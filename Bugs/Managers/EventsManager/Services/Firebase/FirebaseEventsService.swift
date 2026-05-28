import FirebaseAnalytics
import FirebaseCore
import StoreKit

final class FirebaseEventsService: EventServiceProtocol {

    init() {
        guard FirebaseApp.app() == nil else { return }
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            #if DEBUG
            print("[Analytics] GoogleService-Info.plist missing — Firebase not configured")
            #endif
            return
        }
        FirebaseApp.configure()
    }

    func logEvent(name: String, parameters: [String: Any]? = nil) {
        guard FirebaseApp.app() != nil else { return }
        Analytics.logEvent(name, parameters: parameters)
    }

    func logPurchase(product: SKProduct) {
        guard FirebaseApp.app() != nil else { return }
        let currency = product.priceLocale.currency?.identifier ?? "USD"
        Analytics.logEvent(
            AnalyticsEventPurchase,
            parameters: [
                AnalyticsParameterCurrency: currency,
                AnalyticsParameterValue: product.price,
                AnalyticsParameterItems: [product.productIdentifier],
            ]
        )
        #if DEBUG
        print("[Firebase] purchase value=\(product.price) currency=\(currency) productId=\(product.productIdentifier)")
        #endif
    }
}
