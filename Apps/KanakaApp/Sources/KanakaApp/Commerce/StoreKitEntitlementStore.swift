#if canImport(StoreKit) && canImport(SwiftUI)
import Foundation
import KanakaProductDomain
import StoreKit

struct EntitlementConfiguration: Codable, Sendable {
    let schema: String
    let productToMuseumIDs: [String: [String]]
}

actor StoreKitEntitlementStore {
    enum PurchaseOutcome: Sendable {
        case purchased(MuseumEntitlementSnapshot)
        case pending
        case cancelled
    }

    private let configuration: EntitlementConfiguration
    private var snapshot = MuseumEntitlementSnapshot()
    private var listener: Task<Void, Never>?
    private let updates: AsyncStream<MuseumEntitlementSnapshot>
    private let updateContinuation: AsyncStream<MuseumEntitlementSnapshot>.Continuation

    init(configuration: EntitlementConfiguration) throws {
        guard configuration.schema == "museum-entitlements-v1" else {
            throw AppCompositionError.unsupportedEntitlementSchema(configuration.schema)
        }
        let updateChannel = AsyncStream<MuseumEntitlementSnapshot>.makeStream()
        updates = updateChannel.stream
        updateContinuation = updateChannel.continuation
        self.configuration = configuration
    }

    deinit {
        listener?.cancel()
        updateContinuation.finish()
    }

    func startListening() -> AsyncStream<MuseumEntitlementSnapshot> {
        guard listener == nil else { return updates }
        listener = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard case .verified(let transaction) = result else { continue }
                guard let self else { return }
                let refreshed = await self.refresh()
                await self.publish(refreshed)
                await transaction.finish()
            }
        }
        return updates
    }

    func refresh() async -> MuseumEntitlementSnapshot {
        var museumIDs = Set<String>()
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil,
                  transaction.expirationDate.map({ $0 > Date() }) ?? true,
                  let grantedMuseums = configuration.productToMuseumIDs[transaction.productID]
            else { continue }
            museumIDs.formUnion(grantedMuseums)
        }
        snapshot = MuseumEntitlementSnapshot(museumIDs: museumIDs)
        return snapshot
    }

    func currentSnapshot() -> MuseumEntitlementSnapshot { snapshot }

    func products() async throws -> [Product] {
        try await Product.products(for: configuration.productToMuseumIDs.keys.sorted())
    }

    func purchase(productID: String) async throws -> PurchaseOutcome {
        guard configuration.productToMuseumIDs[productID] != nil else {
            throw StoreKitEntitlementError.unconfiguredProduct(productID)
        }
        guard let product = try await Product.products(for: [productID]).first else {
            throw StoreKitEntitlementError.productUnavailable(productID)
        }
        switch try await product.purchase() {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                throw StoreKitEntitlementError.unverifiedTransaction(productID)
            }
            let refreshed = await refresh()
            publish(refreshed)
            await transaction.finish()
            return .purchased(refreshed)
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            throw StoreKitEntitlementError.unknownPurchaseResult
        }
    }

    func restorePurchases() async throws -> MuseumEntitlementSnapshot {
        try await AppStore.sync()
        let refreshed = await refresh()
        publish(refreshed)
        return refreshed
    }

    private func publish(_ snapshot: MuseumEntitlementSnapshot) {
        updateContinuation.yield(snapshot)
    }
}

enum StoreKitEntitlementError: Error {
    case unconfiguredProduct(String)
    case productUnavailable(String)
    case unverifiedTransaction(String)
    case unknownPurchaseResult
}
#endif
