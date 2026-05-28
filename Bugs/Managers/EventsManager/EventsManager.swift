import Foundation

enum SubscriptionPurchaseSource {
    case onboardingFirstPass
    case onboardingRepeat
    case inAppPaywall
}

final class EventsManager {

    static let shared = EventsManager()

    private let firebase = FirebaseEventsService()
    private let appsFlyer = AppsFlyerEventsService()

    private init() {}

    func logEvent(_ event: Event, parameters: [String: Any]? = nil) {
        let name = event.rawValue
        firebase.logEvent(name: name, parameters: parameters)
        appsFlyer.logEvent(name: name, parameters: parameters)
        #if DEBUG
        print("EVENT:", name, parameters ?? [:])
        #endif
    }

    func logEvent(name: String, parameters: [String: Any]? = nil) {
        firebase.logEvent(name: name, parameters: parameters)
        appsFlyer.logEvent(name: name, parameters: parameters)
        #if DEBUG
        print("EVENT:", name, parameters ?? [:])
        #endif
    }

    /// After a successful subscription purchase (Firebase + AppsFlyer + User Acquisition receipt).
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
