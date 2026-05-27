//
//  OnboardingViewController.swift
//  Bugs
//

import StoreKit
import UIKit

/// Общая геометрия плавающей CTA и встроенной кнопки пейвола на втором шаге онбординга.
enum OnboardingFloatingCTALayout {
    static let buttonHeight: CGFloat = 56
    /// Низ кнопки на `safeAreaLayoutGuide.bottomAnchor` с этим отступом (отрицательная константа в Auto Layout).
    static let bottomOffsetFromSafeAreaBottom: CGFloat = 44
}

/// Два экрана на `UICollectionView`, листание только по кнопке на первом шаге; второй — пейвол.
final class OnboardingViewController: UIViewController {
    private static let isOnboardingEndedKey = "isonbended"

    private var currentPage = 0
    private var isRepeatOnboardingSession = false
    private var loggedOnboardingSteps = Set<Int>()
    private var didLogOnboardingPaywallShown = false
    /// `scrollToItem` before layout is ready leaves `contentOffset` at 0 while `currentPage == 1` — wrong page + wrong chrome. Sync in `viewDidLayoutSubviews`.
    private var needsScrollToPaywallAfterLayout = false

    private lazy var flowLayout: UICollectionViewFlowLayout = {
        let l = UICollectionViewFlowLayout()
        l.scrollDirection = .horizontal
        l.minimumLineSpacing = 0
        l.minimumInteritemSpacing = 0
        l.sectionInset = .zero
        return l
    }()

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.semanticContentAttribute = .forceLeftToRight
        cv.backgroundColor = .appBackground
        cv.isPagingEnabled = true
        cv.isScrollEnabled = false
        cv.showsHorizontalScrollIndicator = false
        cv.showsVerticalScrollIndicator = false
        cv.bounces = false
        cv.dataSource = self
        cv.delegate = self
        cv.register(OnboardingIntroPageCollectionViewCell.self, forCellWithReuseIdentifier: OnboardingIntroPageCollectionViewCell.reuseIdentifier)
        cv.register(OnboardingPaywallCollectionViewCell.self, forCellWithReuseIdentifier: OnboardingPaywallCollectionViewCell.reuseIdentifier)
        return cv
    }()

    private let actionButton: GradientRoundedCTAControl = {
        let b = GradientRoundedCTAControl()
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .light
        view.backgroundColor = .appBackground

        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)

        view.addSubview(collectionView)
        view.addSubview(actionButton)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            actionButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 46),
            actionButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -46),
            actionButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -OnboardingFloatingCTALayout.bottomOffsetFromSafeAreaBottom
            ),
            actionButton.heightAnchor.constraint(equalToConstant: OnboardingFloatingCTALayout.buttonHeight),
        ])

        view.bringSubviewToFront(actionButton)
        isRepeatOnboardingSession = Self.shouldStartAtPaywall()
        if isRepeatOnboardingSession {
            currentPage = 1
            needsScrollToPaywallAfterLayout = true
            Self.markOnboardingEndedIfNeeded()
        }
        updateChromeForPage()
        logOnboardingStepIfNeeded(currentPage)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let size = collectionView.bounds.size
        guard size.width > 0, size.height > 0 else { return }
        if flowLayout.itemSize != size {
            flowLayout.itemSize = size
            flowLayout.invalidateLayout()
        }
        if needsScrollToPaywallAfterLayout {
            let indexPath = IndexPath(item: 1, section: 0)
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)
            collectionView.layoutIfNeeded()
            collectionView.contentOffset = CGPoint(x: size.width, y: 0)
            if abs(collectionView.contentOffset.x - size.width) < 2 {
                needsScrollToPaywallAfterLayout = false
            }
            updateChromeForPage()
        }
    }

    private func updateChromeForPage() {
        actionButton.isHidden = false
        if currentPage == 0 {
            actionButton.setTitle(L10n.string("onboarding.button.next"), for: .normal)
        } else {
            actionButton.setTitle(L10n.string("paywall.button.next"), for: .normal)
            logOnboardingPaywallShownIfNeeded()
        }
        actionButton.isPulseAnimationEnabled = (currentPage == 1)
    }

    @objc
    private func actionTapped() {
        if currentPage == 0 {
            currentPage = 1
            let indexPath = IndexPath(item: 1, section: 0)
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
            updateChromeForPage()
            logOnboardingStepIfNeeded(currentPage)
            Self.markOnboardingEndedIfNeeded()
        } else {
            Task { await performSubscriptionPurchase() }
        }
    }

    fileprivate func completeOnboardingAndGoMain() {
        transitionToMain()
    }

    fileprivate func completeOnboardingSkipPaywall() {
        completeOnboardingAndGoMain()
    }

    private func transitionToMain() {
        guard let window = view.window else { return }
        let main = MainTabBarController()
        UIView.transition(with: window, duration: 0.35, options: .transitionCrossDissolve) {
            window.rootViewController = main
        }
    }

    fileprivate static func openExternalURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        UIApplication.shared.open(url)
    }

    @MainActor
    private func performSubscriptionPurchase() async {
        guard NetworkReachability.shared.isConnected else {
            UserFacingRequestErrorAlert.presentTryAgainLater(from: self)
            return
        }
        actionButton.isEnabled = false
        showCenterLoadingOverlay()
        defer {
            hideCenterLoadingOverlay()
            actionButton.isEnabled = true
        }

        do {
            let products = try await SubscriptionManager.shared.loadSubscriptionProducts()
            guard let product = products.first else {
                presentSubscriptionAlert(titleKey: "subscription.error.title", messageKey: "subscription.error.product_unavailable")
                return
            }
            try await SubscriptionManager.shared.purchase(product)
            let purchaseSource: SubscriptionPurchaseSource = isRepeatOnboardingSession ? .onboardingRepeat : .onboardingFirstPass
            EventsManager.shared.recordSubscriptionPurchase(product: product, source: purchaseSource)
            RefundConsentFlow.present(from: self) { [weak self] in
                self?.completeOnboardingAndGoMain()
            }
        } catch SubscriptionManagerError.userCancelled {
            return
        } catch {
            presentSubscriptionAlert(titleKey: "subscription.error.title", messageKey: "subscription.error.purchase_failed")
        }
    }

    @MainActor
    private func performRestoreFromOnboarding() async {
        guard NetworkReachability.shared.isConnected else {
            UserFacingRequestErrorAlert.presentTryAgainLater(from: self)
            return
        }
        actionButton.isEnabled = false
        showCenterLoadingOverlay()
        defer {
            hideCenterLoadingOverlay()
            actionButton.isEnabled = true
        }

        do {
            try await SubscriptionManager.shared.restorePurchases()
            if SubscriptionManager.shared.isSubscriptionActive {
                completeOnboardingAndGoMain()
            } else {
                presentSubscriptionAlert(titleKey: "subscription.restore.title", messageKey: "subscription.restore.nothing")
            }
        } catch {
            presentSubscriptionAlert(titleKey: "subscription.error.title", messageKey: "subscription.error.restore_failed")
        }
    }

    private func presentSubscriptionAlert(titleKey: String, messageKey: String) {
        let alert = UIAlertController(
            title: L10n.string(titleKey),
            message: L10n.string(messageKey),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.string("common.done"), style: .default))
        present(alert, animated: true)
    }

    private static func shouldStartAtPaywall() -> Bool {
        UserDefaults.standard.bool(forKey: isOnboardingEndedKey)
    }

    private static func markOnboardingEndedIfNeeded() {
        if !UserDefaults.standard.bool(forKey: isOnboardingEndedKey) {
            UserDefaults.standard.set(true, forKey: isOnboardingEndedKey)
        }
    }

    private func logOnboardingStepIfNeeded(_ page: Int) {
        guard loggedOnboardingSteps.insert(page).inserted else { return }
        switch page {
        case 0:
            EventsManager.shared.logEvent(.view_onboarding_1)
        case 1:
            EventsManager.shared.logEvent(.view_onboarding_2)
        default:
            break
        }
    }

    private func logOnboardingPaywallShownIfNeeded() {
        guard !didLogOnboardingPaywallShown else { return }
        didLogOnboardingPaywallShown = true
        let event: EventsManager.Event = isRepeatOnboardingSession ? .launch_paywall_view : .view_onboarding_subscription
        EventsManager.shared.logEvent(event)
    }
}

extension OnboardingViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        2
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.item == 0 {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: OnboardingIntroPageCollectionViewCell.reuseIdentifier,
                for: indexPath
            ) as! OnboardingIntroPageCollectionViewCell
            cell.configure()
            return cell
        }
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: OnboardingPaywallCollectionViewCell.reuseIdentifier,
            for: indexPath
        ) as! OnboardingPaywallCollectionViewCell
        cell.configure(
            onClose: { [weak self] in self?.completeOnboardingSkipPaywall() },
            onTerms: { OnboardingViewController.openExternalURL(AppConfig.Marketing.termsOfUseURL) },
            onPrivacy: { OnboardingViewController.openExternalURL(AppConfig.Marketing.privacyPolicyURL) },
            onRestore: { [weak self] in Task { await self?.performRestoreFromOnboarding() } }
        )
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let intro = cell as? OnboardingIntroPageCollectionViewCell {
            intro.playBenefitsRevealAnimation()
        }
    }
}
