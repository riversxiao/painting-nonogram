import Foundation

public enum StoryMilestoneID: String, Codable, CaseIterable, Hashable, Sendable {
    case technicalChainRestored
    case bridgeLocated
    case bridgeBrieflyStarted
    case bridgeRebooted
    case firstPostCollapseFullEntryCompleted
    case firstGenerationPurgeRevealed
    case newOperatorDetected

    public var prerequisite: StoryMilestoneID? {
        switch self {
        case .technicalChainRestored: nil
        case .bridgeLocated: .technicalChainRestored
        case .bridgeBrieflyStarted: .bridgeLocated
        case .bridgeRebooted: .bridgeBrieflyStarted
        case .firstPostCollapseFullEntryCompleted: .bridgeRebooted
        case .firstGenerationPurgeRevealed: .firstPostCollapseFullEntryCompleted
        case .newOperatorDetected: .firstGenerationPurgeRevealed
        }
    }
}

public struct StoryEvidenceID: RawRepresentable, Codable, Equatable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

public struct StoryEvidenceOccurrenceID: RawRepresentable, Codable, Equatable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
}

public enum StoryEvidenceSourceKind: String, Codable, Equatable, Hashable, Sendable {
    case fragmentCompletion
    case artworkRestoration
    case narrativeAction
    case bridgeSession
}

public struct StoryEvidenceSource: Codable, Equatable, Hashable, Sendable {
    public let kind: StoryEvidenceSourceKind
    public let referenceID: String
    public let sessionID: String?

    public init(kind: StoryEvidenceSourceKind, referenceID: String, sessionID: String? = nil) {
        self.kind = kind
        self.referenceID = referenceID
        self.sessionID = sessionID
    }
}

public struct StoryEvidenceEnvelope: Codable, Equatable, Hashable, Sendable {
    public let occurrenceID: StoryEvidenceOccurrenceID
    public let evidenceID: StoryEvidenceID
    public let source: StoryEvidenceSource
    public let occurredAt: Date
    public let rulesRevision: Int

    public init(
        occurrenceID: StoryEvidenceOccurrenceID,
        evidenceID: StoryEvidenceID,
        source: StoryEvidenceSource,
        occurredAt: Date,
        rulesRevision: Int
    ) {
        self.occurrenceID = occurrenceID
        self.evidenceID = evidenceID
        self.source = source
        self.occurredAt = occurredAt
        self.rulesRevision = rulesRevision
    }
}

public struct StoryMilestoneAchievement: Codable, Equatable, Sendable {
    public let milestone: StoryMilestoneID
    public let achievedAt: Date
    public let evidenceOccurrenceID: StoryEvidenceOccurrenceID
    public let rulesRevision: Int
}

public struct StoryState: Codable, Equatable, Sendable {
    public let rulesID: String
    public let rulesRevision: Int
    public internal(set) var acceptedEvidence: [StoryEvidenceEnvelope]
    public internal(set) var achievements: [StoryMilestoneAchievement]

    public init(rulesID: String, rulesRevision: Int) {
        self.rulesID = rulesID
        self.rulesRevision = rulesRevision
        acceptedEvidence = []
        achievements = []
    }

    public var achievedMilestones: Set<StoryMilestoneID> {
        Set(achievements.map(\.milestone))
    }

    public func hasAchieved(_ milestone: StoryMilestoneID) -> Bool {
        achievements.contains { $0.milestone == milestone }
    }
}

public enum StoryTransitionError: Error, Equatable, Sendable {
    case rulesMismatch(expectedID: String, expectedRevision: Int, actualID: String, actualRevision: Int)
    case unknownEvidence(StoryEvidenceID)
    case evidenceIdentityCollision(StoryEvidenceOccurrenceID)
    case forbiddenEvidenceSource(expected: StoryEvidenceSourceKind, actual: StoryEvidenceSourceKind)
    case evidenceOutOfSequence(expected: StoryEvidenceID, actual: StoryEvidenceID)
    case missingPrerequisite(target: StoryMilestoneID, required: StoryMilestoneID)
    case invalidRuleConfiguration(String)
}

public struct StoryAuditRecord: Equatable, Sendable {
    public let occurrenceID: StoryEvidenceOccurrenceID
    public let evidenceID: StoryEvidenceID
    public let accepted: Bool
    public let newlyAchievedMilestones: [StoryMilestoneID]
    public let rejection: StoryTransitionError?
}

public enum StoryTransitionDecision: Equatable, Sendable {
    case applied(newlyAchieved: [StoryMilestoneID], audit: StoryAuditRecord)
    case alreadyApplied(audit: StoryAuditRecord)
    case rejected(StoryTransitionError, audit: StoryAuditRecord)
}
