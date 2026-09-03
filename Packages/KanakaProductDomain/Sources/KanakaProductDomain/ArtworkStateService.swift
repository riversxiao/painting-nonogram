import Foundation
@_spi(KanakaProductDomain) import KanakaContentKit
import KanakaProgress

public struct ArtworkStateService: Sendable {
    fileprivate let catalog: RuntimeContentCatalog
    private let progressStore: any ProgressStore

    public init(catalog: RuntimeContentCatalog, progressStore: any ProgressStore) {
        self.catalog = catalog
        self.progressStore = progressStore
    }

    public func state(
        artworkID: String,
        entitlements: MuseumEntitlementSnapshot
    ) async throws -> ArtworkProductState {
        let keys = try currentKeys(artworkID: artworkID)
        let records = try await progressStore.records(for: Set(keys))
        let completedAtByKey = Dictionary(uniqueKeysWithValues: records.compactMap { key, record in
            record.completedAt.map { (key, $0) }
        })
        return try makeState(
            artworkID: artworkID,
            keys: keys,
            completedAtByKey: completedAtByKey,
            entitlements: entitlements
        )
    }

    /// Derives the post-completion state from the exact snapshot returned by the store,
    /// avoiding a second read that could observe concurrent sibling completion.
    func state(
        artworkID: String,
        completionReceipt: FragmentCompletionReceipt,
        entitlements: MuseumEntitlementSnapshot
    ) throws -> ArtworkProductState {
        guard completionReceipt.artworkID == artworkID else {
            throw ProductDomainError.inconsistentCompletionReceipt
        }
        let keys = try currentKeys(artworkID: artworkID)
        let currentSet = Set(keys)
        let completedSet = Set(completionReceipt.completedAtByFragmentKey.keys)
        guard completionReceipt.totalCount == keys.count,
              currentSet.contains(completionReceipt.fragmentKey),
              completedSet.contains(completionReceipt.fragmentKey),
              completedSet.isSubset(of: currentSet),
              completionReceipt.completedCount == completedSet.count else {
            throw ProductDomainError.inconsistentCompletionReceipt
        }
        return try makeState(
            artworkID: artworkID,
            keys: keys,
            completedAtByKey: completionReceipt.completedAtByFragmentKey,
            entitlements: entitlements
        )
    }

    private func currentKeys(artworkID: String) throws -> [ProgressRecordKey] {
        try catalog.currentFragmentIdentities(artworkID: artworkID).map {
            ProgressRecordKey(
                fragmentID: $0.fragmentID,
                puzzleID: $0.puzzleID,
                puzzleRevision: $0.puzzleRevision,
                puzzleSemanticHash: $0.puzzleSemanticHash
            )
        }
    }

    private func makeState(
        artworkID: String,
        keys: [ProgressRecordKey],
        completedAtByKey: [ProgressRecordKey: Date],
        entitlements: MuseumEntitlementSnapshot
    ) throws -> ArtworkProductState {
        guard let artwork = catalog.artworks[artworkID] else {
            throw RuntimeContentCatalogError.missing(kind: "Artwork", id: artworkID)
        }
        var completedIDs = Set<String>()
        let fragments = keys.map { key in
            let completedAt = completedAtByKey[key]
            if completedAt != nil { completedIDs.insert(key.fragmentID) }
            return FragmentProductState(
                fragmentID: key.fragmentID,
                currentKey: key,
                isCompleted: completedAt != nil,
                completedAt: completedAt
            )
        }
        let access = try ArtworkAccessEvaluator(
            entitlementResolver: entitlements
        ).evaluate(artwork: artwork, completedFragmentIDs: completedIDs)
        return ArtworkProductState(
            artworkID: artworkID,
            fragments: fragments,
            completedCount: completedIDs.count,
            totalCount: keys.count,
            access: access
        )
    }
}

public struct BlueprintUseService: Sendable {
    private let artworkStateService: ArtworkStateService

    public init(artworkStateService: ArtworkStateService) {
        self.artworkStateService = artworkStateService
    }

    public func openBlueprint(
        artworkID: String,
        entitlements: MuseumEntitlementSnapshot
    ) async throws -> AuthorizedBlueprint {
        let state = try await artworkStateService.state(
            artworkID: artworkID,
            entitlements: entitlements
        )
        guard state.access.canUseArtworkBlueprint else {
            throw ProductDomainError.blueprintAccessDenied(artworkID)
        }
        let blueprint = try artworkStateService.catalog.blueprintPayload(forArtworkID: artworkID)
        return AuthorizedBlueprint(
            blueprint: blueprint,
            exportPlan: try BlueprintExportPlan(validatedBlueprint: blueprint)
        )
    }
}
