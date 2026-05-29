//
//  PaywallScreenView.swift
//  Bugs
//

import AVFoundation
import StoreKit
import UIKit

/// Пейвол без скролла. Вертикаль снизу: футер → CTA → вверх. Видео отдельно (top/бока/aspect). У тайтла нет верхнего якоря к видео/экрану — позиция только от `bottom` и контента.
final class PaywallScreenView: UIView {

    let embeddedInOnboarding: Bool

    var onPrimaryTap: (() -> Void)?
    var onCloseTap: (() -> Void)?
    var onTermsTap: (() -> Void)?
    var onPrivacyTap: (() -> Void)?
    var onRestoreTap: (() -> Void)?

    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var videoFadeLayer: CAGradientLayer?
    private var endObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?
    private var backgroundObserver: NSObjectProtocol?
    /// After natural end we stay on the last frame; resume must not restart playback.
    private var videoPlaybackFinished = false
    private var didKickoffPriceLoad = false
    private var didRevealPaywallPreviewCard = false
    private var onboardingPlaybackWorkItem: DispatchWorkItem?
    private var didStartOnboardingPaywallPlayback = false

    private let previewCard = PaywallOnboardingPreviewCardView()

    private let videoContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .black
        v.clipsToBounds = true
        return v
    }()

    private let closeButton: UIButton = {
        let b = UIButton(type: .custom)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setImage(UIImage(named: "paywall_close")?.withRenderingMode(.alwaysTemplate), for: .normal)
        b.tintColor = .appPaywallClose
        b.accessibilityLabel = L10n.string("paywall.close.accessibility")
        return b
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 24, weight: .bold)
        l.textColor = .appTextPrimary
        l.textAlignment = .center
        l.numberOfLines = 0
        l.text = L10n.string("paywall.headline")
        l.setContentCompressionResistancePriority(.required, for: .vertical)
        return l
    }()

    private let benefitsGrid: UIStackView = {
        let row0 = UIStackView()
        row0.axis = .horizontal
        row0.spacing = 6
        row0.distribution = .fillEqually
        row0.alignment = .fill

        let row1 = UIStackView()
        row1.axis = .horizontal
        row1.spacing = 6
        row1.distribution = .fillEqually
        row1.alignment = .fill

        let v = UIStackView(arrangedSubviews: [row0, row1])
        v.translatesAutoresizingMaskIntoConstraints = false
        v.axis = .vertical
        v.spacing = 6
        v.alignment = .fill
        v.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return v
    }()

    private let productLabel = UILabel()
    private let cancelInfoLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 14, weight: .regular)
        l.textColor = .appTextSecondary
        l.textAlignment = .center
        l.numberOfLines = 0
        l.text = L10n.string("paywall.cancel_anytime")
        l.setContentCompressionResistancePriority(.required, for: .vertical)
        return l
    }()

    private let primaryButton: GradientRoundedCTAControl = {
        let b = GradientRoundedCTAControl()
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle(L10n.string("paywall.button.next"), for: .normal)
        b.setContentCompressionResistancePriority(.required, for: .vertical)
        return b
    }()

    private let footerStack: UIStackView = {
        let s = UIStackView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.axis = .horizontal
        s.alignment = .center
        s.spacing = 28
        s.distribution = .fill
        return s
    }()
    private var footerButtons: [UIButton] = []

    private let primaryHeightConstraint: NSLayoutConstraint
    /// В ячейке `safeAreaLayoutGuide` без инсетов — крестик и низ футера через `window` / VC.
    private var closeTopConstraint: NSLayoutConstraint!
    private var closeLeadingConstraint: NSLayoutConstraint!
    /// Низ кнопки подписки: на 44 pt выше нижней границы safe area (`OnboardingFloatingCTALayout`).
    private var primaryBottomSafeConstraint: NSLayoutConstraint!
    /// Футер под кнопкой — верх от `primary.bottom`; низ не выше чем от низа экрана с отступом (в embed обновляется с safe bottom).
    private var footerBottomMaxConstraint: NSLayoutConstraint!

    init(embeddedInOnboarding: Bool) {
        self.embeddedInOnboarding = embeddedInOnboarding
        primaryHeightConstraint = primaryButton.heightAnchor.constraint(equalToConstant: 56)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .appBackground

        productLabel.translatesAutoresizingMaskIntoConstraints = false
        productLabel.font = .systemFont(ofSize: 14, weight: .regular)
        productLabel.textAlignment = .center
        productLabel.numberOfLines = 0
        productLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        configureBenefitsGrid()
        configureFooterButtons()
        updateProductLabel(priceText: nil)

        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        primaryButton.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)
        primaryButton.isPulseAnimationEnabled = true

        addSubview(videoContainer)
        addSubview(previewCard)
        addSubview(titleLabel)
        addSubview(benefitsGrid)
        addSubview(productLabel)
        addSubview(cancelInfoLabel)
        addSubview(footerStack)
        addSubview(primaryButton)
        addSubview(closeButton)

        let ctaBottomOffset = OnboardingFloatingCTALayout.bottomOffsetFromSafeAreaBottom
        if embeddedInOnboarding {
            primaryButton.alpha = 0
            closeTopConstraint = closeButton.topAnchor.constraint(equalTo: topAnchor, constant: 16)
            closeLeadingConstraint = closeButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16)
            primaryBottomSafeConstraint = primaryButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -ctaBottomOffset)
            footerBottomMaxConstraint = footerStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -16)
        } else {
            closeTopConstraint = closeButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 16)
            closeLeadingConstraint = closeButton.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 16)
            primaryBottomSafeConstraint = primaryButton.bottomAnchor.constraint(
                equalTo: safeAreaLayoutGuide.bottomAnchor,
                constant: -ctaBottomOffset
            )
            footerBottomMaxConstraint = footerStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -16)
        }

        NSLayoutConstraint.activate([
            // Видео: только верх, бока и высота от ширины — не участвует в цепочке контента.
            videoContainer.topAnchor.constraint(equalTo: topAnchor),
            videoContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            videoContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            videoContainer.heightAnchor.constraint(equalTo: videoContainer.widthAnchor, multiplier: 420.0 / 390.0),

            closeTopConstraint,
            closeLeadingConstraint,
            closeButton.widthAnchor.constraint(equalToConstant: 24),
            closeButton.heightAnchor.constraint(equalToConstant: 24),

            // Снизу вверх: primary (низ = safe bottom − 44) → футер под ней → дальше вверх.
            primaryBottomSafeConstraint,
            primaryButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 46),
            primaryButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -46),
            primaryHeightConstraint,

            footerStack.topAnchor.constraint(equalTo: primaryButton.bottomAnchor, constant: 16),
            footerStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            footerStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 4),
            footerStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
            footerStack.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -8),
            footerBottomMaxConstraint,
            cancelInfoLabel.bottomAnchor.constraint(equalTo: primaryButton.topAnchor, constant: -16),

            cancelInfoLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            cancelInfoLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            productLabel.bottomAnchor.constraint(equalTo: cancelInfoLabel.topAnchor, constant: -8),
            productLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            productLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            benefitsGrid.bottomAnchor.constraint(equalTo: productLabel.topAnchor, constant: -20),
            benefitsGrid.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            benefitsGrid.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            previewCard.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 54),
            previewCard.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -54),
            titleLabel.topAnchor.constraint(equalTo: previewCard.bottomAnchor, constant: 23),
            titleLabel.bottomAnchor.constraint(equalTo: benefitsGrid.topAnchor, constant: -16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
        ])

        let previewBelowVideo = previewCard.topAnchor.constraint(greaterThanOrEqualTo: videoContainer.bottomAnchor, constant: 8)
        previewBelowVideo.priority = .defaultHigh
        previewBelowVideo.isActive = true

        footerStack.setContentCompressionResistancePriority(.required, for: .vertical)

        sendSubviewToBack(videoContainer)
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        onboardingPlaybackWorkItem?.cancel()
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
        if let backgroundObserver {
            NotificationCenter.default.removeObserver(backgroundObserver)
        }
        player?.pause()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        applyManualOnboardingSafeAreaInsets()
        if player == nil {
            setupVideo(autoPlay: !embeddedInOnboarding)
        }
        if Self.paywallVideoURL() == nil, !embeddedInOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.revealPaywallPreviewCardIfNeeded()
            }
        }
        if !didKickoffPriceLoad {
            didKickoffPriceLoad = true
            Task { [weak self] in
                guard let self else { return }
                await self.loadProductPrice()
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyManualOnboardingSafeAreaInsets()
        playerLayer?.frame = videoContainer.bounds
        videoFadeLayer?.frame = videoContainer.bounds
        updateFooterButtonsLineModeIfNeeded()
    }

    private func applyManualOnboardingSafeAreaInsets() {
        guard embeddedInOnboarding else { return }
        let s = resolvedEmbeddingSafeAreaInsets()
        let offset = OnboardingFloatingCTALayout.bottomOffsetFromSafeAreaBottom
        closeTopConstraint.constant = 16 + s.top
        closeLeadingConstraint.constant = 16 + s.left
        primaryBottomSafeConstraint.constant = -(s.bottom + offset)
        footerBottomMaxConstraint.constant = -(16 + s.bottom)
    }

    /// В ячейке инсеты часто нулевые — берём max(window, hosting VC, keyWindow).
    private func resolvedEmbeddingSafeAreaInsets() -> UIEdgeInsets {
        func sceneKeyWindowInsets() -> UIEdgeInsets {
            guard let scene = window?.windowScene ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
            else { return .zero }
            let key = scene.windows.first { $0.isKeyWindow } ?? scene.windows.first
            return key?.safeAreaInsets ?? .zero
        }

        let wInsets = window?.safeAreaInsets ?? .zero
        let keyInsets = sceneKeyWindowInsets()
        var merged = UIEdgeInsets(
            top: max(wInsets.top, keyInsets.top),
            left: max(wInsets.left, keyInsets.left),
            bottom: max(wInsets.bottom, keyInsets.bottom),
            right: max(wInsets.right, keyInsets.right)
        )

        var r: UIResponder? = self
        while let x = r {
            if let vc = x as? UIViewController {
                let v = vc.view.safeAreaInsets
                merged.top = max(merged.top, v.top)
                merged.left = max(merged.left, v.left)
                merged.bottom = max(merged.bottom, v.bottom)
                merged.right = max(merged.right, v.right)
                break
            }
            r = x.next
        }

        return merged
    }

    private func configureBenefitsGrid() {
        let c0 = PaywallBenefitCardView(imageName: "paywall_benefit_scan", captionKey: "paywall.benefit.scans")
        let c1 = PaywallBenefitCardView(imageName: "paywall_benefit_collection", captionKey: "paywall.benefit.collection")
        let c2 = PaywallBenefitCardView(imageName: "paywall_benefit_ai", captionKey: "paywall.benefit.ai")
        let c3 = PaywallBenefitCardView(imageName: "paywall_benefit_trophy", captionKey: "paywall.benefit.achievements")
        guard benefitsGrid.arrangedSubviews.count >= 2,
              let row0 = benefitsGrid.arrangedSubviews[0] as? UIStackView,
              let row1 = benefitsGrid.arrangedSubviews[1] as? UIStackView else { return }
        row0.addArrangedSubview(c0)
        row0.addArrangedSubview(c1)
        row1.addArrangedSubview(c2)
        row1.addArrangedSubview(c3)
    }

    private func configureFooterButtons() {
        let terms = makeFooterButton(titleKey: "paywall.footer.terms")
        let privacy = makeFooterButton(titleKey: "paywall.footer.privacy")
        let restore = makeFooterButton(titleKey: "paywall.footer.restore")
        terms.addTarget(self, action: #selector(termsTapped), for: .touchUpInside)
        privacy.addTarget(self, action: #selector(privacyTapped), for: .touchUpInside)
        restore.addTarget(self, action: #selector(restoreTapped), for: .touchUpInside)
        footerStack.addArrangedSubview(terms)
        footerStack.addArrangedSubview(privacy)
        footerStack.addArrangedSubview(restore)
        footerButtons = [terms, privacy, restore]
        // На узких экранах все три кнопки сжимаются равномерно.
        terms.widthAnchor.constraint(equalTo: privacy.widthAnchor).isActive = true
        privacy.widthAnchor.constraint(equalTo: restore.widthAnchor).isActive = true
    }

    private func makeFooterButton(titleKey: String) -> UIButton {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle(L10n.string(titleKey), for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 12, weight: .regular)
        b.titleLabel?.numberOfLines = 2
        b.titleLabel?.textAlignment = .center
        b.titleLabel?.adjustsFontSizeToFitWidth = false
        b.titleLabel?.minimumScaleFactor = 0.75
        b.titleLabel?.lineBreakMode = .byWordWrapping
        b.setTitleColor(.appTextSecondary, for: .normal)
        b.contentEdgeInsets = UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        b.setContentCompressionResistancePriority(.required, for: .horizontal)
        b.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return b
    }

    /// Если подписи футера помещаются в одну строку, не переносим их; иначе включаем 2 строки.
    private func updateFooterButtonsLineModeIfNeeded() {
        guard footerButtons.count == 3 else { return }
        let availableWidth = max(0, bounds.width - 8)
        guard availableWidth > 0 else { return }

        let font = UIFont.systemFont(ofSize: 12, weight: .regular)
        let horizontalSpacing = footerStack.spacing * CGFloat(footerButtons.count - 1)
        let perButtonWidth = (availableWidth - horizontalSpacing) / CGFloat(footerButtons.count)
        guard perButtonWidth > 0 else { return }
        let fitsSingleLine = footerButtons.allSatisfy { button in
            let title = button.title(for: .normal) ?? ""
            let size = (title as NSString).size(withAttributes: [.font: font])
            return ceil(size.width) <= perButtonWidth
        }
        let targetLines = fitsSingleLine ? 1 : 2

        for button in footerButtons {
            let title = button.title(for: .normal) ?? ""
            let longestWordWidth = title
                .split(whereSeparator: \.isWhitespace)
                .map { word -> CGFloat in
                    let size = (String(word) as NSString).size(withAttributes: [.font: font])
                    return ceil(size.width)
                }
                .max() ?? 0
            // Если слово не влезает целиком, не ломаем по символам — уменьшаем шрифт.
            let needsFontShrink = longestWordWidth > perButtonWidth

            if needsFontShrink {
                // Для multi-line UIKit не умеет корректно ужимать шрифт,
                // поэтому переводим кнопку в одну строку и включаем fit width.
                button.titleLabel?.numberOfLines = 1
                button.titleLabel?.lineBreakMode = .byClipping
                button.titleLabel?.adjustsFontSizeToFitWidth = true
            } else {
                button.titleLabel?.numberOfLines = targetLines
                button.titleLabel?.lineBreakMode = fitsSingleLine ? .byClipping : .byWordWrapping
                button.titleLabel?.adjustsFontSizeToFitWidth = false
            }
        }
    }

    private func setupVideo(autoPlay: Bool = true) {
        guard let url = Self.paywallVideoURL() else { return }
        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        p.actionAtItemEnd = .none
        player = p

        let layer = AVPlayerLayer(player: p)
        layer.videoGravity = .resizeAspectFill
        layer.frame = videoContainer.bounds
        videoContainer.layer.insertSublayer(layer, at: 0)
        playerLayer = layer

        let fade = CAGradientLayer()
        fade.colors = [UIColor.clear.cgColor, UIColor.appBackground.cgColor]
        fade.locations = [0.55, 1] as [NSNumber]
        fade.startPoint = CGPoint(x: 0.5, y: 0.35)
        fade.endPoint = CGPoint(x: 0.5, y: 1)
        fade.frame = videoContainer.bounds
        videoContainer.layer.addSublayer(fade)
        videoFadeLayer = fade

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self, weak p, weak item] _ in
            guard let self, let p, let item else { return }
            self.videoPlaybackFinished = true
            Self.seekToApproxLastFrame(player: p, item: item)
            self.revealPaywallPreviewCardIfNeeded()
        }

        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self, weak p, weak item] _ in
            guard let self, let p, let item else { return }
            if self.videoPlaybackFinished {
                Self.seekToApproxLastFrame(player: p, item: item)
            } else if self.embeddedInOnboarding, !self.didStartOnboardingPaywallPlayback {
                p.pause()
            } else {
                p.play()
            }
        }
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak p] _ in
            p?.pause()
        }

        if autoPlay {
            p.play()
        } else {
            p.pause()
        }
    }

    /// Hold last decoded frame (no loop). Slightly before `duration` for reliable decoding.
    private static func seekToApproxLastFrame(player: AVPlayer, item: AVPlayerItem) {
        let d = item.duration
        guard d.isNumeric && !d.seconds.isNaN && d.seconds > 0 else {
            player.pause()
            return
        }
        let step = CMTime(value: 1, timescale: max(d.timescale, 600))
        let t = CMTimeSubtract(d, step)
        let target = t.seconds > 0 ? t : .zero
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
            player.pause()
        }
    }

    private func revealPaywallPreviewCardIfNeeded() {
        guard !didRevealPaywallPreviewCard else { return }
        didRevealPaywallPreviewCard = true
        previewCard.animateInIfNeeded()
    }

    /// В онбординге плеер инициализируется в `didMoveToWindow`, `play()` — по кнопке Continue.
    func scheduleOnboardingPaywallPlayback(after delay: TimeInterval = 0.1) {
        guard embeddedInOnboarding else { return }
        onboardingPlaybackWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.playOnboardingPaywallVideoIfNeeded()
        }
        onboardingPlaybackWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func cancelScheduledOnboardingPaywallPlayback() {
        onboardingPlaybackWorkItem?.cancel()
        onboardingPlaybackWorkItem = nil
    }

    private func playOnboardingPaywallVideoIfNeeded() {
        guard embeddedInOnboarding else { return }
        didStartOnboardingPaywallPlayback = true
        if player == nil {
            setupVideo(autoPlay: true)
            return
        }
        if Self.paywallVideoURL() == nil {
            revealPaywallPreviewCardIfNeeded()
        } else {
            player?.play()
        }
    }

    private static func paywallVideoURL() -> URL? {
        if let u = Bundle.main.url(forResource: "paywall", withExtension: "mp4", subdirectory: "Videos") {
            return u
        }
        return Bundle.main.url(forResource: "paywall", withExtension: "mp4")
    }

    @MainActor
    private func loadProductPrice() async {
        var price: String?
        do {
            let products = try await SubscriptionManager.shared.loadSubscriptionProducts()
            price = products.first?.displayPrice
        } catch {
            price = nil
        }
        updateProductLabel(priceText: price)
    }

    func setPurchaseInProgress(_ inProgress: Bool) {
        primaryButton.isEnabled = !inProgress
        primaryButton.alpha = inProgress ? 0.55 : 1
    }

    private func updateProductLabel(priceText: String?) {
        let ws = CharacterSet.whitespacesAndNewlines
        let prefix = L10n.string("paywall.product.prefix").trimmingCharacters(in: ws)
        let suffix = L10n.string("paywall.product.suffix").trimmingCharacters(in: ws)
        let mid = priceText ?? "—"
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .regular),
            .foregroundColor: UIColor.appPaywallProductBody,
        ]
        let priceAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .regular),
            .foregroundColor: UIColor.appPaywallPriceHighlight,
        ]
        let m = NSMutableAttributedString()
        if !prefix.isEmpty {
            m.append(NSAttributedString(string: prefix, attributes: bodyAttrs))
            m.append(NSAttributedString(string: " ", attributes: bodyAttrs))
        }
        m.append(NSAttributedString(string: mid, attributes: priceAttrs))
        if !suffix.isEmpty {
            m.append(NSAttributedString(string: " ", attributes: bodyAttrs))
            m.append(NSAttributedString(string: suffix, attributes: bodyAttrs))
        }
        productLabel.attributedText = m
    }

    @objc
    private func closeTapped() {
        onCloseTap?()
    }

    @objc
    private func primaryTapped() {
        onPrimaryTap?()
    }

    @objc
    private func termsTapped() {
        onTermsTap?()
    }

    @objc
    private func privacyTapped() {
        onPrivacyTap?()
    }

    @objc
    private func restoreTapped() {
        onRestoreTap?()
    }
}
