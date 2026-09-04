#if canImport(SwiftData)
import Foundation
import SwiftData

@Model
final class SwiftDataStoryStateEntity {
    @Attribute(.unique) var rulesID: String
    var rulesRevision: Int
    var stateData: Data
    var updatedAt: Date

    init(rulesID: String, rulesRevision: Int, stateData: Data, updatedAt: Date) {
        self.rulesID = rulesID
        self.rulesRevision = rulesRevision
        self.stateData = stateData
        self.updatedAt = updatedAt
    }
}

public enum SwiftDataStoryStateStoreError: Error, Equatable, CustomStringConvertible {
    case duplicateRulesID(String)
    case corruptState(String)

    public var description: String {
        switch self {
        case .duplicateRulesID(let rulesID):
            "Multiple StoryState rows exist for rules ID \(rulesID)"
        case .corruptState(let reason):
            "Persisted StoryState is corrupt: \(reason)"
        }
    }
}

/// Single-process SwiftData implementation of StoryStateStore.
///
/// Actor isolation serializes all writers. Each accepted envelope is fetched, reduced, encoded,
/// and saved without suspension, preserving the protocol's atomic apply boundary. A future
/// multi-process writer must add backend compare-and-swap rather than constructing another store.
public actor SwiftDataStoryStateStore: StoryStateStore {
    private let context: ModelContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(container: ModelContainer? = nil) throws {
        let resolved: ModelContainer
        if let container {
            resolved = container
        } else {
            // Keep Story persistence in a named store distinct from Progress's container.
            let configuration = ModelConfiguration("KanakaStory")
            resolved = try ModelContainer(
                for: SwiftDataStoryStateEntity.self,
                configurations: configuration
            )
        }
        context = ModelContext(resolved)
        context.autosaveEnabled = false
    }

    public func load(rules: StoryRuleSet) async throws -> StoryState {
        guard let entity = try entity(for: rules.id) else {
            return StoryState(rulesID: rules.id, rulesRevision: rules.revision)
        }
        return try decode(entity)
    }

    public func apply(
        _ envelope: StoryEvidenceEnvelope,
        using rules: StoryRuleSet
    ) async throws -> StoryTransitionDecision {
        let existing = try entity(for: rules.id)
        let state = try existing.map(decode)
            ?? StoryState(rulesID: rules.id, rulesRevision: rules.revision)
        let result = StoryReducer.applying(envelope, to: state, using: rules)
        guard case .applied = result.decision else { return result.decision }

        do {
            let data = try encoder.encode(result.state)
            if let existing {
                existing.rulesRevision = result.state.rulesRevision
                existing.stateData = data
                existing.updatedAt = envelope.occurredAt
            } else {
                context.insert(SwiftDataStoryStateEntity(
                    rulesID: result.state.rulesID,
                    rulesRevision: result.state.rulesRevision,
                    stateData: data,
                    updatedAt: envelope.occurredAt
                ))
            }
            try context.save()
            return result.decision
        } catch {
            context.rollback()
            throw error
        }
    }

    public func flush() throws {
        if context.hasChanges { try context.save() }
    }

    private func entity(for rulesID: String) throws -> SwiftDataStoryStateEntity? {
        let requestedID = rulesID
        var descriptor = FetchDescriptor<SwiftDataStoryStateEntity>(
            predicate: #Predicate { $0.rulesID == requestedID }
        )
        descriptor.fetchLimit = 2
        let matches = try context.fetch(descriptor)
        guard matches.count <= 1 else {
            throw SwiftDataStoryStateStoreError.duplicateRulesID(rulesID)
        }
        return matches.first
    }

    private func decode(_ entity: SwiftDataStoryStateEntity) throws -> StoryState {
        do {
            let state = try decoder.decode(StoryState.self, from: entity.stateData)
            guard state.rulesID == entity.rulesID,
                  state.rulesRevision == entity.rulesRevision else {
                throw SwiftDataStoryStateStoreError.corruptState(
                    "row identity differs from encoded state"
                )
            }
            return state
        } catch let error as SwiftDataStoryStateStoreError {
            throw error
        } catch {
            throw SwiftDataStoryStateStoreError.corruptState(String(describing: error))
        }
    }
}
#endif
