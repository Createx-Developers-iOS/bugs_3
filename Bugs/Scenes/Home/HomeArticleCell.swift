//
//  HomeArticleCell.swift
//  Bugs
//

import UIKit

final class HomeArticleCell: UICollectionViewCell {

    static let reuseIdentifier = "HomeArticleCell"

    /// Отступы внутри ячейки, чтобы тень помещалась в bounds и не резалась UICollectionView.
    static let shadowPadding = UIEdgeInsets(top: 4, left: 8, bottom: 18, right: 8)
    static let cardContentHeight: CGFloat = 139
    static var layoutItemSize: CGSize {
        CGSize(
            width: 300 + shadowPadding.left + shadowPadding.right,
            height: cardContentHeight + shadowPadding.top + shadowPadding.bottom
        )
    }

    private enum Style {
        static let cardCornerRadius: CGFloat = 28
    }

    /// Белая карточка с тенью; `clipsToBounds = false`, иначе тень не рисуется.
    private let shadowCard: UIView = {
        let v = UIView()
        v.backgroundColor = .white
        v.layer.cornerRadius = Style.cardCornerRadius
        v.clipsToBounds = false
        v.layer.masksToBounds = false
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let contentClipView: UIView = {
        let v = UIView()
        v.backgroundColor = .white
        v.layer.cornerRadius = Style.cardCornerRadius
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let coverImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = Style.cardCornerRadius
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .semibold)
        l.textColor = .appTextPrimary
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12, weight: .regular)
        l.textColor = .appTextSecondary
        l.numberOfLines = 2
        l.lineBreakMode = .byTruncatingTail
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var textStack: UIStackView = {
        let s = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        s.axis = .vertical
        s.spacing = 11
        s.alignment = .fill
        s.distribution = .fill
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
        contentView.clipsToBounds = false
        layer.masksToBounds = false
        contentView.backgroundColor = .clear
        backgroundColor = .clear

        contentView.addSubview(shadowCard)
        shadowCard.addSubview(contentClipView)
        contentClipView.addSubview(coverImageView)
        contentClipView.addSubview(textStack)

        let pad = Self.shadowPadding
        let imageSide: CGFloat = 115

        let textCenterY = textStack.centerYAnchor.constraint(equalTo: contentClipView.centerYAnchor)
        textCenterY.priority = .defaultHigh

        NSLayoutConstraint.activate([
            shadowCard.topAnchor.constraint(equalTo: contentView.topAnchor, constant: pad.top),
            shadowCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad.left),
            shadowCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad.right),
            shadowCard.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -pad.bottom),
            shadowCard.heightAnchor.constraint(equalToConstant: Self.cardContentHeight),

            contentClipView.topAnchor.constraint(equalTo: shadowCard.topAnchor),
            contentClipView.leadingAnchor.constraint(equalTo: shadowCard.leadingAnchor),
            contentClipView.trailingAnchor.constraint(equalTo: shadowCard.trailingAnchor),
            contentClipView.bottomAnchor.constraint(equalTo: shadowCard.bottomAnchor),

            coverImageView.leadingAnchor.constraint(equalTo: contentClipView.leadingAnchor, constant: 12),
            coverImageView.topAnchor.constraint(equalTo: contentClipView.topAnchor, constant: 12),
            coverImageView.bottomAnchor.constraint(equalTo: contentClipView.bottomAnchor, constant: -12),
            coverImageView.widthAnchor.constraint(equalToConstant: imageSide),
            coverImageView.heightAnchor.constraint(equalToConstant: imageSide),

            textStack.leadingAnchor.constraint(equalTo: coverImageView.trailingAnchor, constant: 16),
            textStack.trailingAnchor.constraint(equalTo: contentClipView.trailingAnchor, constant: -16),
            textCenterY,
            textStack.topAnchor.constraint(greaterThanOrEqualTo: contentClipView.topAnchor, constant: 12),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: contentClipView.bottomAnchor, constant: -12),
        ])

    }

    required init?(coder: NSCoder) {
        nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { return }
        refreshShadow()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        refreshShadow()
    }

    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        layer.zPosition = CGFloat(layoutAttributes.indexPath.item + 1)
    }

    /// Пересчитать тень после layout (иначе `shadowPath` с нулевым bounds — тени нет).
    func refreshShadow() {
        let layer = shadowCard.layer
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.masksToBounds = false

        let bounds = shadowCard.bounds
        guard bounds.width > 1, bounds.height > 1 else {
            layer.shadowPath = nil
            return
        }
        layer.shadowPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: Style.cardCornerRadius
        ).cgPath
    }

    func configure(with viewModel: Home.ArticleCellViewModel) {
        titleLabel.text = viewModel.title
        subtitleLabel.text = viewModel.subtitle
        RemoteImageLoader.load(into: coverImageView, url: viewModel.coverImageURL)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        shadowCard.layer.shadowPath = nil
        RemoteImageLoader.cancelLoad(for: coverImageView)
        titleLabel.text = nil
        subtitleLabel.text = nil
        coverImageView.image = nil
    }
}
