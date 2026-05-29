import Foundation

/// Production URLs, product IDs, and third-party keys.
enum AppConfig {

    enum Bundle {
        /// Name under the app icon (matches `CFBundleDisplayName` in build settings).
        static let displayName = "Bug Identifier"
    }

    enum Support {
        static let email = "help.team@routemaster.solutions"
    }

    enum Marketing {
        static let appStoreProductURL = "https://apps.apple.com/us/app/bug-identifier-insect-scanner/id6764270946"
        static let appStoreNumericID = "6764270946"
        /// Opens the App Store page with the review sheet when supported.
        static let appStoreWriteReviewURL = "https://apps.apple.com/app/id6764270946?action=write-review"
        static let termsOfUseURL = "https://bugs-identifier.com/terms.html"
        static let privacyPolicyURL = "https://bugs-identifier.com/privacy.html"
        static var shareAppURL: String { appStoreProductURL }
    }

    enum Subscription {
        static let weeklyProductID = "1week.com.insect.routemaster"
    }

    enum UserAcquisition {
        static let baseURL = "https://dash.zireth.com/"
    }

    enum Secrets {
        static let userAcquisitionAPIKey = "RQ72E2ZWi5T7ZtM3T_Gc"
        static let appStoreSharedSecret = "e079c905a04d41808ee747030bb08700"

        static var hasUserAcquisitionAPIKey: Bool {
            !userAcquisitionAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        static var hasAppStoreSharedSecret: Bool {
            !appStoreSharedSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    enum AppsFlyer {
        static let devKey = "me7G2c8GhmF273U55yNN5G"
        static let appleAppID = "6764270946"

        static var isConfigured: Bool {
            !devKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !appleAppID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    enum Facebook {
        static let appID = "1300599818848461"
        static let clientToken = "1ff9fce191ce6457e71fe3af5bba6a97"
        static let displayName = "Bug Identifier"

        static var isConfigured: Bool {
            !appID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !clientToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        static var urlScheme: String { "fb\(appID)" }
    }

    enum AppMetrica {
        static let apiKey = "0894b393-64d8-4636-b75c-7f467b5621ee"

        static var isConfigured: Bool {
            !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
