public protocol MuseumBlueprintEntitlementResolving: Sendable {
    func hasMuseumBlueprintEntitlement(_ museumID: String) -> Bool
}

public enum ArtworkRuleError: Error, Equatable, Sendable {
    case invalidRepairFragmentCount(actual: Int)
}

public struct ArtworkAccessState: Equatable, Sendable {
    public let artworkRestored: Bool
    public let canUseArtworkBlueprint: Bool
    public let hasRestorerSeal: Bool

    fileprivate init(
        artworkRestored: Bool,
        canUseArtworkBlueprint: Bool,
        hasRestorerSeal: Bool
    ) {
        self.artworkRestored = artworkRestored
        self.canUseArtworkBlueprint = canUseArtworkBlueprint
        self.hasRestorerSeal = hasRestorerSeal
    }
}

/// Derives access from current completion truth and an independent Museum entitlement.
///
/// `completedFragmentIDs` must contain only completions recognized for the Artwork's
/// current content identities. Legacy revision policy remains outside this evaluator.
public struct ArtworkAccessEvaluator: Sendable {
    private let entitlementResolver: any MuseumBlueprintEntitlementResolving

    public init(entitlementResolver: any MuseumBlueprintEntitlementResolving) {
        self.entitlementResolver = entitlementResolver
    }

    public func evaluate(
        artwork: ArtworkDefinition,
        completedFragmentIDs: Set<String>
    ) throws -> ArtworkAccessState {
        guard (1...4).contains(artwork.repairFragmentIDs.count) else {
            throw ArtworkRuleError.invalidRepairFragmentCount(
                actual: artwork.repairFragmentIDs.count
            )
        }

        let artworkRestored = artwork.repairFragmentIDs.allSatisfy(
            completedFragmentIDs.contains
        )
        return ArtworkAccessState(
            artworkRestored: artworkRestored,
            canUseArtworkBlueprint: artworkRestored
                || entitlementResolver.hasMuseumBlueprintEntitlement(artwork.museumID),
            hasRestorerSeal: artworkRestored
        )
    }
}
