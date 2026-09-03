import Foundation
import KanakaCore

public actor SessionAutosaveCoordinator {
    private struct PendingSave: Sendable {
        let snapshot: SavedSessionSnapshot
        let generation: UInt64
        let updatedAt: Date
    }

    public let fragmentID: String
    public let throttleDelay: Duration

    private let store: any ProgressStore
    private var generation: UInt64
    private var pendingSave: PendingSave?
    private var scheduledTask: Task<Void, Never>?

    public private(set) var lastAutosaveFailure: String?

    public init(
        fragmentID: String,
        persistedGeneration: UInt64,
        store: any ProgressStore,
        throttleDelay: Duration = .milliseconds(300)
    ) throws {
        guard !fragmentID.isEmpty else { throw ProgressStoreError.invalidFragmentID }
        self.fragmentID = fragmentID
        self.generation = persistedGeneration
        self.store = store
        self.throttleDelay = throttleDelay
    }

    deinit {
        scheduledTask?.cancel()
    }

    public var currentGeneration: UInt64 { generation }
    public var hasPendingSave: Bool { pendingSave != nil }

    /// Keeps only the newest snapshot and schedules a trailing-edge save.
    @discardableResult
    public func submit(
        snapshot: SavedSessionSnapshot,
        updatedAt: Date = Date()
    ) throws -> UInt64 {
        generation = try nextGeneration()
        let pending = PendingSave(
            snapshot: snapshot,
            generation: generation,
            updatedAt: updatedAt
        )
        pendingSave = pending
        scheduledTask?.cancel()

        let expectedGeneration = pending.generation
        let delay = throttleDelay
        scheduledTask = Task { [weak self] in
            do {
                try await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
                await self?.persistScheduled(generation: expectedGeneration)
            } catch is CancellationError {
                return
            } catch {
                await self?.recordScheduledFailure(
                    error,
                    generation: expectedGeneration
                )
            }
        }
        return generation
    }

    /// Cancels the throttle and waits until the latest submitted snapshot is durable.
    /// If durability fails, the captured snapshot remains pending so callers can retry.
    public func flush() async throws {
        scheduledTask?.cancel()
        scheduledTask = nil

        let pending = pendingSave
        do {
            if let pending {
                try await store.saveSession(
                    fragmentID: fragmentID,
                    snapshot: pending.snapshot,
                    generation: pending.generation,
                    updatedAt: pending.updatedAt
                )
            }
            try await store.flush()
            if let pending,
               pendingSave?.generation == pending.generation {
                pendingSave = nil
            }
            if pendingSave == nil { lastAutosaveFailure = nil }
        } catch {
            lastAutosaveFailure = String(describing: error)
            throw error
        }
    }

    /// Commits the final snapshot and completion timestamp through one store operation.
    public func complete(
        artworkID: String,
        requiredFragmentKeys: [ProgressRecordKey],
        session: GameSession,
        completedAt: Date = Date()
    ) async throws -> FragmentCompletionReceipt {
        guard session.isComplete else { throw ProgressStoreError.incompleteSession }
        scheduledTask?.cancel()
        scheduledTask = nil

        generation = try nextGeneration()
        let completionGeneration = generation
        let finalSnapshot = try session.makeSnapshot()
        let command = CompleteFragmentCommand(
            artworkID: artworkID,
            fragmentID: fragmentID,
            requiredFragmentKeys: requiredFragmentKeys,
            finalSnapshot: finalSnapshot,
            generation: completionGeneration,
            completedAt: completedAt
        )
        pendingSave = PendingSave(
            snapshot: finalSnapshot,
            generation: completionGeneration,
            updatedAt: completedAt
        )

        do {
            let receipt = try await store.completeFragment(command)
            try await store.flush()
            if let pending = pendingSave,
               pending.generation <= completionGeneration {
                pendingSave = nil
                lastAutosaveFailure = nil
            }
            return receipt
        } catch {
            lastAutosaveFailure = String(describing: error)
            throw error
        }
    }

    private func nextGeneration() throws -> UInt64 {
        let (next, overflow) = generation.addingReportingOverflow(1)
        guard !overflow else { throw ProgressStoreError.generationExhausted }
        return next
    }

    private func persistScheduled(generation expectedGeneration: UInt64) async {
        guard let pending = pendingSave,
              pending.generation == expectedGeneration else { return }
        do {
            try await store.saveSession(
                fragmentID: fragmentID,
                snapshot: pending.snapshot,
                generation: pending.generation,
                updatedAt: pending.updatedAt
            )
            if pendingSave?.generation == expectedGeneration {
                pendingSave = nil
                lastAutosaveFailure = nil
            }
        } catch {
            if pendingSave?.generation == expectedGeneration {
                lastAutosaveFailure = String(describing: error)
            }
        }
    }

    private func recordScheduledFailure(
        _ error: any Error,
        generation expectedGeneration: UInt64
    ) {
        if pendingSave?.generation == expectedGeneration {
            lastAutosaveFailure = String(describing: error)
        }
    }
}
