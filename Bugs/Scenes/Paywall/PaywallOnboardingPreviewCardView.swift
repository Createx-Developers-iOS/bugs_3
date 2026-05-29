//
//  PaywallOnboardingPreviewCardView.swift
//  Bugs
//

import QuartzCore
import UIKit

/// Карточка-превью над заголовком пейвола: появляется после окончания видео.
final class PaywallOnboardingPreviewCardView: UIView {

    private static let pulseLayerKey = "paywallPreviewCardPulse"

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .white
        layer.cornerRadius = 32
        clipsToBounds = true
        alpha = 0
        isAccessibilityElement = true
        accessibilityLabel = [
            L10n.string("paywall.preview.species"),
            L10n.string("paywall.preview.family"),
            L10n.string("paywall.preview.harmless"),
        ].joined(separator: ", ")

        let thumbnail = UIImageView()
        thumbnail.translatesAutoresizingMaskIntoConstraints = false
        thumbnail.contentMode = .scaleAspectFill
        thumbnail.clipsToBounds = true
        thumbnail.layer.cornerRadius = 12
        thumbnail.image = UIImage(named: "paywall_onboarding_preview")

        let nameLabel = UILabel()
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        nameLabel.textColor = .appTextPrimary
        nameLabel.text = L10n.string("paywall.preview.species")
        nameLabel.numberOfLines = 1

        let familyLabel = UILabel()
        familyLabel.translatesAutoresizingMaskIntoConstraints = false
        familyLabel.font = .systemFont(ofSize: 14, weight: .regular)
        familyLabel.textColor = .appTextSecondary
        familyLabel.text = L10n.string("paywall.preview.family")
        familyLabel.numberOfLines = 1

        let checkView = UIImageView(image: UIImage(named: "insect_detail_status_harmless"))
        checkView.translatesAutoresizingMaskIntoConstraints = false
        checkView.contentMode = .scaleAspectFit

        let harmlessLabel = UILabel()
        harmlessLabel.translatesAutoresizingMaskIntoConstraints = false
        harmlessLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        harmlessLabel.textColor = .appHarmlessGreen
        harmlessLabel.text = L10n.string("paywall.preview.harmless")
        harmlessLabel.numberOfLines = 1

        let statusRow = UIStackView(arrangedSubviews: [checkView, harmlessLabel])
        statusRow.translatesAutoresizingMaskIntoConstraints = false
        statusRow.axis = .horizontal
        statusRow.alignment = .center
        statusRow.spacing = 4

        let textStack = UIStackView(arrangedSubviews: [nameLabel, familyLabel, statusRow])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 4

        addSubview(thumbnail)
        addSubview(textStack)

        let thumbSide: CGFloat = 66 // 90 − 12 − 12

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 90),

            thumbnail.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            thumbnail.centerYAnchor.constraint(equalTo: centerYAnchor),
            thumbnail.widthAnchor.constraint(equalToConstant: thumbSide),
            thumbnail.heightAnchor.constraint(equalToConstant: thumbSide),

            checkView.widthAnchor.constraint(equalToConstant: 16),
            checkView.heightAnchor.constraint(equalToConstant: 16),

            textStack.leadingAnchor.constraint(equalTo: thumbnail.trailingAnchor, constant: 7),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopPulseAnimation()
        } else if alpha > 0.5 {
            startPulseAnimationIfVisible()
        }
    }

    func resetPresentation() {
        stopPulseAnimation()
        alpha = 0
        transform = CGAffineTransform(scaleX: 0.985, y: 0.985)
    }

    func animateInIfNeeded() {
        guard alpha < 0.01 else { return }
        transform = CGAffineTransform(scaleX: 0.985, y: 0.985)
        UIView.animate(
            withDuration: 0.85,
            delay: 0,
            usingSpringWithDamping: 0.94,
            initialSpringVelocity: 0.08,
            options: [.curveEaseInOut, .allowUserInteraction]
        ) {
            self.alpha = 1
            self.transform = .identity
        } completion: { finished in
            guard finished else { return }
            self.startPulseAnimationIfVisible()
        }
    }

    @objc
    private func handleAppDidBecomeActive() {
        guard alpha > 0.5 else { return }
        stopPulseAnimation()
        startPulseAnimationIfVisible()
    }

    private func startPulseAnimationIfVisible() {
        guard alpha > 0.5, window != nil, bounds.width > 1 else { return }
        guard layer.animation(forKey: Self.pulseLayerKey) == nil else { return }

        let anim = CABasicAnimation(keyPath: "transform.scale")
        anim.fromValue = 1.0
        anim.toValue = 1.014
        anim.duration = 1.35
        anim.autoreverses = true
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        anim.isRemovedOnCompletion = false
        layer.add(anim, forKey: Self.pulseLayerKey)
    }

    private func stopPulseAnimation() {
        layer.removeAnimation(forKey: Self.pulseLayerKey)
        layer.transform = CATransform3DIdentity
    }
}
