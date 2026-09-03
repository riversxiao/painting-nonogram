import Foundation
import KanakaContentKit
import KanakaCore
import KanakaProgress

public actor PuzzleSessionController {
    public nonisolated let flowID: UUID
    public nonisolated let fragmentID: String
    public nonisolated let artworkID: String
    public nonisolated let puzzle: PuzzleDefinition
    public nonisolated let requiredFragmentKeys: [ProgressRecordKey]

    private var session: GameSession
    private let autosave: SessionAutosaveCoordinator

    init(
        flowID: UUID,
        fragmentID: String,
        artworkID: String,
        puzzle: PuzzleDefinition,
        requiredFragmentKeys: [ProgressRecordKey],
        session: GameSession,
        generation: UInt64,
        progressStore: any ProgressStore,
        throttleDelay: Duration
    ) throws {
        self.flowID = flowID
        self.fragmentID = fragmentID
        self.artworkID = artworkID
        self.puzzle = puzzle
        self.requiredFragmentKeys = requiredFragmentKeys
        self.session = session
        autosave = try SessionAutosaveCoordinator(
            fragmentID: fragmentID,
            persistedGeneration: generation,
            store: progressStore,
            throttleDelay: throttleDelay
        )
    }

    @discardableResult
    public func apply(
        _ edits: [CellEdit],
        assistance: AssistanceSource? = nil,
        updatedAt: Date = Date()
    ) async throws -> SessionChange {
        let change = try session.applyBatch(edits, assistance: assistance)
        if !change.changedCoordinates.isEmpty || change.assistanceAdded != nil {
            _ = try await autosave.submit(snapshot: session.makeSnapshot(), updatedAt: updatedAt)
        }
        return change
    }

    @discardableResult
    public func recordAssistance(
        _ source: AssistanceSource,
        updatedAt: Date = Date()
    ) async throws -> SessionChange {
        let change = session.recordAssistance(source)
        if change.assistanceAdded != nil {
            _ = try await autosave.submit(snapshot: session.makeSnapshot(), updatedAt: updatedAt)
        }
        return change
    }

    /// Explicitly schedules the current snapshot. Normal mutations autosave automatically.
    public func submit(updatedAt: Date = Date()) async throws -> UInt64 {
        try await autosave.submit(snapshot: session.makeSnapshot(), updatedAt: updatedAt)
    }

    public func flush() async throws {
        try await autosave.flush()
    }

    public func complete(completedAt: Date = Date()) async throws -> FragmentCompletionReceipt {
        try await autosave.complete(
            artworkID: artworkID,
            requiredFragmentKeys: requiredFragmentKeys,
            session: session,
            completedAt: completedAt
        )
    }

    public func currentSession() -> GameSession { session }
}
