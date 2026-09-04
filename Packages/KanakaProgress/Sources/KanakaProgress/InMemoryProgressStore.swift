import Foundation
import KanakaCore

/// Deterministic store used by previews, CLI validation, and non-SwiftData environments.
public actor InMemoryProgressStore: ProgressStore {
    private var recordsByKey: [ProgressRecordKey: FragmentProgressRecord] = [:]

    public init() {}

    public func records(for fragmentID: String) async throws -> [FragmentProgressRecord] {
        guard !fragmentID.isEmpty else { throw ProgressStoreError.invalidFragmentID }
        return recordsByKey.values.filter { $0.key.fragmentID == fragmentID }
    }

    public func record(for key: ProgressRecordKey) async throws -> FragmentProgressRecord? {
        guard !key.fragmentID.isEmpty else { throw ProgressStoreError.invalidFragmentID }
        return recordsByKey[key]
    }

    public func records(
        for keys: Set<ProgressRecordKey>
    ) async throws -> [ProgressRecordKey: FragmentProgressRecord] {
        var result: [ProgressRecordKey: FragmentProgressRecord] = [:]
        for key in keys {
            if let record = recordsByKey[key] { result[key] = record }
        }
        return result
    }

    public func saveSession(
        fragmentID: String,
        snapshot: SavedSessionSnapshot,
        generation: UInt64,
        updatedAt: Date
    ) async throws {
        guard !fragmentID.isEmpty else { throw ProgressStoreError.invalidFragmentID }
        let key = ProgressRecordKey(fragmentID: fragmentID, snapshot: snapshot)

        if let existing = recordsByKey[key] {
            if generation < existing.generation {
                throw ProgressStoreError.staleGeneration(
                    current: existing.generation,
                    attempted: generation
                )
            }
            if generation == existing.generation {
                guard snapshot == existing.snapshot else {
                    throw ProgressStoreError.staleGeneration(
                        current: existing.generation,
                        attempted: generation
                    )
                }
                return
            }
            if existing.completedAt != nil, snapshot != existing.snapshot {
                throw ProgressStoreError.completedSnapshotImmutable(key)
            }
        }

        recordsByKey[key] = FragmentProgressRecord(
            key: key,
            snapshot: snapshot,
            generation: generation,
            updatedAt: updatedAt,
            completedAt: recordsByKey[key]?.completedAt
        )
    }

    public func completeFragment(
        _ command: CompleteFragmentCommand
    ) async throws -> FragmentCompletionReceipt {
        let key = try validateCompletionCommand(command)
        let existing = recordsByKey[key]

        if let existing, existing.completedAt != nil,
           command.finalSnapshot != existing.snapshot {
            throw ProgressStoreError.completedSnapshotImmutable(key)
        }

        if let existing {
            if command.generation < existing.generation {
                throw ProgressStoreError.staleGeneration(
                    current: existing.generation,
                    attempted: command.generation
                )
            }
            if command.generation == existing.generation,
               command.finalSnapshot != existing.snapshot {
                throw ProgressStoreError.staleGeneration(
                    current: existing.generation,
                    attempted: command.generation
                )
            }
        }

        let newlyCompleted = existing?.completedAt == nil
        recordsByKey[key] = FragmentProgressRecord(
            key: key,
            snapshot: command.finalSnapshot,
            generation: max(command.generation, existing?.generation ?? 0),
            updatedAt: command.completedAt,
            completedAt: existing?.completedAt ?? command.completedAt
        )

        let completedAtByKey = Dictionary(uniqueKeysWithValues: command.requiredFragmentKeys.compactMap { requiredKey in
            recordsByKey[requiredKey]?.completedAt.map { (requiredKey, $0) }
        })
        return FragmentCompletionReceipt(
            artworkID: command.artworkID,
            fragmentKey: key,
            newlyCompleted: newlyCompleted,
            completedCount: completedAtByKey.count,
            totalCount: command.requiredFragmentKeys.count,
            completedAtByFragmentKey: completedAtByKey
        )
    }

    public func flush() async throws {}
}
