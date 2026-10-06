import Foundation
import CoreGraphics

// =====================================================================================
// RetouchOp — the declarative retouch model
// =====================================================================================
//
// Everything the user (or an agent) does to a photo is recorded here as data. Pixels are
// only ever produced by rendering a stack, never by a command that "edits the image".
//
// Five rules hold this together, and every one of them is load-bearing:
//
//   1. OPS DESCRIBE INTENT, NOT ALGORITHMS.
//      `skin(method: .automatic)` means "make the skin look better". It does not name
//      frequency separation, a surface blur or a neural net. The engine picks, guided by
//      `PortraitDocument.processVersion`. Without this rule, every improvement to the
//      skin algorithm silently changes — or breaks — every preset ever saved.
//
//   2. THE STACK IS ORDERED BY PHASE, NOT BY USER ORDER.
//      A retoucher thinks "shape, then skin, then light, then colour". Letting the UI (or
//      an agent) place an op anywhere produces sharpening before denoise and a face
//      liquified after its skin was retouched. Each kind declares a phase; the engine
//      sorts stably by phase and preserves order within one.
//
//   3. REGIONS ARE ANCHORED, NOT ADDRESSED BY PIXEL.
//      A blemish lives at "0.08 right of the left cheek landmark", not at (1423, 891).
//      That is what lets a spot survive re-detection, survive a crop, and transfer to
//      another photo of the same person as part of a preset.
//
//   4. AUTHORABILITY IS NOT RENDERABILITY.
//      A hand-painted dodge & burn map is authored with a Pencil on an iPad and must
//      still render — exactly — on an iPhone that has neither. So every op renders at
//      full fidelity everywhere; `authoringRequirement` only tells the UI whether to
//      offer *editing* it on this device.
//
//   5. UNKNOWN OPS SURVIVE A ROUND TRIP.
//      Three devices update on three schedules. An iPhone running an older build must
//      preserve an op it does not understand, not drop it and not refuse the document.
//      See `RetouchOpKind.unsupported` and `JSONValue`.
//
// =====================================================================================

// MARK: - Document

/// One photo's edit. This is the unit that syncs, that a preset is sliced from, and that
/// an agent reads and writes. It is *not* a layer stack and has no notion of a canvas:
/// the canvas comes from the photo.
public struct PortraitDocument: Codable, Sendable, Equatable {

    public static let formatID = "com.example.portrait"
    public static let currentVersion = 1

    /// Bumped when the *meaning* of an existing op changes, the way Lightroom's Process
    /// Version is. Old documents keep rendering the way they did; only new edits get the
    /// new behaviour. This is the escape valve that makes rule 1 safe.
    public static let currentProcessVersion = 2

    public var format: String = PortraitDocument.formatID
    public var version: Int = PortraitDocument.currentVersion
    public var processVersion: Int = PortraitDocument.currentProcessVersion

    /// A reference, not a copy. The original never moves.
    public var photo: PhotoReference

    /// Bottom of the pipeline first. Only `phase` decides what "first" means in practice;
    /// see `RetouchOpKind.phase`.
    public var ops: [RetouchOp]

    /// Cached face analysis. Deliberately a *cache*: it is regenerable from the photo, so
    /// losing it is never data loss, and a device that cannot run the detector can still
    /// render every op that depends on it.
    public var faces: [FaceAnalysis]?

    /// Sidecar pixel assets (painted dodge & burn maps, painted mask shapes, liquify
    /// offset fields). Referenced by `AssetRef`, stored beside the document the same way
    /// Compositor stores `<layer-uuid>.png` under `images/`.
    public var assets: [AssetRef] = []

    public init(photo: PhotoReference, ops: [RetouchOp] = []) {
        self.photo = photo
        self.ops = ops
    }

    // A hand-written decoder so a missing key takes its default instead of throwing.
    // Swift's synthesized `Codable` does *not* fill defaults for absent keys — a trap
    // Compositor's `.comp` manifest falls into, where `format`/`version`/`colorSpace`
    // read as optional in Swift but are required in practice. Do not rely on defaults
    // with a synthesized decoder.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        format = try c.decodeIfPresent(String.self, forKey: .format) ?? Self.formatID
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
        // Missing versions belong to the original semantics, never a newer default.
        processVersion = try c.decodeIfPresent(Int.self, forKey: .processVersion) ?? 1
        photo = try c.decode(PhotoReference.self, forKey: .photo)
        ops = try c.decodeIfPresent([RetouchOp].self, forKey: .ops) ?? []
        faces = try c.decodeIfPresent([FaceAnalysis].self, forKey: .faces)
        assets = try c.decodeIfPresent([AssetRef].self, forKey: .assets) ?? []
    }
}

/// Where the pixels come from. Held as an identifier rather than a path so the same edit
/// applies to a photo-library asset on iOS and a file on macOS.
public struct PhotoReference: Codable, Sendable, Equatable {
    public enum Source: Codable, Sendable, Equatable {
        /// `PHAsset.localIdentifier`.
        case photoLibrary(assetID: String)
        /// A path relative to the project, or a bookmark, resolved by the host app.
        case file(relativePath: String)
    }

    public var source: Source
    /// The pixel dimensions the edit was authored against. Used to detect that the
    /// underlying photo changed or was re-exported at a different size, so anchored
    /// regions can be re-normalized rather than silently misplaced.
    public var pixelSize: SIMD2<Int>
    /// Content hash of the original. If this changes, cached face analysis is stale.
    public var contentHash: String?

    public init(source: Source, pixelSize: SIMD2<Int>, contentHash: String? = nil) {
        self.source = source
        self.pixelSize = pixelSize
        self.contentHash = contentHash
    }
}

// MARK: - Assets

/// A pixel sidecar this document owns. Masks and painted maps, never a copy of the photo.
public struct AssetRef: Codable, Sendable, Equatable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        /// 8-bit coverage, 0 = untouched. Layer masks, painted region shapes.
        case coverage8
        /// Two channels: positive = dodge, negative = burn. One map, not two layers,
        /// because a single signed map can be curved, blurred and clamped as a unit.
        case signedLight16
        /// `rg32Float` displacement. The same representation Compositor uses for liquify,
        /// chosen there for a reason worth keeping: moving offsets and resampling from the
        /// untouched original never softens the pixels, however many dabs are applied.
        case offsetField
    }

    public var id: UUID
    public var kind: Kind
    public var pixelSize: SIMD2<Int>

    public init(id: UUID = UUID(), kind: Kind, pixelSize: SIMD2<Int>) {
        self.id = id
        self.kind = kind
        self.pixelSize = pixelSize
    }
}

