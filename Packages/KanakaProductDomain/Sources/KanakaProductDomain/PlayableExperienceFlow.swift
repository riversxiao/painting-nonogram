import KanakaContentKit
import KanakaStory

public enum TutorialDisposition: String, Codable, Equatable, Sendable {
    case completed
    case skipped
}

public enum PlayableExperiencePhase: Equatable, Sendable {
    case worldIntro
    case tutorial
    case routeChoice
    case ready(PlayableExperienceRoute)
}

public struct PlayableExperienceState: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public let version: Int
    public internal(set) var hasAcknowledgedWorldIntro: Bool
    public internal(set) var tutorialDisposition: TutorialDisposition?
    public internal(set) var initialRoute: PlayableExperienceRoute?

    public init(
        version: Int = currentVersion,
        hasAcknowledgedWorldIntro: Bool = false,
        tutorialDisposition: TutorialDisposition? = nil,
        initialRoute: PlayableExperienceRoute? = nil
    ) {
        self.version = version
        self.hasAcknowledgedWorldIntro = hasAcknowledgedWorldIntro
        self.tutorialDisposition = tutorialDisposition
        self.initialRoute = initialRoute
    }

    public var phase: PlayableExperiencePhase {
        guard hasAcknowledgedWorldIntro else { return .worldIntro }
        guard tutorialDisposition != nil else { return .tutorial }
        guard let initialRoute else { return .routeChoice }
        return .ready(initialRoute)
    }
}

public enum PlayableExperienceFlowError: Error, Equatable, CustomStringConvertible {
    case unsupportedStateVersion(Int)
    case invalidState(String)
    case invalidTransition(from: PlayableExperiencePhase, action: String)

    public var description: String {
        switch self {
        case .unsupportedStateVersion(let version):
            "Unsupported playable experience state version: \(version)"
        case .invalidState(let reason):
            "Invalid playable experience state: \(reason)"
        case .invalidTransition(let phase, let action):
            "Cannot \(action) during playable experience phase \(phase)"
        }
    }
}

public struct PlayableExperienceFlow: Sendable {
    public private(set) var state: PlayableExperienceState

    public init(state: PlayableExperienceState = PlayableExperienceState()) throws {
        guard state.version == PlayableExperienceState.currentVersion else {
            throw PlayableExperienceFlowError.unsupportedStateVersion(state.version)
        }
        guard state.hasAcknowledgedWorldIntro
                || (state.tutorialDisposition == nil && state.initialRoute == nil) else {
            throw PlayableExperienceFlowError.invalidState(
                "tutorial or route cannot precede world intro"
            )
        }
        guard state.tutorialDisposition != nil || state.initialRoute == nil else {
            throw PlayableExperienceFlowError.invalidState(
                "initial route cannot precede tutorial completion or skip"
            )
        }
        self.state = state
    }

    public mutating func acknowledgeWorldIntro() throws {
        guard state.phase == .worldIntro else {
            throw PlayableExperienceFlowError.invalidTransition(
                from: state.phase,
                action: "acknowledge world intro"
            )
        }
        state.hasAcknowledgedWorldIntro = true
    }

    public mutating func completeTutorial() throws {
        try finishTutorial(.completed)
    }

    public mutating func skipTutorial() throws {
        try finishTutorial(.skipped)
    }

    public mutating func chooseInitialRoute(_ route: PlayableExperienceRoute) throws {
        guard state.phase == .routeChoice else {
            throw PlayableExperienceFlowError.invalidTransition(
                from: state.phase,
                action: "choose initial route"
            )
        }
        state.initialRoute = route
    }

    public mutating func reset() {
        state = PlayableExperienceState()
    }

    private mutating func finishTutorial(_ disposition: TutorialDisposition) throws {
        guard state.phase == .tutorial else {
            throw PlayableExperienceFlowError.invalidTransition(
                from: state.phase,
                action: "finish tutorial"
            )
        }
        state.tutorialDisposition = disposition
    }
}

public protocol PlayableExperienceStateStore: Sendable {
    func load() async throws -> PlayableExperienceState?
    func save(_ state: PlayableExperienceState) async throws
}

public actor InMemoryPlayableExperienceStateStore: PlayableExperienceStateStore {
    private var state: PlayableExperienceState?

    public init(state: PlayableExperienceState? = nil) {
        self.state = state
    }

    public func load() async throws -> PlayableExperienceState? { state }

    public func save(_ state: PlayableExperienceState) async throws {
        self.state = state
    }
}

public struct CompletionFeedback: Equatable, Sendable {
    public let completedCount: Int
    public let totalCount: Int
    public let isArtworkRestored: Bool
    public let blueprintAvailable: Bool
    public let restorerSealAwarded: Bool
    public let newlyAcceptedEvidenceIDs: [StoryEvidenceID]
    public let newlyAchievedMilestones: [StoryMilestoneID]

    public init(outcome: FragmentCompletionOutcome) {
        completedCount = outcome.receipt.completedCount
        totalCount = outcome.receipt.totalCount
        isArtworkRestored = outcome.artworkState.access.artworkRestored
        blueprintAvailable = outcome.artworkState.access.canUseArtworkBlueprint
        restorerSealAwarded = outcome.artworkState.access.hasRestorerSeal

        var evidence: [StoryEvidenceID] = []
        var milestones: [StoryMilestoneID] = []
        for decision in outcome.storyDecisions {
            guard case .applied(let newlyAchieved, let audit) = decision else { continue }
            evidence.append(audit.evidenceID)
            milestones.append(contentsOf: newlyAchieved)
        }
        newlyAcceptedEvidenceIDs = evidence
        newlyAchievedMilestones = milestones
    }
}
