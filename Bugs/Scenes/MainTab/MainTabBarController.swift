//
//  MainTabBarController.swift
//  Bugs
//

import UIKit
import UserNotifications

/// Корневой контейнер: четыре вкладки и плавающая центральная кнопка (камера).
final class MainTabBarController: UIViewController {
    private static var didRequestPushPermissionThisSession = false

    private let childContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .appBackground
        return v
    }()

    private let tabBarContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .clear
        v.clipsToBounds = false
        return v
    }()

    private let tabBarChrome = TabBarWhiteChromeView(cornerRadius: Metrics.barTopCornerRadius)

    private let tabsStack: UIStackView = {
        let s = UIStackView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.axis = .horizontal
        s.alignment = .center
        s.distribution = .fill
        s.spacing = 0
        return s
    }()

    private let centerSlot = UIView()
    private let centerActionButton = CenterScanFloatingButton()

    private var tabBarHeightConstraint: NSLayoutConstraint!
    /// Контент заканчивается у верхнего края таббара (корень стека).
    private var childContainerBottomToTabBarConstraint: NSLayoutConstraint!
    /// Контент на весь низ экрана (пуш с корневого экрана — таббар скрыт).
    private var childContainerBottomToViewConstraint: NSLayoutConstraint!
    private var tabBarHiddenForNavigationDepth = false

    private var tabItems: [MainTabItemControl] = []
    private var navigationStacks: [UINavigationController] = []
    /// Тег выбранной вкладки контента: 0 / 1 / 3 (чат с тегом 2 не хранится — модалка).
    private var selectedContentTabTag: Int = 0
    private weak var visibleNavigation: UINavigationController?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .appBackground
        centerSlot.translatesAutoresizingMaskIntoConstraints = false
        buildNavigationStacks()
        buildChrome()
        switchToContentTab(tag: 0)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applySubscriptionStatusForAppearance()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        EventsManager.shared.logEvent(.main_screen_view)
        requestPushPermissionIfNeeded()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        tabBarHeightConstraint.constant = Metrics.tabBarContentHeight + view.safeAreaInsets.bottom
    }

    private func buildNavigationStacks() {
        let homeNav = UINavigationController(rootViewController: HomeConfigurator.assemble())
        let libraryNav = UINavigationController(rootViewController: LibraryConfigurator.assemble())
        let profileNav = UINavigationController(rootViewController: ProfileViewController())
        navigationStacks = [homeNav, libraryNav, profileNav]
        for nav in navigationStacks {
            AppNavigationBarAppearance.apply(to: nav.navigationBar)
            nav.delegate = self
        }
    }

    private func buildChrome() {
        view.addSubview(childContainer)
        view.addSubview(tabBarContainer)
        tabBarContainer.addSubview(tabBarChrome)
        tabBarContainer.addSubview(tabsStack)
        tabBarContainer.addSubview(centerActionButton)

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: Metrics.tabIconPointSize, weight: .medium)
        let tabAssets: [(asset: String, fallbackSymbol: String, a11y: String)] = [
            ("tab_bar_home", "house.fill", "tab.home.accessibility"),
            ("tab_bar_library", "doc.text.fill", "tab.library.accessibility"),
            ("tab_bar_chat", "message.fill", "tab.chat.accessibility"),
            ("tab_bar_profile", "person.fill", "tab.profile.accessibility"),
        ]

        let leftStack = UIStackView()
        leftStack.translatesAutoresizingMaskIntoConstraints = false
        leftStack.axis = .horizontal
        leftStack.distribution = .fillEqually
        leftStack.spacing = 0

        let rightStack = UIStackView()
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        rightStack.axis = .horizontal
        rightStack.distribution = .fillEqually
        rightStack.spacing = 0

        for (idx, spec) in tabAssets.enumerated() {
            if Metrics.hiddenTabTags.contains(idx) { continue }
            let item = MainTabItemControl()
            item.configure(
                assetName: spec.asset,
                fallbackSystemName: spec.fallbackSymbol,
                symbolConfiguration: symbolConfig
            )
            item.accessibilityLabel = L10n.string(spec.a11y)
            item.tag = idx
            item.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            tabItems.append(item)
            if idx < 2 {
                leftStack.addArrangedSubview(item)
            } else {
                rightStack.addArrangedSubview(item)
            }
        }

        centerSlot.widthAnchor.constraint(equalToConstant: Metrics.centerSlotWidth).isActive = true

        tabsStack.addArrangedSubview(leftStack)
        tabsStack.addArrangedSubview(centerSlot)
        tabsStack.addArrangedSubview(rightStack)

        centerActionButton.translatesAutoresizingMaskIntoConstraints = false
        centerActionButton.addTarget(self, action: #selector(centerScanTapped), for: .touchUpInside)
        centerActionButton.accessibilityLabel = L10n.string("tab.scan.accessibility")

        tabBarHeightConstraint = tabBarContainer.heightAnchor.constraint(
            equalToConstant: Metrics.tabBarContentHeight + view.safeAreaInsets.bottom
        )

        childContainerBottomToTabBarConstraint = childContainer.bottomAnchor.constraint(equalTo: tabBarContainer.topAnchor)
        childContainerBottomToViewConstraint = childContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        childContainerBottomToViewConstraint.isActive = false

        NSLayoutConstraint.activate([
            childContainer.topAnchor.constraint(equalTo: view.topAnchor),
            childContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            childContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            childContainerBottomToTabBarConstraint,

            tabBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBarContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tabBarHeightConstraint,

            tabBarChrome.topAnchor.constraint(equalTo: tabBarContainer.topAnchor),
            tabBarChrome.leadingAnchor.constraint(equalTo: tabBarContainer.leadingAnchor),
            tabBarChrome.trailingAnchor.constraint(equalTo: tabBarContainer.trailingAnchor),
            tabBarChrome.bottomAnchor.constraint(equalTo: tabBarContainer.bottomAnchor),

            tabsStack.leadingAnchor.constraint(equalTo: tabBarChrome.leadingAnchor, constant: Metrics.tabsRowHorizontalInset),
            tabsStack.trailingAnchor.constraint(equalTo: tabBarChrome.trailingAnchor, constant: -Metrics.tabsRowHorizontalInset),
            tabsStack.bottomAnchor.constraint(equalTo: tabBarChrome.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            tabsStack.heightAnchor.constraint(equalToConstant: Metrics.tabRowHeight),

            leftStack.widthAnchor.constraint(equalTo: rightStack.widthAnchor),

            centerActionButton.centerXAnchor.constraint(equalTo: tabBarContainer.centerXAnchor),
            centerActionButton.centerYAnchor.constraint(
                equalTo: tabBarChrome.topAnchor,
                constant: Metrics.cameraButtonCenterYOffset
            ),
            centerActionButton.widthAnchor.constraint(equalToConstant: Metrics.centerButtonSize),
            centerActionButton.heightAnchor.constraint(equalToConstant: Metrics.centerButtonSize),
        ])
    }

    @objc
    private func tabTapped(_ sender: MainTabItemControl) {
        let tag = sender.tag
        if tag == Metrics.chatTabTag {
            presentChatModallyFromCurrentScreen()
            return
        }
        switchToContentTab(tag: tag)
    }

    /// Индекс стека для вкладок 0 — главная, 1 — библиотека, 3 — профиль.
    private func contentStackIndex(forTabTag tag: Int) -> Int? {
        switch tag {
        case 0: return 0
        case 1: return 1
        case 3: return 2
        default: return nil
        }
    }

    private func switchToContentTab(tag: Int) {
        guard let stackIndex = contentStackIndex(forTabTag: tag) else { return }
        selectedContentTabTag = tag
        for item in tabItems {
            item.setSelected(item.tag == tag)
        }

        let next = navigationStacks[stackIndex]
        guard visibleNavigation !== next else { return }

        if let old = visibleNavigation {
            old.willMove(toParent: nil)
            old.view.removeFromSuperview()
            old.removeFromParent()
        }

        addChild(next)
        childContainer.addSubview(next.view)
        next.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            next.view.topAnchor.constraint(equalTo: childContainer.topAnchor),
            next.view.leadingAnchor.constraint(equalTo: childContainer.leadingAnchor),
            next.view.trailingAnchor.constraint(equalTo: childContainer.trailingAnchor),
            next.view.bottomAnchor.constraint(equalTo: childContainer.bottomAnchor),
        ])
        next.didMove(toParent: self)
        visibleNavigation = next
        updateTabBarVisibilityForCurrentNavigation(animated: false)
    }

    private func updateTabBarVisibilityForCurrentNavigation(animated: Bool) {
        guard let nav = visibleNavigation else { return }
        let shouldHide = nav.viewControllers.count > 1
        setTabBarHiddenForPush(shouldHide, animated: animated)
    }

    private func setTabBarHiddenForPush(_ hidden: Bool, animated: Bool) {
        guard tabBarHiddenForNavigationDepth != hidden else { return }
        tabBarHiddenForNavigationDepth = hidden

        let apply = {
            self.applyTabBarHiddenConstraints(hidden)
            self.view.layoutIfNeeded()
        }
        if animated {
            UIView.animate(withDuration: 0.28, delay: 0, options: [.curveEaseInOut], animations: apply)
        } else {
            apply()
        }
    }

    private func applyTabBarHiddenConstraints(_ hidden: Bool) {
        childContainerBottomToTabBarConstraint.isActive = !hidden
        childContainerBottomToViewConstraint.isActive = hidden
        tabBarContainer.isHidden = hidden
        tabBarContainer.isUserInteractionEnabled = !hidden
    }

    private func presentChatModallyFromCurrentScreen() {
        guard let nav = visibleNavigation else {
            presentAIConsultantChatFullScreen()
            return
        }
        (nav.visibleViewController ?? nav).topPresenterForModal.presentAIConsultantChatFullScreen()
    }

    private func requestPushPermissionIfNeeded() {
        guard !Self.didRequestPushPermissionThisSession else { return }
        Self.didRequestPushPermissionThisSession = true

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                    guard granted else { return }
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }

    @objc
    private func centerScanTapped() {
        let scanner = ScannerViewController()
        let nav = UINavigationController(rootViewController: scanner)
        AppNavigationBarAppearance.apply(to: nav.navigationBar)
        nav.setNavigationBarHidden(true, animated: false)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    private enum Metrics {
        /// Вкладки с этими тегами не показываются в таббаре (1 — библиотека, 2 — чат).
        static let hiddenTabTags: Set<Int> = [1, 2]
        /// Индекс иконки «чат», если снова включить вторую строку табов.
        static let chatTabTag: Int = 2
        static let barTopCornerRadius: CGFloat = 32
        static let tabBarContentHeight: CGFloat = 62
        static let tabRowHeight: CGFloat = 44
        static let centerButtonSize: CGFloat = 62
        /// Уже слот — меньше расстояние между левой и правой парой вкладок.
        static let centerSlotWidth: CGFloat = 48
        static let tabIconPointSize: CGFloat = 20
        /// Отступ ряда вкладок от краёв белой панели — сдвигает иконки к центру (не сужает сам фон).
        static let tabsRowHorizontalInset: CGFloat = 28
        /// Смещение центра кнопки камеры вниз от верхнего края панели (pt).
        static let cameraButtonCenterYOffset: CGFloat = 18
    }
}