// MARK: - Anchoring

/// A point named the way a retoucher names it, not the way a pixel grid names it.
public struct AnchoredPoint: Codable, Sendable, Equatable {
    public enum Space: Codable, Sendable, Equatable {
        /// Normalized 0–1 across the whole image.
        case image
        /// Normalized 0–1 across a detected face's bounding box.
        case face(index: Int)
        /// An offset, in face-width fractions, from a named landmark on a face.
        /// This is the one an agent should use: it is stable across re-detection,
        /// robust to crop, and something a model can reason about from a preview.
        case landmark(faceIndex: Int, landmark: Landmark)
    }

    public var space: Space
    public var value: SIMD2<Double>

    public init(space: Space, value: SIMD2<Double>) {
        self.space = space
        self.value = value
    }

    public static func near(_ landmark: Landmark, on face: Int = 0,
                           dx: Double = 0, dy: Double = 0) -> AnchoredPoint {
        AnchoredPoint(space: .landmark(faceIndex: face, landmark: landmark), value: SIMD2(dx, dy))
    }
}

/// The landmark vocabulary. Closed and engine-owned, deliberately: these are derived from
/// Vision's regions plus the points retouchers actually name out loud. Because
/// `PortraitDocument.faces` is a cache, an unknown name may be dropped without data loss.
public enum Landmark: String, Codable, Sendable, CaseIterable {
    // Structure
    case faceCenter, forehead, glabella, chin
    case jawLeft, jawRight, cheekLeft, cheekRight, templeLeft, templeRight
    // Eyes and brows
    case browLeft, browRight, eyeLeft, eyeRight, pupilLeft, pupilRight
    case underEyeLeft, underEyeRight
    // Nose and mouth
    case noseBridge, noseTip, nostrilLeft, nostrilRight
    case philtrum, upperLip, lowerLip, mouthCenter, mouthCornerLeft, mouthCornerRight
    // Edges
    case earLeft, earRight, hairlineLeft, hairlineRight, neckCenter
}

/// A rectangle or a path, anchored the same way a point is.
public enum RegionShape: Codable, Sendable, Equatable {
    case ellipse(center: AnchoredPoint, radius: SIMD2<Double>)
    case rectangle(center: AnchoredPoint, halfExtent: SIMD2<Double>)
    case path(points: [AnchoredPoint], closed: Bool)
    /// A shape painted by hand and stored as a `coverage8` asset.
    case painted(assetID: UUID)
}

// MARK: - Face analysis

/// Normalized to 0–1 with the origin top-left, y down — the same convention as
/// `AnchoredPoint`. One convention everywhere, or every coordinate bug is a flip bug.
public struct NormalizedRect: Codable, Sendable, Equatable {
    public var origin: SIMD2<Double>
    public var size: SIMD2<Double>

    public var center: SIMD2<Double> { origin + size / 2 }
    public var maxX: Double { origin.x + size.x }
    public var maxY: Double { origin.y + size.y }

    public init(origin: SIMD2<Double>, size: SIMD2<Double>) {
        self.origin = origin
        self.size = size
    }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.init(origin: SIMD2(x, y), size: SIMD2(width, height))
    }
}

/// Encodes as a plain JSON object and tolerates landmark names it does not know, so a
/// point written by a newer build does not poison the whole analysis.
public struct LandmarkMap: Codable, Sendable, Equatable {
    private var storage: [Landmark: SIMD2<Double>]

    public init(_ storage: [Landmark: SIMD2<Double>] = [:]) { self.storage = storage }

    public subscript(_ landmark: Landmark) -> SIMD2<Double>? {
        get { storage[landmark] }
        set { storage[landmark] = newValue }
    }

    public var points: [Landmark: SIMD2<Double>] { storage }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = try c.decode([String: SIMD2<Double>].self)
        var out: [Landmark: SIMD2<Double>] = [:]
        // An unknown landmark name from a newer build is skipped rather than fatal. Safe
        // precisely because `faces` is a cache: the points we do understand still place
        // every region that matters, and re-running the detector regenerates the rest.
        for (key, value) in raw {
            guard let landmark = Landmark(rawValue: key) else { continue }
            out[landmark] = value
        }
        storage = out
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        var raw: [String: SIMD2<Double>] = [:]
        for (landmark, point) in storage { raw[landmark.rawValue] = point }
        try c.encode(raw)
    }
}

public struct FaceAnalysis: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    /// Index into `PortraitDocument.faces`; the number `AnchoredPoint` refers to.
    public var index: Int
    public var boundingBox: NormalizedRect
    /// Clockwise roll in degrees, from eye line to horizontal.
    public var roll: Double
    public var landmarks: LandmarkMap
    /// Left/right of frame, from the subject's point of view. Facial asymmetry means a
    /// retoucher means "the subject's left cheek", never "the left side of the screen".
    public var skinTone: SkinToneStats?
    public var detectorVersion: String

    public init(id: UUID = UUID(), index: Int, boundingBox: NormalizedRect, roll: Double = 0,
                landmarks: LandmarkMap = LandmarkMap(), skinTone: SkinToneStats? = nil,
                detectorVersion: String) {
        self.id = id
        self.index = index
        self.boundingBox = boundingBox
        self.roll = roll
        self.landmarks = landmarks
        self.skinTone = skinTone
        self.detectorVersion = detectorVersion
    }
}

/// Enough statistics for an agent to reason about *how much* to retouch without guessing.
public struct SkinToneStats: Codable, Sendable, Equatable {
    /// Mean skin colour, sRGB 0–1.
    public var meanColor: SIMD3<Double>
    /// Standard deviation of luminance across the skin region: the texture/noise floor.
    /// A low value means already-smooth skin and a lower smoothing strength is correct.
    public var luminanceStdDev: Double
    /// Fraction of the face region classified as skin.
    public var coverage: Double
    /// Fraction of high-coverage skin occupied by conservative blemish candidate footprints.
    /// A detector statistic, not a diagnosis or an instruction to increase smoothing.
    public var blemishFraction: Double

