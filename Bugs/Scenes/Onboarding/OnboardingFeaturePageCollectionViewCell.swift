//
//  OnboardingFeaturePageCollectionViewCell.swift
//  Bugs
//

import Lottie
import UIKit

/// Логи автопрокрутки отзывов — фильтр в консоли Xcode: `OnboardingAutoScroll`.
/// Не включайте в схеме `OS_ACTIVITY_MODE=disable` — иначе NSLog не виден.
private enum OnboardingAutoScrollLogger {
    nonisolated static func log(_ message: String) {
        NSLog("%@", "[OnboardingAutoScroll] \(message)")
    }
}

final class OnboardingFeaturePageCollectionViewCell: UICollectionViewCell {

    static let reuseIdentifier = "OnboardingFeaturePageCollectionViewCell"

    enum BackgroundKind {
        case lottie(name: String)
        case testimonials(imageAssetName: String)
    }

    private let animationView: LottieAnimationView = {
        let v = LottieAnimationView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.contentMode = .scaleAspectFill
        v.loopMode = .loop
        v.backgroundBehavior = .pauseAndRestore
        return v
    }()

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.isHidden = true
        return iv
    }()
    private let testimonialsContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()
    private let topReviewsCollectionView = OnboardingReviewsCollectionFactory.makeCollectionView()
    private let bottomReviewsCollectionView = OnboardingReviewsCollectionFactory.makeCollectionView()
    private var imageAspectRatioConstraint: NSLayoutConstraint?
    private var testimonialsTopConstraint: NSLayoutConstraint?
    private var autoScrollDisplayLink: CADisplayLink?
    private var topRowDirection: CGFloat = -1
    private var bottomRowDirection: CGFloat = 1
    private var didPrepareAutoScroll = false
    private var autoScrollPrepareRetryCount = 0
    private var didLogFirstAutoScrollTick = false
    private var didLogNoScrollRangeWarning = false

    private lazy var topReviews: [OnboardingReviewItem] = [
        .init(name: L10n.string("onboarding.v2.review.michael.name"), text: L10n.string("onboarding.v2.review.michael.text"), avatarAssetName: "onb_review_avatar_michael"),
        .init(name: L10n.string("onboarding.v2.review.jessica.name"), text: L10n.string("onboarding.v2.review.jessica.text"), avatarAssetName: "onb_review_avatar_jessica"),
        .init(name: L10n.string("onboarding.v2.review.ryan.name"), text: L10n.string("onboarding.v2.review.ryan.text"), avatarAssetName: "onb_review_avatar_ryan"),
    ]
    private lazy var bottomReviews: [OnboardingReviewItem] = [
        .init(name: L10n.string("onboarding.v2.review.olivia.name"), text: L10n.string("onboarding.v2.review.olivia.text"), avatarAssetName: "onb_review_avatar_olivia"),
        .init(name: L10n.string("onboarding.v2.review.daniel.name"), text: L10n.string("onboarding.v2.review.daniel.text"), avatarAssetName: "onb_review_avatar_daniel"),
        .init(name: L10n.string("onboarding.v2.review.amanda.name"), text: L10n.string("onboarding.v2.review.amanda.text"), avatarAssetName: "onb_review_avatar_amanda"),
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        semanticContentAttribute = .forceLeftToRight
        clipsToBounds = false
        contentView.semanticContentAttribute = .forceLeftToRight
        contentView.backgroundColor = .appBackground
        contentView.clipsToBounds = false

        contentView.addSubview(animationView)
        contentView.addSubview(imageView)
        contentView.addSubview(testimonialsContainer)
        testimonialsContainer.addSubview(topReviewsCollectionView)
        testimonialsContainer.addSubview(bottomReviewsCollectionView)

        topReviewsCollectionView.dataSource = self
        bottomReviewsCollectionView.dataSource = self
        topReviewsCollectionView.delegate = self
        bottomReviewsCollectionView.delegate = self
        topReviewsCollectionView.register(OnboardingReviewCardCell.self, forCellWithReuseIdentifier: OnboardingReviewCardCell.reuseIdentifier)
        bottomReviewsCollectionView.register(OnboardingReviewCardCell.self, forCellWithReuseIdentifier: OnboardingReviewCardCell.reuseIdentifier)

        NSLayoutConstraint.activate([
            animationView.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor),
            animationView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            animationView.bottomAnchor.constraint(
                equalTo: contentView.safeAreaLayoutGuide.bottomAnchor,
                constant: -(OnboardingFloatingCTALayout.buttonHeight + OnboardingFloatingCTALayout.bottomOffsetFromSafeAreaBottom + 8)
            ),

            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),

            testimonialsContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            testimonialsContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            testimonialsContainer.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor),
        ])
        testimonialsTopConstraint = testimonialsContainer.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -36)
        testimonialsTopConstraint?.isActive = true

        NSLayoutConstraint.activate([
            topReviewsCollectionView.topAnchor.constraint(equalTo: testimonialsContainer.topAnchor),
            topReviewsCollectionView.leadingAnchor.constraint(equalTo: testimonialsContainer.leadingAnchor),
            topReviewsCollectionView.trailingAnchor.constraint(equalTo: testimonialsContainer.trailingAnchor),
            topReviewsCollectionView.heightAnchor.constraint(equalToConstant: 127),

            bottomReviewsCollectionView.topAnchor.constraint(equalTo: topReviewsCollectionView.bottomAnchor, constant: 12),
            bottomReviewsCollectionView.leadingAnchor.constraint(equalTo: testimonialsContainer.leadingAnchor),
            bottomReviewsCollectionView.trailingAnchor.constraint(equalTo: testimonialsContainer.trailingAnchor),
            bottomReviewsCollectionView.heightAnchor.constraint(equalToConstant: 127),
            bottomReviewsCollectionView.bottomAnchor.constraint(equalTo: testimonialsContainer.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        stopAutoScroll()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        OnboardingAutoScrollLogger.log("prepareForReuse — stop scroll, reset flags")
        animationView.stop()
        animationView.animation = nil
        imageView.image = nil
        imageAspectRatioConstraint?.isActive = false
        imageAspectRatioConstraint = nil
        imageView.isHidden = true
        testimonialsContainer.isHidden = true
        animationView.isHidden = false
        stopAutoScroll(reason: "prepareForReuse")
        didPrepareAutoScroll = false
        autoScrollPrepareRetryCount = 0
        didLogFirstAutoScrollTick = false
        didLogNoScrollRangeWarning = false
    }

    func configure(background: BackgroundKind) {
        switch background {
        case let .lottie(name):
            imageView.isHidden = true
            animationView.isHidden = false
            animationView.animation = LottieAnimation.named(name, bundle: .main)
            animationView.play()
        case let .testimonials(assetName):
            OnboardingAutoScrollLogger.log("configure testimonials asset=\(assetName)")
            animationView.stop()
            animationView.animation = nil
            animationView.isHidden = true
            imageView.isHidden = false
            testimonialsContainer.isHidden = false
            imageView.image = UIImage(named: assetName)
            imageAspectRatioConstraint?.isActive = false
            if let image = imageView.image, image.size.width > 0 {
                let ratio = image.size.height / image.size.width
                let c = imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: ratio)
                c.isActive = true
                imageAspectRatioConstraint = c
            } else {
                OnboardingAutoScrollLogger.log("configure testimonials — hero image missing or zero width")
            }
            topReviewsCollectionView.reloadData()
            bottomReviewsCollectionView.reloadData()
            stopAutoScroll(reason: "configure(testimonials)")
            didPrepareAutoScroll = false
            autoScrollPrepareRetryCount = 0
            didLogFirstAutoScrollTick = false
            didLogNoScrollRangeWarning = false
            setNeedsLayout()
            DispatchQueue.main.async { [weak self] in
                OnboardingAutoScrollLogger.log("configure testimonials — async prepare")
                self?.prepareAutoScrollIfPossible(forceReset: true, source: "configure.async")
            }
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            OnboardingAutoScrollLogger.log("didMoveToWindow — window=nil, stop scroll")
            stopAutoScroll(reason: "didMoveToWindow(nil)")
        } else {
            OnboardingAutoScrollLogger.log("didMoveToWindow — window attached, prepare")
            prepareAutoScrollIfPossible(source: "didMoveToWindow")
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let overlap: CGFloat = bounds.height < 700 ? -100.0 : -36.0
        if testimonialsTopConstraint?.constant != overlap {
            OnboardingAutoScrollLogger.log("layoutSubviews — cellH=\(String(format: "%.1f", bounds.height)) overlap=\(overlap)")
        }
        testimonialsTopConstraint?.constant = overlap
        prepareAutoScrollIfPossible(source: "layoutSubviews")
    }

    private func startAutoScrollIfNeeded(source: String) {
        if testimonialsContainer.isHidden {
            OnboardingAutoScrollLogger.log("startAutoScroll SKIP [\(source)] — testimonials hidden")
            return
        }
        if window == nil {
            OnboardingAutoScrollLogger.log("startAutoScroll SKIP [\(source)] — no window")
            return
        }
        if autoScrollDisplayLink != nil {
            return
        }
        let link = CADisplayLink(target: self, selector: #selector(handleAutoScrollTick(_:)))
        link.add(to: .main, forMode: .common)
        autoScrollDisplayLink = link
        OnboardingAutoScrollLogger.log("startAutoScroll OK [\(source)] — displayLink created | \(autoScrollStateSnapshot())")
    }

    private func prepareAutoScrollIfPossible(forceReset: Bool = false, source: String = "unknown") {
        if testimonialsContainer.isHidden {
            return
        }
        let topW = topReviewsCollectionView.bounds.width
        let bottomW = bottomReviewsCollectionView.bounds.width
        if topW <= 0, bottomW <= 0 {
            OnboardingAutoScrollLogger.log("prepare SKIP [\(source)] — collection bounds width=0 (cell=\(String(format: "%.1f", bounds.width))x\(String(format: "%.1f", bounds.height)))")
            scheduleAutoScrollPrepareRetryIfNeeded(source: source)
            return
        }
        topReviewsCollectionView.layoutIfNeeded()
        bottomReviewsCollectionView.layoutIfNeeded()
        if forceReset || !didPrepareAutoScroll {
            resetAutoScrollStartPositions(source: source)
            didPrepareAutoScroll = true
        }
        let topMax = scrollableRangeX(for: topReviewsCollectionView)
        let bottomMax = scrollableRangeX(for: bottomReviewsCollectionView)
        if topMax <= 0, bottomMax <= 0 {
            OnboardingAutoScrollLogger.log("prepare WARN [\(source)] — no scroll range (contentSize not ready?) | \(autoScrollStateSnapshot())")
            scheduleAutoScrollPrepareRetryIfNeeded(source: source)
        } else {
            autoScrollPrepareRetryCount = 0
            OnboardingAutoScrollLogger.log("prepare OK [\(source)] forceReset=\(forceReset) | \(autoScrollStateSnapshot())")
        }
        startAutoScrollIfNeeded(source: source)
    }

    private func scheduleAutoScrollPrepareRetryIfNeeded(source: String) {
        let maxRetries = 8
        guard autoScrollPrepareRetryCount < maxRetries else {
            OnboardingAutoScrollLogger.log("prepare RETRY exhausted after \(maxRetries) attempts (last=\(source)) | \(autoScrollStateSnapshot())")
            return
        }
        autoScrollPrepareRetryCount += 1
        let attempt = autoScrollPrepareRetryCount
        OnboardingAutoScrollLogger.log("prepare RETRY #\(attempt) scheduled in 0.12s (from \(source))")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self else { return }
            OnboardingAutoScrollLogger.log("prepare RETRY #\(attempt) firing")
            self.prepareAutoScrollIfPossible(forceReset: true, source: "retry#\(attempt)")
        }
    }

    private func stopAutoScroll(reason: String = "unspecified") {
        let hadLink = autoScrollDisplayLink != nil
        autoScrollDisplayLink?.invalidate()
        autoScrollDisplayLink = nil
        topRowDirection = -1
        bottomRowDirection = 1
        if hadLink {
            OnboardingAutoScrollLogger.log("stopAutoScroll — reason=\(reason)")
        }
    }

    private func resetAutoScrollStartPositions(source: String) {
        let topMax = scrollableRangeX(for: topReviewsCollectionView)
        topReviewsCollectionView.setContentOffset(CGPoint(x: topMax, y: 0), animated: false)
        topRowDirection = -1

        bottomReviewsCollectionView.setContentOffset(.zero, animated: false)
        bottomRowDirection = 1
        OnboardingAutoScrollLogger.log("resetOffsets [\(source)] topMax=\(String(format: "%.1f", topMax)) bottomMax=\(String(format: "%.1f", scrollableRangeX(for: bottomReviewsCollectionView)))")
    }

    private func scrollableRangeX(for collectionView: UICollectionView) -> CGFloat {
        max(0, collectionView.contentSize.width - collectionView.bounds.width)
    }

    private func autoScrollStateSnapshot() -> String {
        func row(_ name: String, _ cv: UICollectionView) -> String {
            let maxX = scrollableRangeX(for: cv)
            return "\(name){bounds=\(String(format: "%.0f", cv.bounds.width))x\(String(format: "%.0f", cv.bounds.height)) contentW=\(String(format: "%.1f", cv.contentSize.width)) offsetX=\(String(format: "%.1f", cv.contentOffset.x)) maxX=\(String(format: "%.1f", maxX)) items=\(cv.numberOfItems(inSection: 0))}"
        }
        let link = autoScrollDisplayLink == nil ? "off" : "on"
        return "cell=\(String(format: "%.0f", bounds.width))x\(String(format: "%.0f", bounds.height)) window=\(window == nil ? "nil" : "ok") link=\(link) retries=\(autoScrollPrepareRetryCount) | \(row("top", topReviewsCollectionView)) | \(row("bottom", bottomReviewsCollectionView))"
    }

    @objc
    private func handleAutoScrollTick(_ link: CADisplayLink) {
        guard !testimonialsContainer.isHidden else {
            OnboardingAutoScrollLogger.log("tick SKIP — testimonials hidden")
            return
        }
        if !didLogFirstAutoScrollTick {
            didLogFirstAutoScrollTick = true
            OnboardingAutoScrollLogger.log("tick FIRST | \(autoScrollStateSnapshot())")
        }
        let rawDt = CGFloat(link.targetTimestamp - link.timestamp)
        // На iOS 18 иногда targetTimestamp == timestamp, поэтому берём duration как fallback.
        let dt = rawDt > 0 ? rawDt : CGFloat(link.duration)
        if rawDt <= 0 {
            OnboardingAutoScrollLogger.log("tick WARN — rawDt=\(rawDt), fallbackDt=\(dt) (duration=\(link.duration))")
        }
        autoScroll(collectionView: topReviewsCollectionView, name: "top", direction: &topRowDirection, dt: dt)
        autoScroll(collectionView: bottomReviewsCollectionView, name: "bottom", direction: &bottomRowDirection, dt: dt)
    }

    private func autoScroll(collectionView: UICollectionView, name: String, direction: inout CGFloat, dt: CGFloat) {
        let maxOffsetX = scrollableRangeX(for: collectionView)
        guard maxOffsetX > 0 else {
            if !didLogNoScrollRangeWarning {
                didLogNoScrollRangeWarning = true
                OnboardingAutoScrollLogger.log("tick NO_RANGE \(name) — maxOffsetX=0 contentW=\(collectionView.contentSize.width) boundsW=\(collectionView.bounds.width)")
            }
            return
        }

        // Делаем шаг чуть заметнее, чтобы движение не выглядело "замершим" на маленьких экранах.
        let speed: CGFloat = 30
        let step = max(speed * dt, 0.6)
        var nextX = collectionView.contentOffset.x + (direction * step)
        if nextX <= 0 {
            nextX = 0
            direction = 1
        } else if nextX >= maxOffsetX {
            nextX = maxOffsetX
            direction = -1
        }
        collectionView.setContentOffset(CGPoint(x: nextX, y: 0), animated: false)
    }
}

extension OnboardingFeaturePageCollectionViewCell: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        collectionView === topReviewsCollectionView ? topReviews.count : bottomReviews.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: OnboardingReviewCardCell.reuseIdentifier,
            for: indexPath
        ) as? OnboardingReviewCardCell else {
            return UICollectionViewCell()
        }
        let item = collectionView === topReviewsCollectionView ? topReviews[indexPath.item] : bottomReviews[indexPath.item]
        cell.configure(with: item)
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        CGSize(width: 303, height: 127)
    }
}