extension MainTabBarController: UINavigationControllerDelegate {

    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        guard navigationController === visibleNavigation else { return }
        updateTabBarVisibilityForCurrentNavigation(animated: animated)
    }
}

// MARK: - Tab bar chrome (rounded top + light shadow)

private final class TabBarWhiteChromeView: UIView {

    private let cornerRadius: CGFloat

    private let fillView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .white
        return v
    }()

    init(cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.09
        layer.shadowOffset = CGSize(width: 0, height: -4)
        layer.shadowRadius = 14
        addSubview(fillView)
        NSLayoutConstraint.activate([
            fillView.topAnchor.constraint(equalTo: topAnchor),
            fillView.leadingAnchor.constraint(equalTo: leadingAnchor),
            fillView.trailingAnchor.constraint(equalTo: trailingAnchor),
            fillView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        fillView.layer.cornerRadius = cornerRadius
        fillView.layer.cornerCurve = .continuous
        fillView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        fillView.layer.masksToBounds = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = UIBezierPath(
            roundedRect: bounds,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)
        )
        layer.shadowPath = path.cgPath
    }
}

// MARK: - Center camera image (asset or composed)

private extension UIImage {

    static let tabBarCameraAssetName = "tab_bar_camera"

    /// 62×62 pt: картинка из ассета или одно составное изображение (градиент + иконка).
    static func tabBarCenterCameraButtonImage() -> UIImage {
        let side: CGFloat = 62
        let format = UIGraphicsImageRendererFormat()
        format.scale = UITraitCollection.current.displayScale
        format.opaque = false
        if let asset = UIImage(named: tabBarCameraAssetName) {
            let target = CGSize(width: side, height: side)
            let renderer = UIGraphicsImageRenderer(size: target, format: format)
            return renderer.image { _ in
                asset.draw(in: CGRect(origin: .zero, size: target))
            }
        }
        return tabBarCenterCameraComposed(side: side, format: format)
    }