    public init(meanColor: SIMD3<Double>, luminanceStdDev: Double, coverage: Double, blemishFraction: Double) {
        self.meanColor = meanColor
        self.luminanceStdDev = luminanceStdDev
        self.coverage = coverage
        self.blemishFraction = blemishFraction
    }
}

// MARK: - The op envelope

public struct RetouchOp: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var kind: RetouchOpKind
    /// A/B without deleting. Disabled ops are preserved and still sync.
    public var isEnabled: Bool
    /// User-visible label, for ops the user named. Nil for most.
    public var label: String?
    /// Where this op came from. Load-bearing for the agent workflow.
    public var origin: OpOrigin

    public init(id: UUID = UUID(), kind: RetouchOpKind, isEnabled: Bool = true,
                label: String? = nil, origin: OpOrigin = .user) {
        self.id = id
        self.kind = kind
        self.isEnabled = isEnabled
        self.label = label
        self.origin = origin
    }
}

/// Why `origin` is not just a flag: it answers "undo everything the agent did to this
/// photo" without touching a single thing the user did, and it lets the UI show a
/// suggestion as a suggestion rather than as a fait accompli.
public enum OpOrigin: Codable, Sendable, Equatable {
    case user
    case preset(name: String)
    case ai(sessionID: UUID, model: String?)

    public var isAI: Bool { if case .ai = self { return true }; return false }
    public var sessionID: UUID? { if case .ai(let id, _) = self { return id }; return nil }
}

// MARK: - Phases

/// The pipeline order a retoucher actually works in. Sorted stably: two ops in the same
/// phase keep the order they were added.
///
/// `reshape` before `retouch` is deliberate and is the order most retouchers want: the
/// skin is retouched on the face as it will finally be shaped. A user who prefers the
/// other order is expressing a workflow, not a data-model requirement — solve that with
/// two ops in the same phase, or with a future explicit reorder, not by removing the order.
public enum RetouchPhase: Int, Codable, Sendable, CaseIterable, Comparable {
    case geometry = 0   // crop, straighten, lens correction — changes which pixels exist
    case develop = 1    // exposure, white balance, tone — a neutral base to work on
    case reshape = 2    // face and feature geometry
    case retouch = 3    // skin, blemishes, eyes, teeth
    case paint = 4      // dodge & burn, hand-shaped light
    case grade = 5      // curves, mixer, colour grading
    case finish = 6     // grain, vignette, output sharpening
    case layout = 7     // border, watermark, text

    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

// MARK: - Op kinds

public enum RetouchOpKind: Sendable, Equatable {
    // Geometry
    case crop(CropParams)
    case optics(OpticsParams)

    // Develop — split per module, not one big blob, because "sync only the colour to the
    // rest of the shoot" is a real and frequent request, and because it gives an agent a
    // precise handle: set_module_param(photo, "tone", "exposure", 0.3).
    case whiteBalance(WhiteBalanceParams)
    case tone(ToneParams)
    case presence(PresenceParams)
    case toneCurve(CurveParams)
    case colorMixer(ColorMixerParams)
    case colorGrading(ColorGradingParams)
    case detail(DetailParams)
    case calibration(CalibrationParams)

    // Retouch
    case skin(SkinParams)
    case blemish(BlemishParams)
    case eyes(EyeParams)
    case teeth(TeethParams)

    // Reshape
    case reshape(ReshapeParams)

    // Paint
    case dodgeBurn(DodgeBurnParams)
    case localAdjustment(LocalAdjustmentParams)

    // Finish
    case grain(GrainParams)
    case vignette(VignetteParams)

    // Layout
    case frame(FrameParams)
    case watermark(WatermarkParams)

    /// Forward compatibility. A newer build wrote an op this one does not know; the payload
    /// is kept verbatim and written back unchanged. Never rendered, never dropped.
    case unsupported(UnsupportedOp)
}

public struct UnsupportedOp: Codable, Sendable, Equatable {
    /// The JSON key the newer build used, e.g. `"relight"`.
    public var kind: String
    public var payload: JSONValue

    public init(kind: String, payload: JSONValue) {
        self.kind = kind
        self.payload = payload
    }
}

// MARK: - Geometry

public struct CropParams: Codable, Sendable, Equatable {
    /// Normalized to the *original* image, so crop is idempotent and re-editable.
    public var rect: NormalizedRect
    /// Degrees, clockwise. Non-zero means straighten.
    public var angle: Double = 0
    /// Optional output aspect, e.g. 4:5 for portraits. Nil keeps the crop's own ratio.
    public var aspectRatio: Double?
    public var fillOutside: Bool = false

    public init(rect: NormalizedRect, angle: Double = 0, aspectRatio: Double? = nil) {
        self.rect = rect
        self.angle = angle
        self.aspectRatio = aspectRatio
    }
}

public struct OpticsParams: Codable, Sendable, Equatable {
    public var distortion: Double = 0            // -100...100
    public var vignetteCorrection: Double = 0    // -100...100
    public var chromaticAberration: Bool = false
    public var defringePurple: Double = 0        // 0...100
    public var defringeGreen: Double = 0         // 0...100

    public init() {}
}

// MARK: - Develop

public struct WhiteBalanceParams: Codable, Sendable, Equatable {
    /// Relative, not Kelvin. Compositor's Camera Raw uses three tuned constants to fake
    /// this and it shows. Either implement a real chromatic adaptation (Bradford/von Kries
    /// against the camera profile) or label the sliders honestly as relative offsets.
    public var temperature: Double = 0   // -100...100
    public var tint: Double = 0          // -100...100
    /// User-picked neutral, if the eyedropper was used. Overrides the two above.
    public var sampledNeutral: SIMD3<Double>?

    public init() {}
}

public struct ToneParams: Codable, Sendable, Equatable {
    public var exposure: Double = 0     // -5...5 stops
    public var contrast: Double = 0     // -100...100
    public var highlights: Double = 0   // -100...100
    public var shadows: Double = 0
    public var whites: Double = 0
    public var blacks: Double = 0

    public init() {}
}

public struct PresenceParams: Codable, Sendable, Equatable {
    public var texture: Double = 0      // -100...100
    public var clarity: Double = 0
    public var dehaze: Double = 0
    public var vibrance: Double = 0
    public var saturation: Double = 0

