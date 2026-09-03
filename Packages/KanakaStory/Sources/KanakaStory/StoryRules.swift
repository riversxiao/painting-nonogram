public struct StoryEvidenceRule: Equatable, Sendable {
    public let evidenceID: StoryEvidenceID
    public let sourceKind: StoryEvidenceSourceKind
    public let achievesMilestone: StoryMilestoneID?

    public init(
        evidenceID: StoryEvidenceID,
        sourceKind: StoryEvidenceSourceKind,
        achievesMilestone: StoryMilestoneID? = nil
    ) {
        self.evidenceID = evidenceID
        self.sourceKind = sourceKind
        self.achievesMilestone = achievesMilestone
    }
}

public struct StoryRuleSet: Equatable, Sendable {
    public let id: String
    public let revision: Int
    public let orderedEvidence: [StoryEvidenceRule]

    public init(id: String, revision: Int, orderedEvidence: [StoryEvidenceRule]) throws {
        guard !id.isEmpty, revision > 0, !orderedEvidence.isEmpty else {
            throw StoryTransitionError.invalidRuleConfiguration("rules require id, positive revision, and evidence")
        }
        guard Set(orderedEvidence.map(\.evidenceID)).count == orderedEvidence.count else {
            throw StoryTransitionError.invalidRuleConfiguration("evidence IDs must be unique")
        }

        var achieved = Set<StoryMilestoneID>()
        for rule in orderedEvidence {
            if let milestone = rule.achievesMilestone {
                if let prerequisite = milestone.prerequisite, !achieved.contains(prerequisite) {
                    throw StoryTransitionError.invalidRuleConfiguration(
                        "milestone \(milestone.rawValue) precedes \(prerequisite.rawValue)"
                    )
                }
                guard achieved.insert(milestone).inserted else {
                    throw StoryTransitionError.invalidRuleConfiguration(
                        "milestone \(milestone.rawValue) is assigned more than once"
                    )
                }
            }
        }
        self.id = id
        self.revision = revision
        self.orderedEvidence = orderedEvidence
    }
}

public enum Museum1StoryRules {
    public static let id = "museum-1-canon-v1"
    public static let revision = 1

    public static func make() throws -> StoryRuleSet {
        try StoryRuleSet(id: id, revision: revision, orderedEvidence: [
            artwork("m1.a01.restored"),
            artwork("m1.a02.restored"),
            artwork("m1.a03.restored"),
            artwork("m1.a04.restored"),
            artwork("m1.a05.restored"),
            artwork("m1.a06.restored", achieves: .technicalChainRestored),
            narrative("m1.bridge.located", achieves: .bridgeLocated),
            session("m1.bridge.briefly-started", achieves: .bridgeBrieflyStarted),
            artwork("m1.a07.restored"),
            artwork("m1.a08.restored"),
            artwork("m1.a09.restored"),
            artwork("m1.a10.restored"),
            artwork("m1.a11.restored"),
            session("m1.a12.bridge-rebooted", achieves: .bridgeRebooted),
            fragment("m1.a12.fragment-1-restored"),
            fragment("m1.a12.fragment-2-restored"),
            fragment("m1.a12.fragment-3-restored"),
            session("m1.a12.safe-exit", achieves: .firstPostCollapseFullEntryCompleted),
            artwork("m1.a13.restored"),
            artwork("m1.a14.restored"),
            artwork("m1.a15.restored"),
            artwork("m1.a16.restored"),
            artwork("m1.a17.restored"),
            fragment("m1.a18.fragment-1-restored"),
            fragment("m1.a18.fragment-2-restored"),
            fragment("m1.a18.fragment-3-restored"),
            fragment("m1.a18.fragment-4-restored", achieves: .firstGenerationPurgeRevealed),
            session("m1.a18.new-operator-detected", achieves: .newOperatorDetected),
        ])
    }

    private static func artwork(
        _ id: String,
        achieves milestone: StoryMilestoneID? = nil
    ) -> StoryEvidenceRule {
        StoryEvidenceRule(
            evidenceID: StoryEvidenceID(rawValue: id),
            sourceKind: .artworkRestoration,
            achievesMilestone: milestone
        )
    }

    private static func fragment(_ id: String, achieves milestone: StoryMilestoneID? = nil) -> StoryEvidenceRule {
        StoryEvidenceRule(
            evidenceID: StoryEvidenceID(rawValue: id),
            sourceKind: .fragmentCompletion,
            achievesMilestone: milestone
        )
    }

    private static func narrative(_ id: String, achieves milestone: StoryMilestoneID? = nil) -> StoryEvidenceRule {
        StoryEvidenceRule(
            evidenceID: StoryEvidenceID(rawValue: id),
            sourceKind: .narrativeAction,
            achievesMilestone: milestone
        )
    }

    private static func session(_ id: String, achieves milestone: StoryMilestoneID? = nil) -> StoryEvidenceRule {
        StoryEvidenceRule(
            evidenceID: StoryEvidenceID(rawValue: id),
            sourceKind: .bridgeSession,
            achievesMilestone: milestone
        )
    }
}
