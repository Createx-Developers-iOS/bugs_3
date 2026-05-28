import AppsFlyerLib
import Foundation

final class AppsFlyerEventsService: NSObject, EventServiceProtocol, AppsFlyerLibDelegate {

    private let isConfigured: Bool

    override init() {
        let ok = AppConfig.AppsFlyer.isConfigured
        let key = AppConfig.AppsFlyer.devKey
        let appId = AppConfig.AppsFlyer.appleAppID
        self.isConfigured = ok
        super.init()
        guard ok else {
            #if DEBUG
            print("[AppsFlyer] Missing devKey or appleAppID — SDK not started")
            #endif
            return
        }
        let af = AppsFlyerLib.shared()
        af.delegate = self
        af.appsFlyerDevKey = key
        af.appleAppID = appId
        af.waitForATTUserAuthorization(timeoutInterval: 60)
        af.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let uid = AppsFlyerLib.shared().getAppsFlyerUID()
            guard !uid.isEmpty else { return }
            UserAcquisitionManager.shared.conversionInfo.appsFlyerId = uid
        }
    }

    func logEvent(name: String, parameters: [String: Any]?) {
        guard isConfigured else { return }
        AppsFlyerLib.shared().logEvent(name, withValues: parameters)
    }

    func logPurchase(productId: String) {
        guard isConfigured else { return }
        AppsFlyerLib.shared().logEvent(AFEventPurchase, withValues: ["product_id": productId])
        #if DEBUG
        print("[AppsFlyer] AFEventPurchase productId=\(productId)")
        #endif
    }

    func onConversionDataSuccess(_ conversionInfo: [AnyHashable: Any]) {
        guard let data = conversionInfo as? [String: Any] else { return }
        UserAcquisitionManager.shared.conversionInfo.setAppsFlyerData(data)
        UserAcquisitionManager.shared.conversionInfo.appsFlyerId = AppsFlyerLib.shared().getAppsFlyerUID()
    }

    func onConversionDataFail(_ error: Error) {}
}