    public init() {}
}

public struct CurvePoint: Codable, Sendable, Equatable {
    public var x: Double   // 0...1
    public var y: Double   // 0...1
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

public struct CurveParams: Codable, Sendable, Equatable {
    public enum Channel: String, Codable, Sendable, CaseIterable {
        case rgb, red, green, blue
    }
    /// Per-channel point curves. The engine interpolates monotonically (shape-preserving),
    /// the way Compositor's Does — a plain Catmull-Rom overshoots and inverts contrast.
    public var channels: [Channel: [CurvePoint]] = [:]
    /// Parametric region curve, Photoshop-style.
    public var parametric: ParametricCurve?
    public var refineSaturation: Double = 0

    public init() {}
}

public struct ParametricCurve: Codable, Sendable, Equatable {
    public var shadows: Double = 0
    public var darks: Double = 0
    public var lights: Double = 0
    public var highlights: Double = 0
    public var shadowSplit: Double = 25
    public var midSplit: Double = 50
    public var highlightSplit: Double = 75

    public init() {}
}

public struct ColorMixerParams: Codable, Sendable, Equatable {
    public enum Band: String, Codable, Sendable, CaseIterable {
        case red, orange, yellow, green, aqua, blue, purple, magenta
    }
    public struct Shift: Codable, Sendable, Equatable {
        public var hue: Double = 0        // -100...100
        public var saturation: Double = 0
        public var luminance: Double = 0
        public init() {}
    }
    public var bands: [Band: Shift] = [:]
    /// Point colour: sampled colours with their own shifts. Portrait retouchers use this
    /// for skin — pull one swatch off a cheek and adjust it without touching the background.
    public var pointColors: [PointColor] = []

    public init() {}
}

public struct PointColor: Codable, Sendable, Equatable {
    public var id: UUID
    public var reference: SIMD3<Double>
    public var shift: ColorMixerParams.Shift
    public var hueRange: Double = 30     // degrees
    public var saturationRange: Double = 0.5
    public var luminanceRange: Double = 0.5

    public init(id: UUID = UUID(), reference: SIMD3<Double>, shift: ColorMixerParams.Shift = .init()) {
        self.id = id
        self.reference = reference
        self.shift = shift
    }
}

public struct ColorGradingParams: Codable, Sendable, Equatable {
    public struct Wheel: Codable, Sendable, Equatable {
        public var hue: Double = 0         // 0...360
        public var saturation: Double = 0  // 0...100
        public var luminance: Double = 0   // -100...100
        public init() {}
    }
    public var shadows = Wheel()
    public var midtones = Wheel()
    public var highlights = Wheel()
    public var global = Wheel()
    public var blending: Double = 50
    public var balance: Double = 0

    public init() {}
}

public struct DetailParams: Codable, Sendable, Equatable {
    public var sharpenAmount: Double = 0        // 0...150
    public var sharpenRadius: Double = 1        // 0.5...3 px
    public var sharpenDetail: Double = 25       // 0...100
    public var sharpenMasking: Double = 0       // 0...100
    public var noiseLuminance: Double = 0       // 0...100
    public var noiseLuminanceDetail: Double = 50
    public var noiseColor: Double = 25          // 0...100
    public var noiseColorDetail: Double = 50

    public init() {}
}

public struct CalibrationParams: Codable, Sendable, Equatable {
    public var shadowTint: Double = 0
    public struct Primary: Codable, Sendable, Equatable {
        public var hue: Double = 0
        public var saturation: Double = 0
        public init() {}
    }
    public var redPrimary = Primary()
    public var greenPrimary = Primary()
    public var bluePrimary = Primary()

    public init() {}
}

// MARK: - Retouch (the part that makes this a portrait app)

/// Skin retouching, expressed as intent.
///
/// `texturePreservation` is the parameter that separates a tool from a toy: at 0 the skin
/// is smoothed flat, at 1 the high-frequency layer is untouched and only colour and light
/// are evened out. A default below roughly 0.5 is a bug, not a preference.
public struct SkinParams: Codable, Sendable, Equatable {
    public var strength: Double = 0.5             // 0...1
    public var texturePreservation: Double = 0.6  // 0...1
    /// Detail scale in pixels at full resolution: roughly the pore size to preserve.
    public var radius: Double = 12                // 2...80
    /// Extra local smoothing on detected blemishes, on top of `strength`.
    public var blemishStrength: Double = 0        // 0...1
    /// Positive grows the skin mask, negative shrinks it. Guards the eyes, brows,
    /// nostrils and lips from being smoothed.
    public var maskExpansion: Double = 0          // -1...1
    /// Skip retouching where the detected face is not skin — hair, background, clothing.
    public var protectNonSkin: Bool = true

    public init() {}
}

/// Spots, auto-detected and hand-placed, in one list.
///
/// One list rather than two because they behave identically after placement: the same
/// heal algorithm, the same undo granularity, the same "undo everything the agent found".
public struct BlemishParams: Codable, Sendable, Equatable {
    public struct Spot: Codable, Sendable, Equatable, Identifiable {
        public enum Origin: String, Codable, Sendable {
            case manual     // tapped or painted by a person
            case detected   // found by the skin analyser
            case agent      // proposed by a model and accepted
        }
        public var id: UUID
        /// Where the spot is. An `agent`-origin spot must be landmark-anchored.
        public var at: AnchoredPoint
        /// Where to copy from. Nil means the engine picks, preferring a nearby patch of
        /// the subject's own skin — which is what makes a heal invisible.
        public var source: AnchoredPoint?
        /// Radius as a fraction of face width, so a spot means the same thing on a
        /// 12 MP phone shot and a 61 MP camera shot.
        public var radius: Double
        public var hardness: Double = 0   // 0...1
        public var opacity: Double = 1    // 0...1
        public var origin: Origin
        /// Detected spots the user rejected. Kept so re-analysis does not resurrect them.
        public var rejected: Bool = false

        public init(id: UUID = UUID(), at: AnchoredPoint, source: AnchoredPoint? = nil,
                    radius: Double, hardness: Double = 0, opacity: Double = 1,
                    origin: Origin = .manual) {
            self.id = id
            self.at = at
            self.source = source
            self.radius = radius
            self.hardness = hardness
            self.opacity = opacity
            self.origin = origin
        }
    }

