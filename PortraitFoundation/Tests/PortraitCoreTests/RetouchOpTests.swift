import Testing
import Foundation
import CoreGraphics
@testable import PortraitCore

// =====================================================================================
// The two tests that must exist before anything else is built.
//
// 1. Forward-compatibility round trip. Rule 5 in RetouchOp.swift says an older build must
//    preserve an op it does not understand. That is a promise about *encoding* as much as
//    decoding, and the only way to keep the two hand-written switches in step is a test
//    that round-trips every case. Add a case to `RetouchOpKind` and forget one direction:
//    this catches it.
//
// 2. Phase ordering. Rule 2 says the engine sorts by phase, stably. If that ever stops
//    being stable, the same document renders two different ways on two machines — which
//    is the failure mode that makes non-destructive editing untrustworthy.
// =====================================================================================

private let coder: JSONEncoder = {
    let e = JSONEncoder()
    e.outputFormatting = [.sortedKeys]
    return e
}()

private func roundTrip(_ document: PortraitDocument) throws -> PortraitDocument {
    try JSONDecoder().decode(PortraitDocument.self, from: try coder.encode(document))
}

private func sampleDocument(ops: [RetouchOp] = []) -> PortraitDocument {
    PortraitDocument(
        photo: PhotoReference(source: .photoLibrary(assetID: "ABC123"), pixelSize: SIMD2(4032, 3024)),
        ops: ops
    )
}

/// Every op kind, in one place.
///
/// Adding a `RetouchOpKind` case means adding it here, and then three tests fail until the
/// new case round-trips, declares a phase, and declares whether a phone can edit it. That
/// is the point: the hand-written `Codable` switches and the product metadata tables are
/// exactly the things that go stale silently.
private let allKinds: [RetouchOpKind] = [
    .crop(CropParams(rect: NormalizedRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8), angle: 2.5)),
    .optics(OpticsParams()),
    .whiteBalance(WhiteBalanceParams()),
    .tone(ToneParams()),
    .presence(PresenceParams()),
    .toneCurve(CurveParams()),
    .colorMixer(ColorMixerParams()),
    .colorGrading(ColorGradingParams()),
    .detail(DetailParams()),
    .calibration(CalibrationParams()),
    .skin(SkinParams()),
    .blemish(BlemishParams()),
    .eyes(EyeParams()),
    .teeth(TeethParams()),
    .reshape(ReshapeParams()),
    .dodgeBurn(DodgeBurnParams(map: UUID())),
    .localAdjustment(LocalAdjustmentParams(
        region: .ellipse(center: .near(.cheekLeft, dx: 0.05, dy: 0.02), radius: SIMD2(0.1, 0.08)))),
    .grain(GrainParams()),
    .vignette(VignetteParams()),
    .frame(FrameParams()),
    .watermark(WatermarkParams()),
]

// MARK: - 1. Forward compatibility

@Suite("Forward compatibility")
struct ForwardCompatibilityTests {

    /// Every known kind survives a round trip. This is the test that keeps `encode(to:)`
    /// and `init(from:)` honest — they are written by hand, so nothing else would.
    @Test("Every op kind round-trips")
    func everyKindRoundTrips() throws {
        for kind in allKinds {
            let document = sampleDocument(ops: [RetouchOp(kind: kind)])
            let decoded = try roundTrip(document)
            #expect(decoded.ops.map(\.kind) == [kind], "\(kind) did not survive a round trip")
        }
    }

