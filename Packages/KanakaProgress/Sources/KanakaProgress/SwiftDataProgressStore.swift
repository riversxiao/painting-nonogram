#if canImport(SwiftData)
import Foundation
import KanakaCore
import SwiftData

@available(iOS 17, macOS 14, *)
@Model
final class SwiftDataFragmentProgressEntity {
    var storageID: UUID
    var schemaVersion: Int
    var fragmentID: String
    var puzzleID: String
    var puzzleRevision: Int
    var puzzleSemanticHash: String
    var codecVersion: Int
    var width: Int
    var height: Int
    var cellCount: Int
    var paletteColorIDsData: Data
    var encodedCells: Data
    var assistanceHistoryData: Data
    /// Stored as decimal text so the complete UInt64 generation range remains representable.
    var generationText: String
    var updatedAt: Date
    var completedAt: Date?

    init(
        fragmentID: String,
        snapshot: SavedSessionSnapshot,
        generation: UInt64,
        updatedAt: Date,
        completedAt: Date? = nil
    ) throws {
        storageID = UUID()
        schemaVersion = KanakaProgressVersion.schema
        self.fragmentID = fragmentID
        puzzleID = snapshot.metadata.puzzleID
        puzzleRevision = snapshot.metadata.puzzleRevision
        puzzleSemanticHash = snapshot.metadata.puzzleSemanticHash
        codecVersion = snapshot.metadata.codecVersion
        width = snapshot.metadata.width
        height = snapshot.metadata.height
        cellCount = snapshot.metadata.cellCount
        paletteColorIDsData = try JSONEncoder().encode(snapshot.metadata.paletteColorIDsByIndex)
        encodedCells = snapshot.encodedCells
        assistanceHistoryData = try JSONEncoder().encode(snapshot.assistanceHistory)
        generationText = String(generation)
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }

    var key: ProgressRecordKey {
        ProgressRecordKey(
            fragmentID: fragmentID,
            puzzleID: puzzleID,
            puzzleRevision: puzzleRevision,
            puzzleSemanticHash: puzzleSemanticHash
        )
    }

    func replace(
        snapshot: SavedSessionSnapshot,
        generation: UInt64,
        updatedAt: Date
    ) throws {
        schemaVersion = KanakaProgressVersion.schema
        puzzleID = snapshot.metadata.puzzleID
        puzzleRevision = snapshot.metadata.puzzleRevision
        puzzleSemanticHash = snapshot.metadata.puzzleSemanticHash
        codecVersion = snapshot.metadata.codecVersion
        width = snapshot.metadata.width
        height = snapshot.metadata.height
        cellCount = snapshot.metadata.cellCount
        paletteColorIDsData = try JSONEncoder().encode(snapshot.metadata.paletteColorIDsByIndex)
        encodedCells = snapshot.encodedCells
        assistanceHistoryData = try JSONEncoder().encode(snapshot.assistanceHistory)
        generationText = String(generation)
        self.updatedAt = updatedAt
    }

    func domainRecord() throws -> FragmentProgressRecord {
        guard schemaVersion == KanakaProgressVersion.schema else {
            throw ProgressStoreError.persistentRecordCorrupt(
                "unsupported schema version \(schemaVersion)"
            )
        }
        guard let generation = UInt64(generationText) else {
            throw ProgressStoreError.persistentRecordCorrupt(
                "invalid generation \(generationText)"
            )
        }
        let palette: [String]
        let assistance: [AssistanceSource]
        do {
            palette = try JSONDecoder().decode([String].self, from: paletteColorIDsData)
            assistance = try JSONDecoder().decode(
                [AssistanceSource].self,
                from: assistanceHistoryData
            )
        } catch {
            throw ProgressStoreError.persistentRecordCorrupt(String(describing: error))
        }

        let snapshot = SavedSessionSnapshot(
            metadata: SavedSessionMetadata(
                codecVersion: codecVersion,
                puzzleID: puzzleID,
                puzzleRevision: puzzleRevision,
                puzzleSemanticHash: puzzleSemanticHash,
                width: width,
                height: height,
                cellCount: cellCount,
                paletteColorIDsByIndex: palette
            ),
            encodedCells: encodedCells,
            assistanceHistory: assistance
        )
        return FragmentProgressRecord(
            key: key,
            snapshot: snapshot,
            generation: generation,
            updatedAt: updatedAt,
            completedAt: completedAt
        )
    }
}