    public var spots: [Spot] = []
    /// Run the detector on load. Turning it off keeps the detected spots already in the
    /// list; turning it back on must not duplicate them.
    public var autoDetect: Bool = true
    /// Minimum contrast a defect must have to be offered, so a detector does not chase
    /// the subject's own freckles and moles.
    public var detectionThreshold: Double = 0.5   // 0...1

    public init() {}
}

/// Eyes and teeth are separate ops from skin because their *guardrails* are different:
/// over-smoothing skin looks bad, over-whitening a sclera looks like a mistake.
public struct EyeParams: Codable, Sendable, Equatable {
    public struct EyeSelector: Codable, Sendable, Equatable {
        public var faceIndex: Int = 0
        /// A `Landmark` sibling: `.eyeLeft` / `.eyeRight`, or nil for both.
        public var landmark: Landmark?
        public init(faceIndex: Int = 0, landmark: Landmark? = nil) {
            self.faceIndex = faceIndex
            self.landmark = landmark
        }
    }

    public var selector = EyeSelector()
    /// Lifts the sclera toward white.
    public var scleraBrightness: Double = 0     // 0...1
    /// Removes the yellow/red cast from the sclera. Separate from brightness because
    /// raising brightness alone on a bloodshot eye makes it look worse, not better.
    public var scleraWhiteness: Double = 0      // 0...1
    public var irisBrightness: Double = 0       // -0.5...0.5
    public var irisClarity: Double = 0          // 0...1
    public var irisSaturation: Double = 0       // -1...1
    public var catchlightBoost: Double = 0      // 0...1
    public var darkenLashLine: Double = 0       // 0...1
    public var brightenUnderEye: Double = 0     // 0...1

    public init() {}
}

public struct TeethParams: Codable, Sendable, Equatable {
    /// Yellow removal. Must be a *hue-windowed* desaturation toward the tooth's own
    /// luminance, never a plain brightness lift — a brightened yellow tooth is still yellow.
    public var whitening: Double = 0        // 0...1
    public var brightness: Double = 0       // 0...1
    /// Keeps the dark seam between adjacent teeth, which is what stops whitening from
    /// turning a mouth into a white bar.
    public var preserveSeparation: Double = 0.7   // 0...1

    public init() {}
}

// MARK: - Reshape

public struct ReshapeParams: Codable, Sendable, Equatable {
    public enum Feature: String, Codable, Sendable, CaseIterable {
        case faceWidth, faceLength, jawline, chin, cheekbones
        case noseWidth, noseLength, noseTip
        case eyeSize, eyeSpacing
        case mouthWidth, lipFullness, smile
        case forehead, hairline
    }

    public struct Warp: Codable, Sendable, Equatable {
        public var feature: Feature
        public var amount: Double           // -1...1
        public init(feature: Feature, amount: Double) {
            self.feature = feature
            self.amount = amount
        }
    }

    public var faceIndex: Int = 0
    public var warps: [Warp] = []

    /// Hand-pushed offsets, stored as a displacement field rather than replayed strokes.
    ///
    /// This is the one place where Compositor's design is worth copying wholesale: it keeps
    /// one untouched original texture plus a per-pixel `float2` offset, moves only the
    /// offsets on each dab, and resamples from the original every time. Replaying strokes
    /// against already-resampled pixels softens the image a little more with every pass.
    /// Photoshop's Liquify keeps pixels sharp for the same reason.
    public var offsetField: UUID?

    /// Landmarks the warps must not move. Set true for anything involving eyes.
    public var protectFeatureLandmarks: Bool = true

    public init() {}
}

// MARK: - Paint

/// A hand-shaped lighting map.
///
/// Stored as one signed map rather than two painted layers. A signed map can be blurred,
/// curved and clamped as a unit — which is how a retoucher actually works, building broad
/// transitions first and refining on top. Two independent dodge and burn layers cannot.
public struct DodgeBurnParams: Codable, Sendable, Equatable {
    public enum Blend: String, Codable, Sendable {
        /// 50% grey on Soft Light — the classic, and the safest default.
        case softLight
        case overlay
        /// Only L changes; hue and saturation are held. For skin, this is usually right.
        case luminanceOnly
    }

    public var map: UUID                  // AssetRef id, kind == .signedLight16
    public var amount: Double = 1         // -2...2
    public var blend: Blend = .softLight
    public var contrast: Double = 0       // -1...1, curves the map before it is applied

    public init(map: UUID) { self.map = map }
}

/// A masked regional edit. The general-purpose escape hatch, and the op an agent reaches
/// for when nothing more specific fits: "warm the background", "lift the shadow under the
/// left eye", "add clarity to the dress".
public struct LocalAdjustmentParams: Codable, Sendable, Equatable {
    public var region: RegionShape
    public var feather: Double = 0.5      // 0...1
    public var invert: Bool = false
    /// Fraction of the adjustment applied at full mask coverage.
    public var opacity: Double = 1        // 0...1
    public var blend: String = "normal"

    public var tone: ToneParams?
    public var presence: PresenceParams?
    public var whiteBalance: WhiteBalanceParams?
    public var colorMixer: ColorMixerParams?

    public init(region: RegionShape) { self.region = region }
}

// MARK: - Finish and layout

public struct GrainParams: Codable, Sendable, Equatable {
    public var amount: Double = 0        // 0...100
    public var size: Double = 1.5        // 0.5...20
    public var roughness: Double = 50    // 0...100
    /// Fixed so the pattern is stable between sessions and between devices. A random
    /// seed would make the same document look different on a phone and a Mac.
    public var seed: UInt64 = 1
    public init() {}
}

public struct VignetteParams: Codable, Sendable, Equatable {
    public var amount: Double = 0        // -100...100
    public var midpoint: Double = 50     // 0...100
    public var roundness: Double = 0     // -100...100
    public var feather: Double = 60      // 0...100
    public var highlights: Double = 0    // 0...100
    public init() {}
}

public struct FrameParams: Codable, Sendable, Equatable {
    public enum Style: String, Codable, Sendable {
        case none, border, matte, polaroid
    }
    public var style: Style = .none
    public var width: Double = 0         // fraction of the short edge
    public var color: SIMD3<Double> = SIMD3(1, 1, 1)
    public var cornerRadius: Double = 0
    public init() {}
}

public struct WatermarkParams: Codable, Sendable, Equatable {
    public var text: String = ""
    public var assetID: UUID?
    public var anchor: SIMD2<Double> = SIMD2(0.5, 0.95)   // normalized
    public var scale: Double = 0.05
    public var opacity: Double = 0.7
    public var rotation: Double = 0
    public init() {}
}

// MARK: - Op metadata

public extension RetouchOpKind {