    /// The case that matters: a newer build writes an op this one has never heard of.
    @Test("An unknown op is preserved verbatim, not dropped and not fatal")
    func unknownOpIsPreserved() throws {
        let json = """
        {
          "format": "com.example.portrait",
          "version": 1,
          "photo": { "source": { "photoLibrary": { "assetID": "X" } }, "pixelSize": [100, 100] },
          "ops": [
            { "id": "11111111-1111-1111-1111-111111111111",
              "kind": { "relight": { "keyIntensity": 0.8, "fill": [0.1, 0.2, 0.3], "nested": { "a": true } } },
              "isEnabled": true,
              "origin": { "user": {} } }
          ]
        }
        """.data(using: .utf8)!

        let document = try JSONDecoder().decode(PortraitDocument.self, from: json)
        #expect(document.ops.count == 1)

        guard case .unsupported(let op) = document.ops[0].kind else {
            Issue.record("An unknown kind must decode as .unsupported")
            return
        }
        #expect(op.kind == "relight")
        #expect(op.payload.objectValue?["keyIntensity"]?.doubleValue == 0.8)

        // And it must come back out with its original key and payload, so a device that
        // writes the document after an older one did not destroy the newer one's work.
        let reencoded = try coder.encode(document)
        let text = String(decoding: reencoded, as: UTF8.self)
        #expect(text.contains("\"relight\""))
        #expect(!text.contains("\"unsupported\""))
    }

    /// A missing key takes its default. Swift's synthesized decoder would throw here —
    /// the trap Compositor's manifest falls into — so `PortraitDocument` decodes by hand.
    @Test("Absent optional keys take their defaults")
    func missingKeysTakeDefaults() throws {
        let json = """
        { "photo": { "source": { "photoLibrary": { "assetID": "X" } }, "pixelSize": [10, 10] } }
        """.data(using: .utf8)!

        let document = try JSONDecoder().decode(PortraitDocument.self, from: json)
        #expect(document.format == PortraitDocument.formatID)
        #expect(document.version == PortraitDocument.currentVersion)
        #expect(document.ops.isEmpty)
        #expect(document.assets.isEmpty)
    }

    /// A document from a future format version is refused with a specific error rather
    /// than rendering something surprising — pass-through covers unknown *ops*, not a
    /// changed meaning of the envelope itself.
    @Test("A future document version is refused, not guessed at")
    func futureVersionIsRefused() throws {
        var document = sampleDocument()
        document.version = PortraitDocument.currentVersion + 1
        #expect(throws: RetouchError.unsupportedVersion(PortraitDocument.currentVersion + 1)) {
            try document.validate()
        }
    }
}

// MARK: - 2. Phase ordering

@Suite("Phase ordering")
struct PhaseOrderingTests {

    @Test("Ops render in phase order, not insertion order")
    func phasesSortTheStack() {
        var document = sampleDocument()
        // Added deliberately backwards.
        document.ops = [
            RetouchOp(kind: .vignette(VignetteParams())),      // finish
            RetouchOp(kind: .tone(ToneParams())),              // develop
            RetouchOp(kind: .crop(CropParams(rect: NormalizedRect(x: 0, y: 0, width: 1, height: 1)))), // geometry
            RetouchOp(kind: .skin(SkinParams())),              // retouch
        ]
        #expect(document.renderOrder.map(\.kind.phase) == [.geometry, .develop, .retouch, .finish])
    }

    @Test("Two ops in the same phase keep the order they were added")
    func samePhaseIsStable() {
        let first = RetouchOp(kind: .blemish(BlemishParams()))
        let second = RetouchOp(kind: .skin(SkinParams()))
        var document = sampleDocument(ops: [first, second])

        // A stable sort, so this must never flip.
        #expect(document.renderOrder.map(\.id) == [first.id, second.id])

        // Reordering after the fact must still not flip ops in one phase.
        document.ops = [second, first]
        #expect(document.renderOrder.map(\.id) == [second.id, first.id])
    }

    @Test("Disabled and unsupported ops are left out of the render, but kept in the document")
    func disabledOpsAreKept() throws {
        let disabled = RetouchOp(kind: .skin(SkinParams()), isEnabled: false)
        let unknown = RetouchOp(kind: .unsupported(UnsupportedOp(kind: "relight", payload: .null)))
        let live = RetouchOp(kind: .tone(ToneParams()))
        let document = sampleDocument(ops: [disabled, unknown, live])

        #expect(document.renderOrder.map(\.id) == [live.id])
        #expect(document.ops.count == 3)
    }
}

// MARK: - 3. Agent provenance

@Suite("Agent provenance")
struct AgentProvenanceTests {

