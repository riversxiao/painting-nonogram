import Foundation
import KanakaCore

public struct ProgressRecordKey: Codable, Equatable, Hashable, Sendable {
    public let fragmentID: String
    public let puzzleID: String
    public let puzzleRevision: Int
    public let puzzleSemanticHash: String

    public init(
        fragmentID: String,
        puzzleID: String,
        puzzleRevision: Int,
        puzzleSemanticHash: String
    ) {
        self.fragmentID = fragmentID
        self.puzzleID = puzzleID
        self.puzzleRevision = puzzleRevision
        self.puzzleSemanticHash = puzzleSemanticHash
    }

    public init(fragmentID: String, snapshot: SavedSessionSnapshot) {
        self.init(
            fragmentID: fragmentID,
            puzzleID: snapshot.metadata.puzzleID,
            puzzleRevision: snapshot.metadata.puzzleRevision,
            puzzleSemanticHash: snapshot.metadata.puzzleSemanticHash
        )
    }

    public init(fragmentID: String, puzzle: PuzzleDefinition) {
        self.init(
            fragmentID: fragmentID,
            puzzleID: puzzle.id,
            puzzleRevision: puzzle.revision,
            puzzleSemanticHash: puzzle.semanticHash
        )
    }
}

public struct FragmentProgressRecord: Codable, Equatable, Sendable {
    public let key: ProgressRecordKey
    public let snapshot: SavedSessionSnapshot
    public let generation: UInt64
    public let updatedAt: Date
    public let completedAt: Date?

    public init(
        key: ProgressRecordKey,
        snapshot: SavedSessionSnapshot,
        generation: UInt64,
        updatedAt: Date,
        completedAt: Date?
    ) {
        self.key = key
        self.snapshot = snapshot
        self.generation = generation
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }
}

public struct CompleteFragmentCommand: Sendable {
    public let artworkID: String
    public let fragmentID: String
    public let requiredFragmentKeys: [ProgressRecordKey]
    public let finalSnapshot: SavedSessionSnapshot
    public let generation: UInt64
    public let completedAt: Date

    public init(
        artworkID: String,
        fragmentID: String,
        requiredFragmentKeys: [ProgressRecordKey],
        finalSnapshot: SavedSessionSnapshot,
        generation: UInt64,
        completedAt: Date
    ) {
        self.artworkID = artworkID
        self.fragmentID = fragmentID
        self.requiredFragmentKeys = requiredFragmentKeys
        self.finalSnapshot = finalSnapshot
        self.generation = generation
        self.completedAt = completedAt
    }
}

public struct FragmentCompletionReceipt: Equatable, Sendable {
    public let artworkID: String
    public let fragmentKey: ProgressRecordKey
    public let newlyCompleted: Bool
    public let completedCount: Int
    public let totalCount: Int

    public init(
        artworkID: String,
        fragmentKey: ProgressRecordKey,
        newlyCompleted: Bool,
        completedCount: Int,
        totalCount: Int
    ) {
        self.artworkID = artworkID
        self.fragmentKey = fragmentKey
        self.newlyCompleted = newlyCompleted
        self.completedCount = completedCount
        self.totalCount = totalCount
    }
}

public enum ProgressSessionOpenResult: Sendable {
    case new(session: GameSession, generation: UInt64)
    case restored(session: GameSession, generation: UInt64)
    case requiresMigration(record: FragmentProgressRecord, mismatch: RestoreMismatch)
    case corrupt(record: FragmentProgressRecord, reason: SavedStateCorruption)
}