    /// Which pipeline pass this op belongs to. The engine sorts by this, stably.
    var phase: RetouchPhase {
        switch self {
        case .crop, .optics:                                  return .geometry
        case .whiteBalance, .tone, .presence, .toneCurve,
             .colorMixer, .colorGrading, .detail, .calibration: return .develop
        case .reshape:                                        return .reshape
        case .skin, .blemish, .eyes, .teeth:                  return .retouch
        case .dodgeBurn, .localAdjustment:                    return .paint
        case .grain, .vignette:                               return .finish
        case .frame, .watermark:                              return .layout
        case .unsupported:                                    return .finish
        }
    }

    /// What the UI needs to edit this op — and *only* that. Rendering is always full
    /// fidelity on every platform; an iPhone shows a synced dodge & burn map perfectly, it
    /// just cannot author one.
    enum AuthoringRequirement: String, Codable, Sendable {
        /// Sliders and taps. Every platform including iPhone.
        case anywhere
        /// Needs a precise pointer: placing a spot, drawing a mask.
        case pointer
        /// Needs pressure, tilt or hover: painting dodge & burn, fine liquify.
        case pencil
    }

    var authoringRequirement: AuthoringRequirement {
        switch self {
        case .skin, .blemish, .eyes, .teeth, .reshape,
             .whiteBalance, .tone, .presence, .toneCurve,
             .colorMixer, .colorGrading, .detail, .calibration,
             .crop, .optics, .grain, .vignette, .frame, .watermark:
            return .anywhere
        case .localAdjustment:
            return .pointer
        case .dodgeBurn:
            return .pencil
        case .unsupported:
            return .anywhere
        }
    }

    /// How this op behaves when a preset is applied to a *different* photo. Getting this
    /// wrong is how a "sync to all" wipes a shoot: a hand-painted dodge & burn map copied
    /// onto another face puts light in the wrong places, while a tone curve copied over is
    /// exactly what was wanted.
    enum SyncBehavior: String, Codable, Sendable {
        /// Parameters transfer unchanged.
        case always
        /// Transfers if the target has a detectable face; anchors are re-resolved there.
        case faceRelative
        /// Never transfers. Photo-specific paint.
        case never
    }

    var syncBehavior: SyncBehavior {
        switch self {
        case .dodgeBurn:
            // A hand-painted light map copied onto another face puts light in the wrong
            // places. This is the op that makes "sync to all" dangerous, and the reason
            // `SyncBehavior` exists at all.
            return .never
        case .unsupported:
            return .never
        case .skin, .blemish, .eyes, .teeth, .reshape:
            return .faceRelative
        case .localAdjustment:
            // Per region: landmark-anchored regions transfer, painted ones do not. A crop
            // is a framing decision about *this* photo, so it does not transfer either.
            return .faceRelative
        case .crop:
            return .never
        default:
            return .always
        }
    }
}

// MARK: - Validation

public enum RetouchError: Error, Equatable {
    case outOfRange(op: String, field: String, value: Double, range: ClosedRange<Double>)
    case missingFace(index: Int)
    case missingAsset(UUID)
    case invalidRegion(String)
    case unsupportedVersion(Int)
}

public extension RetouchOpKind {