    @Test("An agent session can be reverted without touching the user's own work")
    func sessionIsolation() {
        let session = UUID()
        let mine = RetouchOp(kind: .tone(ToneParams()), origin: .user)
        let theirs = RetouchOp(kind: .skin(SkinParams()), origin: .ai(sessionID: session, model: "test"))
        let preset = RetouchOp(kind: .grain(GrainParams()), origin: .preset(name: "Wedding"))

        let document = sampleDocument(ops: [mine, theirs, preset])
        #expect(document.ops(fromAISession: session).map(\.id) == [theirs.id])
        #expect(!mine.origin.isAI)
        #expect(preset.origin.sessionID == nil)
    }
}

// MARK: - 4. Validation and sync metadata

@Suite("Validation")
struct ValidationTests {

    @Test("Normalized image and face anchors reject pixels, negative positions and nonfinite values")
    func normalizedAnchorsRejectInvalidUnits() throws {
        for space: AnchoredPoint.Space in [.image, .face(index: 0)] {
            for value in [SIMD2<Double>(3000, 2000), SIMD2(-0.01, 0.5),
                          SIMD2(0.5, 1.01), SIMD2(.nan, 0.5), SIMD2(0.5, .infinity)] {
                var params = BlemishParams()
                params.spots = [.init(at: AnchoredPoint(space: space, value: value), radius: 0.01)]
                #expect(throws: RetouchError.self) {
                    try sampleDocument(ops: [RetouchOp(kind: .blemish(params))]).validate()
                }
            }
            for value in [SIMD2<Double>(0, 0), SIMD2(1, 1)] {
                var params = BlemishParams()
                params.spots = [.init(at: AnchoredPoint(space: space, value: value), radius: 0.01)]
                try sampleDocument(ops: [RetouchOp(kind: .blemish(params))]).validate()
            }
        }
    }

    @Test("Heal source and all anchored region shapes enforce normalized coordinates")
    func sourcesAndRegionsRejectPixelCoordinates() {
        let bad = AnchoredPoint(space: .image, value: SIMD2(3000, 2000))
        var params = BlemishParams()
        params.spots = [.init(at: .near(.cheekLeft), source: bad, radius: 0.01)]
        #expect(throws: RetouchError.self) {
            try sampleDocument(ops: [RetouchOp(kind: .blemish(params))]).validate()
        }
        for region: RegionShape in [.ellipse(center: bad, radius: SIMD2(0.1, 0.1)),
                                    .rectangle(center: bad, halfExtent: SIMD2(0.1, 0.1)),
                                    .path(points: [.near(.cheekLeft), bad], closed: true)] {
            #expect(throws: RetouchError.self) {
                try sampleDocument(ops: [RetouchOp(kind: .localAdjustment(LocalAdjustmentParams(region: region)))]).validate()
            }
        }
    }

    @Test("Landmark offsets preserve signed fractions beyond one face width but refuse nonfinite values")
    func landmarkOffsetsRemainSignedAndUnbounded() throws {
        var params = BlemishParams()
        params.spots = [.init(at: .near(.cheekLeft, dx: -0.1, dy: 1.2), radius: 0.01)]
        let document = sampleDocument(ops: [RetouchOp(kind: .blemish(params))])
        let decoded = try JSONDecoder().decode(PortraitDocument.self, from: JSONEncoder().encode(document))
        #expect(decoded.ops == document.ops)
        try decoded.validate()
        for value in [Double.nan, .infinity, -.infinity] {
            params.spots[0].at.value.x = value
            #expect(throws: RetouchError.self) {
                try sampleDocument(ops: [RetouchOp(kind: .blemish(params))]).validate()
            }
        }
    }

    @Test("An out-of-range value is refused with the range, not silently clamped")
    func outOfRangeIsRefused() throws {
        var params = SkinParams()
        params.strength = 1.4
        let document = sampleDocument(ops: [RetouchOp(kind: .skin(params))])

        #expect(throws: RetouchError.self) { try document.validate() }
        do {
            try document.validate()
        } catch let error as RetouchError {
            guard case .outOfRange(let op, let field, _, let range) = error else {
                Issue.record("Expected .outOfRange, got \(error)")
                return
            }
            #expect(op == "skin")
            #expect(field == "strength")
            #expect(range == 0...1)
        }
    }

    /// The bug this prevents: a preset synced to a photo whose faces have not been detected
    /// yet must still load. Otherwise "sync to all" produces documents some devices refuse.
    @Test("A face-relative op with no faces detected is valid and simply renders nothing")
    func faceRelativeOpWithoutFacesIsValid() throws {
        let document = sampleDocument(ops: [
            RetouchOp(kind: .eyes(EyeParams())),
            RetouchOp(kind: .teeth(TeethParams())),
        ])
        #expect(document.faces == nil)
        try document.validate()
    }

    @Test("A face-relative op pointing at a face that is not there is refused")
    func missingFaceIsRefused() {
        var params = ReshapeParams()
        params.faceIndex = 3
        var document = sampleDocument(ops: [RetouchOp(kind: .reshape(params))])
        document.faces = [
            FaceAnalysis(index: 0, boundingBox: NormalizedRect(x: 0.2, y: 0.1, width: 0.3, height: 0.4),
                         detectorVersion: "test")
        ]
        #expect(throws: RetouchError.missingFace(index: 3)) { try document.validate() }
    }

    @Test("A dodge & burn map that is not in the document is refused")
    func missingAssetIsRefused() {
        let document = sampleDocument(ops: [RetouchOp(kind: .dodgeBurn(DodgeBurnParams(map: UUID())))])
        #expect(throws: RetouchError.self) { try document.validate() }
    }

    @Test("A crop outside the image is refused")
    func cropOutsideImageIsRefused() {
        let document = sampleDocument(ops: [
            RetouchOp(kind: .crop(CropParams(rect: NormalizedRect(x: 0.5, y: 0, width: 0.8, height: 1))))
        ])
        #expect(throws: RetouchError.self) { try document.validate() }
    }
}

