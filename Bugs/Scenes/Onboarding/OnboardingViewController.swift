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

/// Три интро-экрана + пейволл, навигация только по кнопке.
final class OnboardingViewController: UIViewController {
    private static let isOnboardingEndedKey = "isonbended"
    private static let introPageCount = 3
    private static let paywallPageIndex = 3

    private var currentPage = 0
    private var isRepeatOnboardingSession = false
    private var loggedOnboardingSteps = Set<Int>()
    private var didLogOnboardingPaywallShown = false
    /// `scrollToItem` before layout is ready leaves `contentOffset` at 0 while `currentPage` уже изменён.
    private var needsScrollToInitialPageAfterLayout = false

    private struct IntroPageModel {
        let title: String
        let background: OnboardingFeaturePageCollectionViewCell.BackgroundKind
    }

    private let introPages: [IntroPageModel] = [
        .init(
            title: L10n.string("onboarding.v2.page1.title"),
            background: .lottie(name: "onb1")
        ),
        .init(
            title: L10n.string("onboarding.v2.page3.title"),
            background: .lottie(name: "onb2")
        ),
        .init(
            title: L10n.string("onboarding.v2.page2.title"),
            background: .testimonials(imageAssetName: "people")
        ),
    ]

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
        cv.register(OnboardingFeaturePageCollectionViewCell.self, forCellWithReuseIdentifier: OnboardingFeaturePageCollectionViewCell.reuseIdentifier)
        cv.register(OnboardingPaywallCollectionViewCell.self, forCellWithReuseIdentifier: OnboardingPaywallCollectionViewCell.reuseIdentifier)
        return cv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 24, weight: .bold)
        l.textColor = .appTextPrimary
        l.textAlignment = .center
        l.numberOfLines = 0
        l.lineBreakMode = .byWordWrapping
        return l
    }()

    private let actionButton: GradientRoundedCTAControl = {
        let b = GradientRoundedCTAControl()
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let pageControlView: OnboardingCustomPageControlView = {
        let v = OnboardingCustomPageControlView(numberOfPages: 3)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .light
        view.backgroundColor = .appBackground

        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)

        view.addSubview(collectionView)
        view.addSubview(titleLabel)
        view.addSubview(actionButton)
        view.addSubview(pageControlView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            titleLabel.bottomAnchor.constraint(equalTo: actionButton.topAnchor, constant: -20),

            actionButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 46),
            actionButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -46),
            actionButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -OnboardingFloatingCTALayout.bottomOffsetFromSafeAreaBottom
            ),
            actionButton.heightAnchor.constraint(equalToConstant: OnboardingFloatingCTALayout.buttonHeight),

            pageControlView.topAnchor.constraint(equalTo: actionButton.bottomAnchor, constant: 18),
            pageControlView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControlView.heightAnchor.constraint(equalToConstant: 8),
        ])

        view.bringSubviewToFront(actionButton)
        view.bringSubviewToFront(titleLabel)
        view.bringSubviewToFront(pageControlView)
        isRepeatOnboardingSession = Self.shouldStartAtPaywall()
        if isRepeatOnboardingSession {
            currentPage = Self.paywallPageIndex
            needsScrollToInitialPageAfterLayout = true
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
        if needsScrollToInitialPageAfterLayout {
            let indexPath = IndexPath(item: currentPage, section: 0)
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: false)
            collectionView.layoutIfNeeded()
            collectionView.contentOffset = CGPoint(x: size.width * CGFloat(currentPage), y: 0)
            if abs(collectionView.contentOffset.x - (size.width * CGFloat(currentPage))) < 2 {
                needsScrollToInitialPageAfterLayout = false
            }
            updateChromeForPage()
        }
    }

    private func updateChromeForPage() {
        let isPaywallPage = (currentPage == Self.paywallPageIndex)
        actionButton.isHidden = false
        if isPaywallPage {
            titleLabel.isHidden = true
            pageControlView.isHidden = true
            actionButton.setTitle(L10n.string("paywall.button.next"), for: .normal)
            actionButton.isPulseAnimationEnabled = true
            logOnboardingPaywallShownIfNeeded()
        } else {
            titleLabel.isHidden = false
            pageControlView.isHidden = false
            titleLabel.text = introPages[currentPage].title
            actionButton.setTitle(L10n.string("onboarding.button.next"), for: .normal)
            actionButton.isPulseAnimationEnabled = false
            pageControlView.currentPage = currentPage
        }
    }

    @objc
    private func actionTapped() {
        if currentPage < Self.introPageCount - 1 {
            currentPage += 1
            let indexPath = IndexPath(item: currentPage, section: 0)
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
            updateChromeForPage()
            logOnboardingStepIfNeeded(currentPage)
        } else if currentPage == Self.introPageCount - 1 {
            currentPage = Self.paywallPageIndex
            let indexPath = IndexPath(item: currentPage, section: 0)
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
        case Self.paywallPageIndex:
            logOnboardingPaywallShownIfNeeded()
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
        Self.introPageCount + 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.item < Self.introPageCount {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: OnboardingFeaturePageCollectionViewCell.reuseIdentifier,
                for: indexPath
            ) as! OnboardingFeaturePageCollectionViewCell
            cell.configure(background: introPages[indexPath.item].background)
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

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {}
}