    /// Checked on every MCP write and on every file load. One implementation, so an agent
    /// cannot write a value the engine will silently clamp, and a malformed file is
    /// rejected with a reason instead of rendering something surprising.
    func validate(against document: PortraitDocument) throws {
        func check(_ op: String, _ field: String, _ value: Double, _ range: ClosedRange<Double>) throws {
            guard value.isFinite, range.contains(value) else {
                throw RetouchError.outOfRange(op: op, field: field, value: value, range: range)
            }
        }
        func checkFace(_ index: Int) throws {
            let count = document.faces?.count ?? 0
            // No analysis yet — a preset synced onto a photo before detection ran, or a
            // document opened on a device that cannot run the detector. The op is still
            // valid; it renders nothing until a face is found. Rejecting here would make
            // a perfectly good preset unopenable on some devices, which is exactly the
            // class of bug rule 5 exists to prevent.
            guard count > 0 else { return }
            guard index >= 0, index < count else { throw RetouchError.missingFace(index: index) }
        }
        func checkAsset(_ id: UUID) throws {
            guard document.assets.contains(where: { $0.id == id }) else {
                throw RetouchError.missingAsset(id)
            }
        }

        func checkAnchor(_ point: AnchoredPoint, op: String, field: String) throws {
            switch point.space {
            case .image:
                try check(op, field + ".value.x", point.value.x, 0...1)
                try check(op, field + ".value.y", point.value.y, 0...1)
            case .face(let index):
                try checkFace(index)
                try check(op, field + ".value.x", point.value.x, 0...1)
                try check(op, field + ".value.y", point.value.y, 0...1)
            case .landmark(let index, _):
                try checkFace(index)
                // Offsets can be negative or extend beyond one face width; bounds would
                // reject valid regions extending beyond a face or outside the image.
                guard point.value.x.isFinite, point.value.y.isFinite else {
                    throw RetouchError.invalidRegion(field + " must contain finite landmark offsets in face-width fractions")
                }
            }
        }
        func checkRegion(_ region: RegionShape) throws {
            switch region {
            case .ellipse(let center, _), .rectangle(let center, _):
                try checkAnchor(center, op: "localAdjustment", field: "region.center")
            case .path(let points, _):
                for (index, point) in points.enumerated() {
                    try checkAnchor(point, op: "localAdjustment", field: "region.points[\(index)]")
                }
            case .painted(let asset): try checkAsset(asset)
            }
        }

        switch self {
        case .tone(let p):
            try check("tone", "exposure", p.exposure, -5...5)
            for (n, v) in [("contrast", p.contrast), ("highlights", p.highlights),
                           ("shadows", p.shadows), ("whites", p.whites), ("blacks", p.blacks)] {
                try check("tone", n, v, -100...100)
            }

        case .skin(let p):
            try check("skin", "strength", p.strength, 0...1)
            try check("skin", "texturePreservation", p.texturePreservation, 0...1)
            try check("skin", "radius", p.radius, 2...80)
            try check("skin", "blemishStrength", p.blemishStrength, 0...1)
            try check("skin", "maskExpansion", p.maskExpansion, -1...1)

        case .blemish(let p):
            try check("blemish", "detectionThreshold", p.detectionThreshold, 0...1)
            for (index, spot) in p.spots.enumerated() {
                try check("blemish", "radius", spot.radius, 0.001...0.2)
                try check("blemish", "hardness", spot.hardness, 0...1)
                try check("blemish", "opacity", spot.opacity, 0...1)
                try checkAnchor(spot.at, op: "blemish", field: "spots[\(index)].at")
                if let source = spot.source {
                    try checkAnchor(source, op: "blemish", field: "spots[\(index)].source")
                }
            }

        case .reshape(let p):
            try checkFace(p.faceIndex)
            for warp in p.warps { try check("reshape", "amount", warp.amount, -1...1) }
            if let field = p.offsetField { try checkAsset(field) }

        case .dodgeBurn(let p):
            try check("dodgeBurn", "amount", p.amount, -2...2)
            try check("dodgeBurn", "contrast", p.contrast, -1...1)
            try checkAsset(p.map)

        case .eyes(let p):
            try checkFace(p.selector.faceIndex)
            try check("eyes", "scleraBrightness", p.scleraBrightness, 0...1)
            try check("eyes", "scleraWhiteness", p.scleraWhiteness, 0...1)
            try check("eyes", "irisBrightness", p.irisBrightness, -0.5...0.5)
            try check("eyes", "irisClarity", p.irisClarity, 0...1)
            try check("eyes", "catchlightBoost", p.catchlightBoost, 0...1)

        case .teeth(let p):
            try check("teeth", "whitening", p.whitening, 0...1)
            try check("teeth", "brightness", p.brightness, 0...1)
            try check("teeth", "preserveSeparation", p.preserveSeparation, 0...1)

        case .crop(let p):
            try check("crop", "angle", p.angle, -45...45)
            guard p.rect.size.x > 0, p.rect.size.y > 0,
                  p.rect.origin.x >= 0, p.rect.origin.y >= 0,
                  p.rect.maxX <= 1.0001, p.rect.maxY <= 1.0001 else {
                throw RetouchError.invalidRegion("crop rect must lie inside the image")
            }

        case .localAdjustment(let p):
            try check("localAdjustment", "feather", p.feather, 0...1)
            try check("localAdjustment", "opacity", p.opacity, 0...1)
            try checkRegion(p.region)

        case .grain(let p):
            try check("grain", "amount", p.amount, 0...100)
            try check("grain", "size", p.size, 0.5...20)
            try check("grain", "roughness", p.roughness, 0...100)

        case .unsupported:
            // Never validated: this build does not know what the constraints are, and
            // must not invent them.
            break

        default:
            break
        }
    }
}

// MARK: - Stack preparation

public extension PortraitDocument {

    /// Ops in the order the engine renders them, with disabled and unsupported ops removed.
    ///
    /// A *stable* sort, so two ops in the same phase keep the order they were added, and
    /// so rendering a document twice never produces different pixels.
    var renderOrder: [RetouchOp] {
        ops.enumerated()
            .filter { $0.element.isEnabled && !$0.element.kind.isUnsupported }
            .sorted { a, b in
                let pa = a.element.kind.phase.rawValue, pb = b.element.kind.phase.rawValue
                return pa == pb ? a.offset < b.offset : pa < pb
            }
            .map(\.element)
    }

    /// Validates every op. Called before a save and before any MCP mutation is committed.
    func validate() throws {
        guard version <= Self.currentVersion else {
            throw RetouchError.unsupportedVersion(version)
        }
        for op in ops { try op.kind.validate(against: self) }
    }

    /// Every op one agent session added, so "undo what the agent did" is one call that
    /// cannot touch the user's own work.
    func ops(fromAISession session: UUID) -> [RetouchOp] {
        ops.filter { $0.origin.sessionID == session }
    }
}

public extension RetouchOpKind {
    var isUnsupported: Bool { if case .unsupported = self { return true }; return false }
}

// MARK: - Forward-compatible coding
//
// The default synthesized `Codable` for an enum with associated values would throw on an
// unknown case, which is precisely the situation this design has to survive: an iPhone on
// an older build opening a document an iPad just wrote.
//
// So the kind is coded by hand, in both directions. `RetouchOpKindCodingTests` round-trips
// every case, which is what catches a case added to `encode` and forgotten in `decode`.

extension RetouchOpKind: Codable {

