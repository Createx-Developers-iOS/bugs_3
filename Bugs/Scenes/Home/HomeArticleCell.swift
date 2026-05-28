//
//  HomeArticleCell.swift
//  Bugs
//

import UIKit

final class HomeArticleCell: UICollectionViewCell {

    static let reuseIdentifier = "HomeArticleCell"

    private let cardView: UIView = {
        let v = UIView()
        v.backgroundColor = .white
        v.layer.cornerRadius = 28
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let coverImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 28
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
        contentView.addSubview(cardView)
        cardView.addSubview(coverImageView)
        cardView.addSubview(textStack)

        let imageSide: CGFloat = 115

        let textCenterY = textStack.centerYAnchor.constraint(equalTo: cardView.centerYAnchor)
        textCenterY.priority = .defaultHigh

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            coverImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            coverImageView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            coverImageView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),
            coverImageView.widthAnchor.constraint(equalToConstant: imageSide),
            coverImageView.heightAnchor.constraint(equalToConstant: imageSide),

            textStack.leadingAnchor.constraint(equalTo: coverImageView.trailingAnchor, constant: 16),
            textStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            textCenterY,
            textStack.topAnchor.constraint(greaterThanOrEqualTo: cardView.topAnchor, constant: 12),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -12),
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(with viewModel: Home.ArticleCellViewModel) {
        titleLabel.text = viewModel.title
        subtitleLabel.text = viewModel.subtitle
        RemoteImageLoader.load(into: coverImageView, url: viewModel.coverImageURL)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        RemoteImageLoader.cancelLoad(for: coverImageView)
        titleLabel.text = nil
        subtitleLabel.text = nil
        coverImageView.image = nil
    }
}
