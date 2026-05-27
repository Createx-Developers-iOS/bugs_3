//
//  OnboardingPaywallCollectionViewCell.swift
//  Bugs
//

import UIKit

/// Вторая страница онбординга — пейвол в ячейке; подписка через плавающую CTA, кнопка в пейволе скрыта.
final class OnboardingPaywallCollectionViewCell: UICollectionViewCell {

    static let reuseIdentifier = "OnboardingPaywallCollectionViewCell"

    private let paywallView = PaywallScreenView(embeddedInOnboarding: true)

    override init(frame: CGRect) {
        super.init(frame: frame)
        semanticContentAttribute = .forceLeftToRight
        contentView.semanticContentAttribute = .forceLeftToRight
        contentView.backgroundColor = .appBackground
        paywallView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(paywallView)
        NSLayoutConstraint.activate([
            paywallView.topAnchor.constraint(equalTo: contentView.topAnchor),
            paywallView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            paywallView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            paywallView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(
        onClose: @escaping () -> Void,
        onTerms: @escaping () -> Void,
        onPrivacy: @escaping () -> Void,
        onRestore: @escaping () -> Void
    ) {
        paywallView.onCloseTap = onClose
        paywallView.onTermsTap = onTerms
        paywallView.onPrivacyTap = onPrivacy
        paywallView.onRestoreTap = onRestore
    }
}