@available(iOS 17, macOS 14, *)
public actor SwiftDataProgressStore: ProgressStore {
    private let container: ModelContainer
    private let context: ModelContext

    public init(inMemoryOnly: Bool = false) throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemoryOnly)
        let container = try ModelContainer(
            for: SwiftDataFragmentProgressEntity.self,
            configurations: configuration
        )
        self.container = container
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    public init(container: ModelContainer) {
        self.container = container
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    public func records(for fragmentID: String) async throws -> [FragmentProgressRecord] {
        guard !fragmentID.isEmpty else { throw ProgressStoreError.invalidFragmentID }
        return try allEntities()
            .filter { $0.fragmentID == fragmentID }
            .map { try $0.domainRecord() }
    }

    public func record(for key: ProgressRecordKey) async throws -> FragmentProgressRecord? {
        guard !key.fragmentID.isEmpty else { throw ProgressStoreError.invalidFragmentID }
        return try allEntities()
            .first(where: { $0.key == key })
            .map { try $0.domainRecord() }
    }

    public func saveSession(
        fragmentID: String,
        snapshot: SavedSessionSnapshot,
        generation: UInt64,
        updatedAt: Date
    ) async throws {
        guard !fragmentID.isEmpty else { throw ProgressStoreError.invalidFragmentID }
        let key = ProgressRecordKey(fragmentID: fragmentID, snapshot: snapshot)
        let entities = try allEntities()

        if let existing = entities.first(where: { $0.key == key }) {
            let current = try existing.domainRecord()
            if generation < current.generation {
                throw ProgressStoreError.staleGeneration(
                    current: current.generation,
                    attempted: generation
                )
            }
            if generation == current.generation {
                guard snapshot == current.snapshot else {
                    throw ProgressStoreError.staleGeneration(
                        current: current.generation,
                        attempted: generation
                    )
                }
                return
            }
            try existing.replace(
                snapshot: snapshot,
                generation: generation,
                updatedAt: updatedAt
            )
        } else {
            context.insert(try SwiftDataFragmentProgressEntity(
                fragmentID: fragmentID,
                snapshot: snapshot,
                generation: generation,
                updatedAt: updatedAt
            ))
        }
        try context.save()
    }

    public func completeFragment(
        _ command: CompleteFragmentCommand
    ) async throws -> FragmentCompletionReceipt {
        let key = try validateCompletionCommand(command)
        var entities = try allEntities()
        let existing = entities.first(where: { $0.key == key })
        let current = try existing?.domainRecord()

        if let current {
            if command.generation < current.generation {
                throw ProgressStoreError.staleGeneration(
                    current: current.generation,
                    attempted: command.generation
                )
            }
            if command.generation == current.generation,
               command.finalSnapshot != current.snapshot {
                throw ProgressStoreError.staleGeneration(
                    current: current.generation,
                    attempted: command.generation
                )
            }
        }

        let newlyCompleted = current?.completedAt == nil
        let entity: SwiftDataFragmentProgressEntity
        if let existing {
            try existing.replace(
                snapshot: command.finalSnapshot,
                generation: max(command.generation, current?.generation ?? 0),
                updatedAt: command.completedAt
            )
            if existing.completedAt == nil { existing.completedAt = command.completedAt }
            entity = existing
        } else {
            entity = try SwiftDataFragmentProgressEntity(
                fragmentID: command.fragmentID,
                snapshot: command.finalSnapshot,
                generation: command.generation,
                updatedAt: command.completedAt,
                completedAt: command.completedAt
            )
            context.insert(entity)
            entities.append(entity)
        }

        // Snapshot and completion timestamp become durable in the same context save.
        try context.save()

        let completedKeys = Set(entities.compactMap { item in
            item.completedAt == nil ? nil : item.key
        })
        let completedCount = command.requiredFragmentKeys.reduce(into: 0) { count, requiredKey in
            if completedKeys.contains(requiredKey) { count += 1 }
        }
        return FragmentCompletionReceipt(
            artworkID: command.artworkID,
            fragmentKey: key,
            newlyCompleted: newlyCompleted,
            completedCount: completedCount,
            totalCount: command.requiredFragmentKeys.count,
            artworkRestored: completedCount == command.requiredFragmentKeys.count
        )
    }

    public func flush() async throws {
        if context.hasChanges { try context.save() }
    }

    private func allEntities() throws -> [SwiftDataFragmentProgressEntity] {
        try context.fetch(FetchDescriptor<SwiftDataFragmentProgressEntity>())
    }
}
#endif