    private static func tabBarCenterCameraComposed(side: CGFloat, format: UIGraphicsImageRendererFormat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        return renderer.image { ctx in
            let colors = [
                UIColor(red: 22 / 255, green: 110 / 255, blue: 62 / 255, alpha: 1).cgColor,
                UIColor.appCollectionCtaGradientEnd.cgColor,
            ] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            if let grad = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
                ctx.cgContext.drawLinearGradient(
                    grad,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: side, y: side),
                    options: []
                )
            }

            let iconSide = side * 0.44
            let pad = (side - iconSide) / 2
            let iconRect = CGRect(x: pad, y: pad, width: iconSide, height: iconSide)
            let cfg = UIImage.SymbolConfiguration(pointSize: side * 0.38, weight: .semibold)
            let sym = UIImage(systemName: "camera.viewfinder", withConfiguration: cfg)
                ?? UIImage(systemName: "camera.fill", withConfiguration: cfg)
            sym?.withTintColor(.white, renderingMode: .alwaysOriginal).draw(in: iconRect)
        }
    }
}

// MARK: - Tab item

private final class MainTabItemControl: UIControl {

    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.tintColor = MainTabItemControl.inactiveTint
        return iv
    }()

    private let dotView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.appReadMore
        v.layer.cornerRadius = 2.5
        return v
    }()

    private static let inactiveTint = UIColor(red: 0.62, green: 0.62, blue: 0.64, alpha: 1)

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)
        addSubview(dotView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            dotView.centerXAnchor.constraint(equalTo: centerXAnchor),
            dotView.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 4),
            dotView.widthAnchor.constraint(equalToConstant: 5),
            dotView.heightAnchor.constraint(equalToConstant: 5),
            bottomAnchor.constraint(equalTo: dotView.bottomAnchor, constant: 4),
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(assetName: String, fallbackSystemName: String, symbolConfiguration: UIImage.SymbolConfiguration) {
        if let asset = UIImage(named: assetName) {
            iconView.image = asset.withRenderingMode(.alwaysTemplate)
        } else if let sym = UIImage(systemName: fallbackSystemName, withConfiguration: symbolConfiguration) {
            iconView.image = sym.withRenderingMode(.alwaysTemplate)
        } else {
            iconView.image = nil
        }
        setSelected(false)
    }

    func setSelected(_ selected: Bool) {
        iconView.tintColor = selected ? UIColor.appReadMore : Self.inactiveTint
        dotView.alpha = selected ? 1 : 0
    }
}

// MARK: - Center button (целиком одна картинка 62×62, без скругления слоя)

private final class CenterScanFloatingButton: UIButton {

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 0
        layer.masksToBounds = false
        setBackgroundImage(UIImage.tabBarCenterCameraButtonImage(), for: .normal)
    }

    required init?(coder: NSCoder) {
        nil
    }
}
