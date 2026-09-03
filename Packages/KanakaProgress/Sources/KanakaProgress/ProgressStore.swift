import Foundation
import KanakaCore

public protocol ProgressStore: Sendable {
    func records(for fragmentID: String) async throws -> [FragmentProgressRecord]

    /// Fetches one exact identity without requiring sibling revisions to decode successfully.
    func record(for key: ProgressRecordKey) async throws -> FragmentProgressRecord?

    /// Reads one coherent exact-key snapshot. Missing keys are omitted.
    func records(
        for keys: Set<ProgressRecordKey>
    ) async throws -> [ProgressRecordKey: FragmentProgressRecord]

    func saveSession(
        fragmentID: String,
        snapshot: SavedSessionSnapshot,
        generation: UInt64,
        updatedAt: Date
    ) async throws

    func completeFragment(
        _ command: CompleteFragmentCommand
    ) async throws -> FragmentCompletionReceipt

    /// Persists all writes issued before this call or throws if durability cannot be reached.
    func flush() async throws
}

public extension ProgressStore {
    func record(for key: ProgressRecordKey) async throws -> FragmentProgressRecord? {
        try await records(for: key.fragmentID).first(where: { $0.key == key })
    }
}

public enum ProgressStoreError: Error, Equatable, CustomStringConvertible {
    case invalidFragmentID
    case staleGeneration(current: UInt64, attempted: UInt64)
    case invalidRequiredFragmentCount(Int)
    case duplicateRequiredFragment(ProgressRecordKey)
    case targetFragmentNotRequired(ProgressRecordKey)
    case snapshotIdentityMismatch(expected: ProgressRecordKey, actual: ProgressRecordKey)
    case incompleteSession
    case generationExhausted
    case persistentRecordCorrupt(String)
    case unsupportedPlatform(String)

    public var description: String {
        switch self {
        case .invalidFragmentID:
            return "Fragment ID must not be empty"
        case .staleGeneration(let current, let attempted):
            return "Refusing stale progress generation \(attempted); current generation is \(current)"
        case .invalidRequiredFragmentCount(let count):
            return "Artwork completion requires 1...4 fragment identities, found \(count)"
        case .duplicateRequiredFragment(let key):
            return "Artwork completion contains duplicate fragment identity: \(key.fragmentID)"
        case .targetFragmentNotRequired(let key):
            return "Completed fragment identity is not part of the Artwork: \(key.fragmentID)"
        case .snapshotIdentityMismatch(let expected, let actual):
            return "Snapshot identity for \(actual.fragmentID) does not match expected fragment \(expected.fragmentID)"
        case .incompleteSession:
            return "A Fragment cannot be completed from an incomplete GameSession"
        case .generationExhausted:
            return "Progress generation counter is exhausted"
        case .persistentRecordCorrupt(let reason):
            return "Persistent progress record is corrupt: \(reason)"
        case .unsupportedPlatform(let feature):
            return "\(feature) is unavailable on this platform"
        }
    }
}

public enum ProgressSessionLoader {
    public static func open(
        fragmentID: String,
        puzzle: PuzzleDefinition,
        store: any ProgressStore
    ) async throws -> ProgressSessionOpenResult {
        guard !fragmentID.isEmpty else { throw ProgressStoreError.invalidFragmentID }

        let currentKey = ProgressRecordKey(fragmentID: fragmentID, puzzle: puzzle)
        let candidate: FragmentProgressRecord?
        if let current = try await store.record(for: currentKey) {
            candidate = current
        } else {
            candidate = try await store.records(for: fragmentID)
                .sorted { lhs, rhs in
                    if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
                    return lhs.generation > rhs.generation
                }
                .first
        }

        guard let candidate else {
            return .new(session: try GameSession(puzzle: puzzle), generation: 0)
        }

        switch SessionRestoreEvaluator.evaluate(snapshot: candidate.snapshot, current: puzzle) {
        case .compatible:
            return .restored(
                session: try GameSession.restore(puzzle: puzzle, from: candidate.snapshot),
                generation: candidate.generation
            )
        case .requiresMigration(let mismatch):
            return .requiresMigration(record: candidate, mismatch: mismatch)
        case .corrupt(let reason):
            return .corrupt(record: candidate, reason: reason)
        }
    }
}

func validateCompletionCommand(
    _ command: CompleteFragmentCommand
) throws -> ProgressRecordKey {
    guard !command.fragmentID.isEmpty else { throw ProgressStoreError.invalidFragmentID }
    guard (1...4).contains(command.requiredFragmentKeys.count) else {
        throw ProgressStoreError.invalidRequiredFragmentCount(command.requiredFragmentKeys.count)
    }

    var seen = Set<ProgressRecordKey>()
    var seenFragmentIDs = Set<String>()
    for key in command.requiredFragmentKeys {
        guard seen.insert(key).inserted,
              seenFragmentIDs.insert(key.fragmentID).inserted else {
            throw ProgressStoreError.duplicateRequiredFragment(key)
        }
    }

    let actualKey = ProgressRecordKey(
        fragmentID: command.fragmentID,
        snapshot: command.finalSnapshot
    )
    guard command.requiredFragmentKeys.contains(actualKey) else {
        throw ProgressStoreError.targetFragmentNotRequired(actualKey)
    }
    return actualKey
}
