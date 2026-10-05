import CoreGraphics
import Foundation
import PortraitAnalysis
import PortraitCore
import RetouchKit
import ImageIO

/// State errors are tool errors, rather than invalid JSON-RPC requests.
public enum PortraitSessionError: Error, Sendable, Equatable {
    case unknownPhoto, staleRevision, unsupportedProcessVersion, duplicateOperationID
    case previewNotFound, previewMismatch, emptyUndo, unsupportedOperation, historyFull, externalChange
}

/// A preview ticket binds approval to the actual rendered candidate and source revision.
public struct PreviewTicket: @unchecked Sendable {
    public let id: UUID
    public let revision: Int
    public let image: CGImage
    public let stack: [RetouchOp]
    public let processVersion: Int
}

/// One photo's state, owned in-process by the host. Previews never mutate its stack.
/// Rendering and writes serialize, so a candidate cannot commit against a stale revision.
public actor PortraitSession {
    public let photoID: String
    private let photo: LoadedPhoto
    private let analyzer: FaceAnalyzer
    private let renderer = PortraitRenderer()
    private var document: PortraitDocument
    private var analysis: FaceAnalysisResult?
    private var revision = 0
    private var tickets: [UUID: PreviewTicket] = [:]
    private var history: [PortraitDocument] = []
    private let storageURL: URL?
    private var storedData: Data?

    /// Open a bounded photo for an in-process tool host or a future native UI.
    public init(photo: LoadedPhoto, analyzer: FaceAnalyzer = FaceAnalyzer()) {
        self.photo = photo
        self.photoID = photo.id
        self.analyzer = analyzer
        self.document = PortraitDocument(photo: photo.reference)
        self.storageURL = nil
        self.storedData = nil
    }

    private init(photo: LoadedPhoto, document: PortraitDocument, storageURL: URL, storedData: Data?, analysis: FaceAnalysisResult?) {
        self.photo = photo
        self.photoID = photo.id
        self.analyzer = FaceAnalyzer()
        self.document = document
        self.storageURL = storageURL
        self.storedData = storedData
        self.analysis = analysis
    }

    /// Reopen a sidecar belonging to this source, or prepare a new one. Mutations save atomically.
    public static func open(photo: LoadedPhoto, documentURL: URL) throws -> PortraitSession {
        let document: PortraitDocument
        var storedData: Data?
        if FileManager.default.fileExists(atPath: documentURL.path) {
            let data = try Data(contentsOf: documentURL)
            document = try JSONDecoder().decode(PortraitDocument.self, from: data)
            storedData = data
            guard document.photo.contentHash == photo.reference.contentHash,
                  document.photo.pixelSize == photo.reference.pixelSize else { throw PortraitSessionError.unknownPhoto }
            try document.validate()
            guard (1...2).contains(document.processVersion),
                  Set(document.ops.map(\.id)).count == document.ops.count else { throw PortraitSessionError.unsupportedProcessVersion }
        } else { document = PortraitDocument(photo: photo.reference) }
        var analysis: FaceAnalysisResult?
        let cacheURL = documentURL.appendingPathExtension("analysis.json")
        if let data = try? Data(contentsOf: cacheURL), let cache = try? JSONDecoder().decode(AnalysisCache.self, from: data),
           cache.version == 1, cache.sourceHash == photo.reference.contentHash,
           let source = CGImageSourceCreateWithData(cache.mask as CFData, nil),
           let mask = CGImageSourceCreateImageAtIndex(source, 0, nil),
           mask.width == photo.image.width, mask.height == photo.image.height {
            analysis = FaceAnalysisResult(faces: cache.faces, skinMask: mask, geometry: cache.geometry, warnings: cache.warnings)
        }
        return PortraitSession(photo: photo, document: document, storageURL: documentURL, storedData: storedData, analysis: analysis)
    }

    /// Return a value snapshot for a UI; mutation remains inside this actor.
    public func snapshot() -> (document: PortraitDocument, revision: Int) { (document, revision) }

    /// Cache detection and coverage from unchanged upright source pixels.
    public func analyzeFaces() throws -> FaceAnalysisResult {
        if let analysis { return analysis }
        let result = try analyzer.analyze(photo.image)
        analysis = result
        document.faces = result.faces
        return result
    }

    /// Render proposed data, issue a ticket, and leave saved state and history unchanged.
    public func preview(stack: [RetouchOp], maximumDimension: Int = 1024,
                        processVersion: Int? = nil) throws -> PreviewTicket {
        guard (64...2048).contains(maximumDimension) else { throw PhotoIOError.invalidSize }
        let analysis = try analyzeFaces()
        var candidate = document
        candidate.ops = stack
        candidate.processVersion = processVersion ?? document.processVersion
        try validate(candidate)
        let input = try PhotoIO.resize(photo.image, maximumDimension: maximumDimension)
        let mask = try PhotoIO.resize(analysis.skinMask, maximumDimension: maximumDimension)
        let context = RenderContext(scale: .preview(maxDimension: maximumDimension), assets: [:], faces: analysis.faces,
            processVersion: candidate.processVersion, sourcePixelSize: photo.reference.pixelSize, skinMask: mask)
        let output = try renderer.renderStack(candidate, input: input, context: context)
        let ticket = PreviewTicket(id: UUID(), revision: revision, image: output, stack: stack,
                                   processVersion: candidate.processVersion)
        // Bound retained previews rather than silently dropping undo history.
        if tickets.count >= 4 { tickets.removeAll() }
        tickets[ticket.id] = ticket
        return ticket
    }

    /// Commit exactly a previously rendered candidate after the host obtains approval.
    /// Unchanged operations keep their provenance; changed operations belong to this session.
    public func setStack(_ stack: [RetouchOp], previewID: UUID, expectedRevision: Int,
                         sessionID: UUID, model: String? = nil) throws -> Int {
        guard revision == expectedRevision else { throw PortraitSessionError.staleRevision }
        guard let ticket = tickets[previewID] else { throw PortraitSessionError.previewNotFound }
        guard ticket.revision == revision, ticket.stack == stack else { throw PortraitSessionError.previewMismatch }
        guard history.count < 100 else { throw PortraitSessionError.historyFull }
        var candidate = document
        let existing = Dictionary(uniqueKeysWithValues: document.ops.map { ($0.id, $0) })
        candidate.ops = stack.map { op in
            if existing[op.id] == op { return op }
            var tagged = op
            tagged.origin = .ai(sessionID: sessionID, model: model)
            return tagged
        }
        candidate.processVersion = ticket.processVersion
        try validate(candidate)
        try persist(candidate)
        history.append(document)
        document = candidate
        revision += 1
        tickets.removeAll()
        return revision
    }

    /// Native-host undo restores the entire prior stack, including replaced user operations.
    /// It is intentionally not a fourth MCP tool in this first tool surface.
    public func undo() throws -> Int {
        guard let previous = history.last else { throw PortraitSessionError.emptyUndo }
        try persist(previous)
        history.removeLast()
        document = previous
        revision += 1
        tickets.removeAll()
        return revision
    }

    /// Current output without requiring a new approval or modifying history.
    public func renderCurrent(maximumDimension: Int = 1024) throws -> CGImage {
        try preview(stack: document.ops, maximumDimension: maximumDimension).image
    }

    private func validate(_ document: PortraitDocument) throws {
        guard (1...2).contains(document.processVersion) else { throw PortraitSessionError.unsupportedProcessVersion }
        guard Set(document.ops.map(\.id)).count == document.ops.count else { throw PortraitSessionError.duplicateOperationID }
        try document.validate()
        for op in document.renderOrder {
            switch op.kind {
            case .skin, .tone, .presence, .toneCurve, .whiteBalance: break
            default: throw PortraitSessionError.unsupportedOperation
            }
        }
    }

    private func persist(_ document: PortraitDocument) throws {
        guard let storageURL else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let next = try encoder.encode(document)
        // Freeze coverage with accepted edits; future detector improvements must not
        // silently repaint old documents. Invalid caches remain regenerable.
        let cache = try analysis.map { analysis in
            try encoder.encode(AnalysisCache(version: 1, sourceHash: photo.reference.contentHash,
                faces: analysis.faces, geometry: analysis.geometry, warnings: analysis.warnings,
                mask: PhotoIO.encode(analysis.skinMask)))
        }
        let expected = storedData
        var coordinationError: NSError?, writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: storageURL, options: .forReplacing, error: &coordinationError) { url in
            do {
                let actual = FileManager.default.fileExists(atPath: url.path) ? try Data(contentsOf: url) : nil
                guard actual == expected else { throw PortraitSessionError.externalChange }
                if let cache { try cache.write(to: storageURL.appendingPathExtension("analysis.json"), options: .atomic) }
                try next.write(to: url, options: .atomic)
            } catch { writeError = error }
        }
        if let error = coordinationError { throw error }
        if let error = writeError { throw error }
        storedData = next
    }
}

private struct AnalysisCache: Codable {
    let version: Int
    let sourceHash: String?
    let faces: [FaceAnalysis]
    let geometry: [FaceGeometry]
    let warnings: [String]
    let mask: Data
}