private struct OnboardingReviewItem {
    let name: String
    let text: String
    let avatarAssetName: String
}

private enum OnboardingReviewsCollectionFactory {
    static func makeCollectionView() -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 12
        layout.minimumInteritemSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.bounces = false
        cv.clipsToBounds = false
        return cv
    }
}

private final class OnboardingReviewCardCell: UICollectionViewCell {
    static let reuseIdentifier = "OnboardingReviewCardCell"
    private static let baseReviewFontSize: CGFloat = 14
    private static let minReviewFontSize: CGFloat = 8

    private let cardView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .white
        v.layer.cornerRadius = 23
        v.clipsToBounds = true
        return v
    }()
    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 20
        iv.backgroundColor = UIColor(red: 240 / 255, green: 240 / 255, blue: 240 / 255, alpha: 1)
        return iv
    }()
    private let nameLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 14, weight: .semibold)
        l.textColor = UIColor(red: 82 / 255, green: 76 / 255, blue: 67 / 255, alpha: 1)
        l.numberOfLines = 1
        return l
    }()
    private let reviewLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: baseReviewFontSize, weight: .regular)
        l.textColor = UIColor(red: 82 / 255, green: 76 / 255, blue: 67 / 255, alpha: 1)
        l.numberOfLines = 2
        l.lineBreakMode = .byWordWrapping
        return l
    }()
    private let starsImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.image = UIImage(named: "onb_review_stars")
        return iv
    }()
    private var reviewRawText: String = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
        contentView.clipsToBounds = false
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOpacity = 0.08
        contentView.layer.shadowRadius = 8
        contentView.layer.shadowOffset = CGSize(width: 0, height: 3)
        contentView.addSubview(cardView)
        cardView.addSubview(avatarImageView)
        cardView.addSubview(nameLabel)
        cardView.addSubview(reviewLabel)
        cardView.addSubview(starsImageView)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            avatarImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            avatarImageView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            avatarImageView.widthAnchor.constraint(equalToConstant: 40),
            avatarImageView.heightAnchor.constraint(equalToConstant: 40),

            nameLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            nameLabel.topAnchor.constraint(equalTo: avatarImageView.bottomAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),

            reviewLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            reviewLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            reviewLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            reviewLabel.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -12),

            starsImageView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            starsImageView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 23),
            starsImageView.widthAnchor.constraint(equalToConstant: 128),
            starsImageView.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.layer.shadowPath = UIBezierPath(
            roundedRect: cardView.frame,
            cornerRadius: cardView.layer.cornerRadius
        ).cgPath
        applyReviewTextFontFitting()
    }

    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let attrs = super.preferredLayoutAttributesFitting(layoutAttributes)
        contentView.layoutIfNeeded()
        applyReviewTextFontFitting()
        return attrs
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.image = nil
        nameLabel.text = nil
        reviewLabel.text = nil
        reviewRawText = ""
        reviewLabel.font = .systemFont(ofSize: Self.baseReviewFontSize, weight: .regular)
    }

    func configure(with item: OnboardingReviewItem) {
        nameLabel.text = item.name
        reviewRawText = item.text
        reviewLabel.text = item.text
        reviewLabel.font = .systemFont(ofSize: Self.baseReviewFontSize, weight: .regular)
        avatarImageView.image = UIImage(named: item.avatarAssetName)
        setNeedsLayout()
        layoutIfNeeded()
        applyReviewTextFontFitting()
    }

    private func applyReviewTextFontFitting() {
        guard !reviewRawText.isEmpty else { return }
        let width = reviewLabel.bounds.width
        guard width > 1 else { return }

        let maxHeight = CGFloat(2) * UIFont.systemFont(ofSize: Self.baseReviewFontSize, weight: .regular).lineHeight
        var fontSize: CGFloat = Self.baseReviewFontSize
        let minSize: CGFloat = Self.minReviewFontSize

        while fontSize > minSize {
            let testFont = UIFont.systemFont(ofSize: fontSize, weight: .regular)
            let attrs: [NSAttributedString.Key: Any] = [.font: testFont]
            let rect = (reviewRawText as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attrs,
                context: nil
            )
            if ceil(rect.height) <= maxHeight {
                reviewLabel.font = testFont
                return
            }
            fontSize -= 0.5
        }
        reviewLabel.font = .systemFont(ofSize: minSize, weight: .regular)
    }
}

