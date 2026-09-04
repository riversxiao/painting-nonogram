import Foundation
import KanakaContentKit
import KanakaProgress
import KanakaStory

public struct MuseumEntitlementSnapshot: MuseumBlueprintEntitlementResolving, Equatable, Sendable {
    public let museumIDs: Set<String>

    public init(museumIDs: Set<String> = []) {
        self.museumIDs = museumIDs
    }

    public func hasMuseumBlueprintEntitlement(_ museumID: String) -> Bool {
        museumIDs.contains(museumID)
    }
}

public struct FragmentProductState: Equatable, Sendable {
    public let fragmentID: String
    public let currentKey: ProgressRecordKey
    public let isCompleted: Bool
    public let completedAt: Date?
}

public struct ArtworkProductState: Equatable, Sendable {
    public let artworkID: String
    public let fragments: [FragmentProductState]
    public let completedCount: Int
    public let totalCount: Int
    public let access: ArtworkAccessState
}

public enum FragmentRestorationStatus: Equatable, Sendable {
    case notStarted
    case inProgress(updatedAt: Date)
    case completed(completedAt: Date)

    public var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }
}

public struct FragmentRestorationState: Equatable, Sendable {
    public let fragmentID: String
    public let currentKey: ProgressRecordKey
    public let status: FragmentRestorationStatus
}

/// UI-facing progress projection derived from one coherent exact-current record snapshot.
/// Opening a session alone is intentionally not considered progress.
public struct ArtworkRestorationSnapshot: Equatable, Sendable {
    public let artworkState: ArtworkProductState
    public let fragments: [FragmentRestorationState]
}

public struct AuthorizedBlueprint: Equatable, Sendable {
    public let blueprint: BlueprintDefinition
    public let exportPlan: BlueprintExportPlan
}

public struct FragmentCompletionOutcome: Sendable {
    public let receipt: FragmentCompletionReceipt
    public let artworkState: ArtworkProductState
    public let storyDecisions: [StoryTransitionDecision]
}

public enum ProductDomainError: Error, Equatable, CustomStringConvertible {
    case migrationRequired(String)
    case corruptProgress(String)
    case blueprintAccessDenied(String)
    case sessionBelongsToAnotherFlow
    case inconsistentCompletionReceipt
    case invalidStoryMapping(String)
    case sessionFinalized

    public var description: String {
        switch self {
        case .migrationRequired(let reason): "Progress migration required: \(reason)"
        case .corruptProgress(let reason): "Progress is corrupt: \(reason)"
        case .blueprintAccessDenied(let artworkID): "Blueprint access denied for Artwork \(artworkID)"
        case .sessionBelongsToAnotherFlow: "Puzzle session does not belong to this product flow"
        case .inconsistentCompletionReceipt: "Completion receipt does not match current Artwork content"
        case .invalidStoryMapping(let reason): "Invalid completion-to-Story mapping: \(reason)"
        case .sessionFinalized: "Completed puzzle session is read-only"
        }
    }
}

public struct CompletionStoryMapping: Equatable, Sendable {
    public let fragmentEvidence: [String: StoryEvidenceID]
    public let artworkEvidence: [String: StoryEvidenceID]

    public init(
        fragmentEvidence: [String: StoryEvidenceID] = [:],
        artworkEvidence: [String: StoryEvidenceID] = [:]
    ) {
        self.fragmentEvidence = fragmentEvidence
        self.artworkEvidence = artworkEvidence
    }
}
