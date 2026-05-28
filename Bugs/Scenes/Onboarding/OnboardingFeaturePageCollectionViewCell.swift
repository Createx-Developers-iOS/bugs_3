//
//  OnboardingFeaturePageCollectionViewCell.swift
//  Bugs
//

import Lottie
import UIKit

final class OnboardingFeaturePageCollectionViewCell: UICollectionViewCell {

    static let reuseIdentifier = "OnboardingFeaturePageCollectionViewCell"

    enum BackgroundKind {
        case lottie(name: String)
        case customPreviewImage(assetName: String)
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

    override init(frame: CGRect) {
        super.init(frame: frame)
        semanticContentAttribute = .forceLeftToRight
        contentView.semanticContentAttribute = .forceLeftToRight
        contentView.backgroundColor = .appBackground

        contentView.addSubview(animationView)
        contentView.addSubview(imageView)

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
            imageView.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 70),
            imageView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -220),
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        animationView.stop()
        animationView.animation = nil
        imageView.image = nil
        imageView.isHidden = true
        animationView.isHidden = false
    }

    func configure(background: BackgroundKind) {
        switch background {
        case let .lottie(name):
            imageView.isHidden = true
            animationView.isHidden = false
            animationView.animation = LottieAnimation.named(name, bundle: .main)
            animationView.play()
        case let .customPreviewImage(assetName):
            animationView.stop()
            animationView.animation = nil
            animationView.isHidden = true
            imageView.isHidden = false
            imageView.image = UIImage(named: assetName)
        }
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
