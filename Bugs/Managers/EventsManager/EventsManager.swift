import Foundation
import StoreKit
import SwiftyStoreKit
import UIKit

enum SubscriptionPurchaseSource {
    case onboardingFirstPass
    case onboardingRepeat
    case inAppPaywall
}

final class EventsManager {

    static let shared = EventsManager()

    fileprivate let firebase = FirebaseEventsService()
    fileprivate let appsFlyer = AppsFlyerEventsService()
    fileprivate let facebook = FacebookEventsService()
    fileprivate let appMetrica = AppMetricaEventsService()

    private var didConfigureOnLaunch = false

    private init() {}

    /// Facebook `Settings` must be set before `ApplicationDelegate` (call from `AppDelegate` on launch).
    func configureOnLaunch(
        application: UIApplication,
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) {
        guard !didConfigureOnLaunch else { return }
        didConfigureOnLaunch = true

        facebook.configureSDKSettings()
        appMetrica.activate()
        fillUserAcquisitionAttributionIDs()

        facebook.finishLaunch(application, launchOptions: launchOptions)
        facebook.activateApp()
    }

    private func fillUserAcquisitionAttributionIDs() {
        let fbId = facebook.anonymousID
        if !fbId.isEmpty {
            UserAcquisitionManager.shared.conversionInfo.fbAnonymousId = fbId
            #if DEBUG
            print("[Analytics] Facebook anonymous ID set")
            #endif
        }

        appMetrica.requestDeviceID { deviceID in
            guard !deviceID.isEmpty else { return }
            UserAcquisitionManager.shared.conversionInfo.appmetricaId = deviceID
            #if DEBUG
            print("[Analytics] AppMetrica device ID set")
            #endif
        }
    }

    func logEvent(_ event: Event, parameters: [String: Any]? = nil) {
        logEvent(name: event.rawValue, parameters: parameters)
    }

    func logEvent(name: String, parameters: [String: Any]? = nil) {
        firebase.logEvent(name: name, parameters: parameters)
        appsFlyer.logEvent(name: name, parameters: parameters)
        facebook.logEvent(name: name, parameters: parameters)
        appMetrica.logEvent(name: name, parameters: parameters)
        #if DEBUG
        print("EVENT:", name, parameters ?? [:])
        #endif
    }

    /// After a successful subscription purchase (Firebase, AppsFlyer, Facebook, AppMetrica, User Acquisition).
    @MainActor
    func recordSubscriptionPurchase(product: SubscriptionProduct, source: SubscriptionPurchaseSource) {
        UserAcquisitionManager.shared.logPurchase(of: product)
        logEvent(.subscription_done_all)
        appsFlyer.logPurchase(productId: product.id)

        switch source {
        case .onboardingFirstPass:
            logEvent(.onboarding_subscription_done)
        case .onboardingRepeat:
            logEvent(.subscription_done_new_open_app)
        case .inAppPaywall:
            logEvent(.subscription_done_purchased_inapp)
        }

        let productId = product.id.lowercased()
        if productId.contains("week") || productId.contains("7day") || productId.contains("7_day") {
            logEvent(.paywall_subscribe_week)
        } else if productId.contains("3month")
            || productId.contains("quarter")
            || productId.contains("3_month")
            || productId.contains("threemonth") {
            logEvent(.paywall_subscribe_threemonths)
        } else if productId.contains("1year")
            || productId.contains("year")
            || productId.contains("annual") {
            logEvent(.paywall_subscribe_year)
        }

        logSubscriptionRevenueToFacebookAndAppMetrica(productId: product.id)
    }

    /// Loads `SKProduct` for revenue events (Meta `logPurchase` / AppMetrica `subscription_purchase`).
    private func logSubscriptionRevenueToFacebookAndAppMetrica(productId: String) {
        SwiftyStoreKit.retrieveProductsInfo([productId]) { [weak self] result in
            guard let self else { return }
            guard let skProduct = result.retrievedProducts.first else {
                #if DEBUG
                if let error = result.error {
                    print("[Analytics] retrieveProductsInfo failed:", error.localizedDescription)
                } else {
                    print("[Analytics] retrieveProductsInfo: no product for \(productId)")
                }
                #endif
                return
            }

            self.firebase.logPurchase(product: skProduct)
            self.facebook.logPurchase(product: skProduct)

            let amount = Double(truncating: skProduct.price)
            let currency = skProduct.priceLocale.currency?.identifier ?? "USD"
            self.appMetrica.logPurchase(productId: productId, price: amount, currency: currency)
        }
    }

    enum Event: String, CaseIterable {
        case splash_show
        case view_onboarding_1
        case view_onboarding_2
        case view_onboarding_3
        case view_onboarding_subscription
        case launch_paywall_view
        case paywall_inapp_displayed
        case main_screen_view

        case subscription_done_all
        case onboarding_subscription_done
        case subscription_done_new_open_app
        case subscription_done_purchased_inapp

        case paywall_subscribe_week
        case paywall_subscribe_threemonths
        case paywall_subscribe_year

        case core_scan_started
        case core_scan_recognition_success
        case core_scan_recognition_failure
        case core_scan_result_opened
        case core_add_to_collection_started
        case core_add_to_collection_success
        case core_ai_chat_message_sent
    }
}
