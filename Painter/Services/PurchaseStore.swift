import StoreKit
import Observation

@Observable @MainActor
final class PurchaseStore {
    static let weeklyProductID = "com.karamba555.painter.pro.weekly"
    private(set) var product: Product?
    private(set) var isPro = false
    private(set) var isBusy = false
    var message: String?
    var price: String { product?.displayPrice ?? "$5.99" }

    func load() async {
        do { product = try await Product.products(for: [Self.weeklyProductID]).first }
        catch { message = "The App Store is unavailable. Please try again." }
        await refreshEntitlements()
    }
    func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.weeklyProductID,
               transaction.revocationDate == nil { entitled = true }
        }
        isPro = entitled
    }
    /// Sent only to the configured backend; the server independently verifies it with Apple.
    func signedEntitlement() async -> String? {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.weeklyProductID,
               transaction.revocationDate == nil { return result.jwsRepresentation }
        }
        return nil
    }
    func observeTransactions() async {
        for await result in Transaction.updates {
            guard !Task.isCancelled else { return }
            guard case .verified(let transaction) = result else { continue }
            await refreshEntitlements()
            await transaction.finish()
        }
    }
    func purchase() async {
        guard !isBusy else { return }
        isBusy = true; defer { isBusy = false }
        if product == nil { await load() }
        guard let product else {
            message = "Subscriptions are not available in this build yet. You can keep using the free drawings and lessons."
            return
        }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await refreshEntitlements(); await transaction.finish()
            case .success(.unverified): message = "We couldn’t verify this purchase. Please restore purchases or try again."
            case .pending: message = "Your purchase is awaiting approval. Pro will unlock when it is approved."
            case .userCancelled: break
            @unknown default: message = "The purchase could not be completed. Please try again."
            }
        } catch { message = "The purchase could not be completed. Please try again." }
    }
    func restore() async {
        guard !isBusy else { return }
        isBusy = true; defer { isBusy = false }
        do {
            try await AppStore.sync(); await refreshEntitlements()
            message = isPro ? "Your Pro subscription has been restored." : "No active subscription was found for this Apple Account."
        } catch { message = "Purchases could not be restored. Please try again." }
    }
}