final class OnboardingCustomPageControlView: UIView {
    private let dotStack: UIStackView = {
        let s = UIStackView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.axis = .horizontal
        s.alignment = .center
        s.spacing = 3
        return s
    }()

    private var dotViews: [UIView] = []
    private var widthConstraints: [NSLayoutConstraint] = []

    var currentPage: Int = 0 {
        didSet { updateAppearance() }
    }

    init(numberOfPages: Int) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(dotStack)
        NSLayoutConstraint.activate([
            dotStack.topAnchor.constraint(equalTo: topAnchor),
            dotStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            dotStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            dotStack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        for _ in 0..<max(0, numberOfPages) {
            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.layer.cornerRadius = 4
            dot.clipsToBounds = true
            dotStack.addArrangedSubview(dot)
            let w = dot.widthAnchor.constraint(equalToConstant: 8)
            w.isActive = true
            NSLayoutConstraint.activate([
                dot.heightAnchor.constraint(equalToConstant: 8),
            ])
            dotViews.append(dot)
            widthConstraints.append(w)
        }
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func updateAppearance() {
        for (index, dot) in dotViews.enumerated() {
            let selected = (index == currentPage)
            widthConstraints[index].constant = selected ? 24 : 8
            dot.backgroundColor = selected
                ? UIColor(red: 58 / 255, green: 161 / 255, blue: 118 / 255, alpha: 1)
                : UIColor(red: 155 / 255, green: 152 / 255, blue: 148 / 255, alpha: 1)
        }
        layoutIfNeeded()
    }
}
