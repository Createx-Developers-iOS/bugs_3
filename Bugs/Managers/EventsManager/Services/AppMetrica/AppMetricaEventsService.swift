import Foundation
import YandexMobileMetrica

/// Yandex AppMetrica.
final class AppMetricaEventsService: EventServiceProtocol {

    private var isActivated = false

    private var isConfigured: Bool { AppConfig.AppMetrica.isConfigured }

    func activate() {
        guard isConfigured, !isActivated else { return }
        guard let config = YMMYandexMetricaConfiguration(apiKey: AppConfig.AppMetrica.apiKey) else {
            #if DEBUG
            print("[AppMetrica] Failed to create configuration")
            #endif
            return
        }
        YMMYandexMetrica.activate(with: config)
        isActivated = true
        #if DEBUG
        print("[AppMetrica] activated")
        #endif
    }

    func requestDeviceID(completion: @escaping (String) -> Void) {
        guard isConfigured, isActivated else {
            completion("")
            return
        }
        YMMYandexMetrica.requestAppMetricaDeviceID(withCompletionQueue: .main) { deviceID, _ in
            completion(deviceID ?? "")
        }
    }

    func logEvent(name: String, parameters: [String: Any]?) {
        guard isConfigured, isActivated else { return }
        guard let params = parameters, !params.isEmpty else {
            YMMYandexMetrica.reportEvent(name)
            return
        }
        let stringParams = params.mapValues { value in
            (value as? String) ?? String(describing: value)
        }
        YMMYandexMetrica.reportEvent(name, parameters: stringParams)
    }

    func logPurchase(productId: String, price: Double, currency: String) {
        guard isConfigured, isActivated else { return }
        logEvent(
            name: "subscription_purchase",
            parameters: [
                "product_id": productId,
                "price": price,
                "currency": currency,
            ]
        )
        logEvent(name: "subscriptionCompleted", parameters: nil)
        #if DEBUG
        print("[AppMetrica] subscription_purchase + subscriptionCompleted productId=\(productId) price=\(price) currency=\(currency)")
        #endif
    }
}
