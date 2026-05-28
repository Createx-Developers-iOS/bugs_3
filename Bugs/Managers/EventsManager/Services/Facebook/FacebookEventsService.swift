import FacebookCore
import StoreKit
import UIKit

/// Meta App Events (Facebook SDK).
final class FacebookEventsService: EventServiceProtocol {

    private var isConfigured: Bool { AppConfig.Facebook.isConfigured }

    func configureSDKSettings() {
        guard isConfigured else {
            #if DEBUG
            print("[Facebook] Missing appID or clientToken — SDK not configured")
            #endif
            return
        }
        Settings.shared.appID = AppConfig.Facebook.appID
        Settings.shared.clientToken = AppConfig.Facebook.clientToken
        #if DEBUG
        print("[Facebook] SDK settings configured")
        #endif
    }

    func finishLaunch(
        _ application: UIApplication,
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) {
        guard isConfigured else { return }
        _ = ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func activateApp() {
        guard isConfigured else { return }
        AppEvents.shared.activateApp()
        #if DEBUG
        print("[Facebook] activateApp()")
        #endif
    }

    var anonymousID: String {
        guard isConfigured else { return "" }
        return AppEvents.shared.anonymousID
    }

    func logEvent(name: String, parameters: [String: Any]?) {
        guard isConfigured else { return }
        var fbParams: [AppEvents.ParameterName: Any] = [:]
        parameters?.forEach { fbParams[AppEvents.ParameterName($0.key)] = $0.value }
        if fbParams.isEmpty {
            AppEvents.shared.logEvent(AppEvents.Name(name))
        } else {
            AppEvents.shared.logEvent(AppEvents.Name(name), parameters: fbParams)
        }
    }

    /// Revenue + standard subscription events (`Subscribe`, `StartTrial` when applicable).
    func logPurchase(product: SKProduct) {
        guard isConfigured else { return }

        let currency = product.priceLocale.currency?.identifier ?? "USD"
        let amount = Double(truncating: product.price)

        logEvent(name: "subscriptionCompleted", parameters: nil)
        AppEvents.shared.logPurchase(amount: amount, currency: currency)
        logStandardSubscriptionAppEvents(for: product, amount: amount, currency: currency)

        #if DEBUG
        print("[Facebook] subscriptionCompleted + logPurchase amount=\(amount) currency=\(currency) productId=\(product.productIdentifier)")
        #endif
    }

    private func logStandardSubscriptionAppEvents(for product: SKProduct, amount: Double, currency: String) {
        guard #available(iOS 12.0, *) else { return }
        guard product.subscriptionPeriod != nil else { return }

        let params: [AppEvents.ParameterName: Any] = [
            .currency: currency,
            .contentID: product.productIdentifier,
            .contentType: "subscription",
        ]

        AppEvents.shared.logEvent(AppEvents.Name.subscribe, valueToSum: amount, parameters: params)
        #if DEBUG
        print("[Facebook] Subscribe valueToSum=\(amount) productId=\(product.productIdentifier)")
        #endif

        if #available(iOS 11.2, *) {
            if let intro = product.introductoryPrice, intro.paymentMode == .freeTrial {
                AppEvents.shared.logEvent(AppEvents.Name.startTrial, valueToSum: 0, parameters: params)
                #if DEBUG
                print("[Facebook] StartTrial productId=\(product.productIdentifier)")
                #endif
            }
        }
    }
}
