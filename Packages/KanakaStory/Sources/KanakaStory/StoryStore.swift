public protocol StoryStateStore: Sendable {
    func load(rules: StoryRuleSet) async throws -> StoryState
    /// Atomically loads, reduces, and persists one evidence envelope.
    func apply(
        _ envelope: StoryEvidenceEnvelope,
        using rules: StoryRuleSet
    ) async throws -> StoryTransitionDecision
}

public actor InMemoryStoryStateStore: StoryStateStore {
    private var states: [String: StoryState] = [:]

    public init() {}

    public func load(rules: StoryRuleSet) async throws -> StoryState {
        states[rules.id] ?? StoryState(rulesID: rules.id, rulesRevision: rules.revision)
    }

    public func apply(
        _ envelope: StoryEvidenceEnvelope,
        using rules: StoryRuleSet
    ) async throws -> StoryTransitionDecision {
        let state = states[rules.id] ?? StoryState(rulesID: rules.id, rulesRevision: rules.revision)
        let result = StoryReducer.applying(envelope, to: state, using: rules)
        if case .applied = result.decision {
            states[rules.id] = result.state
        }
        return result.decision
    }
}

public actor StoryEventProcessor {
    private let store: any StoryStateStore
    public nonisolated let rules: StoryRuleSet

    public init(store: any StoryStateStore, rules: StoryRuleSet) {
        self.store = store
        self.rules = rules
    }

    public func submit(_ envelope: StoryEvidenceEnvelope) async throws -> StoryTransitionDecision {
        try await store.apply(envelope, using: rules)
    }

    public func state() async throws -> StoryState {
        try await store.load(rules: rules)
    }
}