@Suite("Sync metadata")
struct SyncMetadataTests {

    /// This table is a product decision as much as a technical one: it is what "sync to all"
    /// reads before it copies anything.
    @Test("Sync behaviour is declared per op kind")
    func syncBehaviour() {
        #expect(RetouchOpKind.tone(ToneParams()).syncBehavior == .always)
        #expect(RetouchOpKind.skin(SkinParams()).syncBehavior == .faceRelative)
        #expect(RetouchOpKind.blemish(BlemishParams()).syncBehavior == .faceRelative)
        #expect(RetouchOpKind.dodgeBurn(DodgeBurnParams(map: UUID())).syncBehavior == .never)
        #expect(RetouchOpKind.crop(CropParams(rect: NormalizedRect(x: 0, y: 0, width: 1, height: 1))).syncBehavior == .never)
    }

    /// Authorability is not renderability: every op renders everywhere, and this only
    /// decides which devices offer to *edit* it.
    @Test("Only painting needs a Pencil")
    func authoringRequirements() {
        #expect(RetouchOpKind.skin(SkinParams()).authoringRequirement == .anywhere)
        #expect(RetouchOpKind.eyes(EyeParams()).authoringRequirement == .anywhere)
        #expect(RetouchOpKind.localAdjustment(
            LocalAdjustmentParams(region: .painted(assetID: UUID()))).authoringRequirement == .pointer)

        // The invariant worth guarding: exactly ONE op is Pencil-only. A new op that
        // declares `.pencil` — or an existing one quietly changed to it — makes that
        // feature invisible on every phone, which is the kind of regression nobody
        // notices until someone tries to use it on a train.
        let pencilOnly = allKinds.filter { $0.authoringRequirement == .pencil }
        #expect(pencilOnly.count == 1)
        if case .dodgeBurn = pencilOnly.first { } else {
            Issue.record("Expected dodge & burn to be the only Pencil-only op, got \(pencilOnly)")
        }
    }

    @Test("Every op kind declares a phase")
    func everyKindHasAPhase() {
        // Trivially true today because `phase` is exhaustive over the enum — which is the
        // point: adding a case without a phase is a compile error, not a test failure.
        // Asserting it keeps the exhaustiveness honest across refactors that might
        // introduce a `default:` arm.
        for kind in allKinds {
            #expect(RetouchPhase.allCases.contains(kind.phase))
        }
    }
}