    private struct DynamicKey: CodingKey {
        var stringValue: String
        var intValue: Int?
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { self.intValue = intValue; self.stringValue = String(intValue) }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: DynamicKey.self)
        guard c.allKeys.count == 1, let key = c.allKeys.first else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "A retouch op must be a single-key object"))
        }
        func value<T: Decodable>(_ type: T.Type) throws -> T { try c.decode(type, forKey: key) }

        switch key.stringValue {
        case "crop":            self = .crop(try value(CropParams.self))
        case "optics":          self = .optics(try value(OpticsParams.self))
        case "whiteBalance":    self = .whiteBalance(try value(WhiteBalanceParams.self))
        case "tone":            self = .tone(try value(ToneParams.self))
        case "presence":        self = .presence(try value(PresenceParams.self))
        case "toneCurve":       self = .toneCurve(try value(CurveParams.self))
        case "colorMixer":      self = .colorMixer(try value(ColorMixerParams.self))
        case "colorGrading":    self = .colorGrading(try value(ColorGradingParams.self))
        case "detail":          self = .detail(try value(DetailParams.self))
        case "calibration":     self = .calibration(try value(CalibrationParams.self))
        case "skin":            self = .skin(try value(SkinParams.self))
        case "blemish":         self = .blemish(try value(BlemishParams.self))
        case "eyes":            self = .eyes(try value(EyeParams.self))
        case "teeth":           self = .teeth(try value(TeethParams.self))
        case "reshape":         self = .reshape(try value(ReshapeParams.self))
        case "dodgeBurn":       self = .dodgeBurn(try value(DodgeBurnParams.self))
        case "localAdjustment": self = .localAdjustment(try value(LocalAdjustmentParams.self))
        case "grain":           self = .grain(try value(GrainParams.self))
        case "vignette":        self = .vignette(try value(VignetteParams.self))
        case "frame":           self = .frame(try value(FrameParams.self))
        case "watermark":       self = .watermark(try value(WatermarkParams.self))
        default:
            // Written by a newer build. Keep it, do not interpret it, write it back intact.
            self = .unsupported(UnsupportedOp(kind: key.stringValue,
                                              payload: try value(JSONValue.self)))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: DynamicKey.self)
        func put<T: Encodable>(_ name: String, _ payload: T) throws {
            try c.encode(payload, forKey: DynamicKey(stringValue: name)!)
        }
        switch self {
        case .crop(let p):            try put("crop", p)
        case .optics(let p):          try put("optics", p)
        case .whiteBalance(let p):    try put("whiteBalance", p)
        case .tone(let p):            try put("tone", p)
        case .presence(let p):        try put("presence", p)
        case .toneCurve(let p):       try put("toneCurve", p)
        case .colorMixer(let p):      try put("colorMixer", p)
        case .colorGrading(let p):    try put("colorGrading", p)
        case .detail(let p):          try put("detail", p)
        case .calibration(let p):     try put("calibration", p)
        case .skin(let p):            try put("skin", p)
        case .blemish(let p):         try put("blemish", p)
        case .eyes(let p):            try put("eyes", p)
        case .teeth(let p):           try put("teeth", p)
        case .reshape(let p):         try put("reshape", p)
        case .dodgeBurn(let p):       try put("dodgeBurn", p)
        case .localAdjustment(let p): try put("localAdjustment", p)
        case .grain(let p):           try put("grain", p)
        case .vignette(let p):        try put("vignette", p)
        case .frame(let p):           try put("frame", p)
        case .watermark(let p):       try put("watermark", p)
        case .unsupported(let op):    try put(op.kind, op.payload)
        }
    }
}

// MARK: - Rendering contract

/// What a renderer needs from the host: decoded pixels, resolved assets, and the analysis
/// that anchored regions refer to. Nothing platform-specific, so the same renderer runs on
/// a Mac, an iPad and an iPhone.
///
/// `@unchecked Sendable` because `CGImage` is not marked `Sendable` but is immutable once
/// created: sharing one across threads is safe, and pretending otherwise would force a
/// copy of every asset on every render. Compositor makes the same call for the same reason.
public struct RenderContext: @unchecked Sendable {
    public enum Scale: Sendable, Equatable {
        /// Full resolution. The only scale an export may use.
        case full
        /// A preview for the screen or for an agent to look at. Ops with a spatial extent
        /// (blur radius, spot radius, grain size) scale with this; a tone curve does not.
        case preview(maxDimension: Int)
    }

    /// Single-step rendering uses this version; a stack binds it to the document version.
    public let processVersion: Int
    /// Full-resolution dimensions used to scale spatial parameters in preview inputs.
    /// Preview inputs are already resized by the caller, with the same aspect ratio.
    public let sourcePixelSize: SIMD2<Int>?
    /// Explicit skin coverage, black = protected, white = editable. Same dimensions and
    /// top-left orientation as the input. A detector supplies it; a face box is not a mask.
    public let skinMask: CGImage?
    public let scale: Scale
    public let assets: [UUID: CGImage]
    public let faces: [FaceAnalysis]
    /// Higher is better and slower. The preview path lowers it; export pins it.
    public let quality: Quality

    public enum Quality: String, Sendable, Codable {
        case draft, standard, best
    }

    public init(scale: Scale, assets: [UUID: CGImage], faces: [FaceAnalysis], quality: Quality = .standard,
                processVersion: Int = PortraitDocument.currentProcessVersion,
                sourcePixelSize: SIMD2<Int>? = nil, skinMask: CGImage? = nil) {
        self.processVersion = processVersion
        self.sourcePixelSize = sourcePixelSize
        self.skinMask = skinMask
        self.scale = scale
        self.assets = assets
        self.faces = faces
        self.quality = quality
    }

    /// Keep the same analysis, assets and preview geometry while selecting saved semantics.
    public func usingProcessVersion(_ version: Int) -> RenderContext {
        RenderContext(scale: scale, assets: assets, faces: faces, quality: quality,
                      processVersion: version, sourcePixelSize: sourcePixelSize, skinMask: skinMask)
    }
}

/// The rendering contract. Two entry points, deliberately, and the relationship between
/// them is the whole point:
///
///   `renderStep` is the *definition* of what an op means. One op, one image, pure.
///   `renderStack` is the *production* path. It may fuse ops — all the develop LUTs into
///             one pass, for instance — but it must agree with folding `renderStep`.
///
/// Compositor carries two complete compositors (a Core Graphics one and a Core Image one)
/// that are kept in step by hand and by comments. That is the single largest piece of debt
/// in an otherwise excellent codebase, and it exists because there was no definition of
/// which one was authoritative.
///
/// Here there is: `renderStep` is authoritative, fusion is an optimisation, and a parity
/// test over a corpus of documents is what allows the optimiser to exist. Write that test
/// on day one, not after the first divergence.
public protocol RetouchRenderer: Sendable {
    /// Pure: same inputs, same output, always. This is the reference semantics.
    func renderStep(_ kind: RetouchOpKind, input: CGImage, context: RenderContext) throws -> CGImage

    /// The production path. Must equal the result of folding `renderStep` over
    /// `document.renderOrder`, within `tolerance`.
    func renderStack(_ document: PortraitDocument, input: CGImage, context: RenderContext) throws -> CGImage

    /// Maximum per-channel difference `renderStack` may show against the `renderStep` fold,
    /// in 8-bit levels. Zero for the operations that must be exact; a small value for
    /// paths that legitimately reorder floating-point work.
    var tolerance: Int { get }
}

public extension RetouchRenderer {
    var tolerance: Int { 0 }

    /// The reference implementation of `renderStack`: literally fold `renderStep`. Any
    /// conforming renderer can inherit this, and should, until it has a reason and a test
    /// to do otherwise.
    func foldStack(_ document: PortraitDocument, input: CGImage, context: RenderContext) throws -> CGImage {
        let context = context.usingProcessVersion(document.processVersion)
        var image = input
        for op in document.renderOrder {
            image = try renderStep(op.kind, input: image, context: context)
        }
        return image
    }
}
