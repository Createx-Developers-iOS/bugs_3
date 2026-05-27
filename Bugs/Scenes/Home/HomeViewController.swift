//
//  HomeViewController.swift
//  Bugs
//

import UIKit

protocol HomeDisplayLogic: AnyObject {
    func displayLoad(viewModel: Home.Load.ViewModel)
    func displayGenericRequestError()
}

final class HomeViewController: UIViewController, HomeDisplayLogic {

    var interactor: HomeBusinessLogic?

    private var categories: [Home.CategoryCellViewModel] = []
    private var popularInsects: [Home.PopularInsectCellViewModel] = []
    private var articles: [Home.ArticleCellViewModel] = []

    private let navBarContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 24, weight: .bold)
        l.textColor = .appTextPrimary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let settingsButton: UIButton = {
        let b = UIButton(type: .custom)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setImage(UIImage(named: "home_nav_settings"), for: .normal)
        b.imageView?.contentMode = .scaleAspectFit
        return b
    }()

    private let premiumButton: UIButton = {
        let b = UIButton(type: .custom)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setImage(UIImage(named: "home_nav_premium"), for: .normal)
        b.imageView?.contentMode = .scaleAspectFit
        return b
    }()

    private let contentLoadingOverlay = ContentLoadingOverlayView()

    private let scrollView: UIScrollView = {
        let s = UIScrollView()
        s.alwaysBounceVertical = true
        s.showsVerticalScrollIndicator = false
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let scrollContentView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let insetSearchField = InsetSearchFieldView()

    private lazy var collectionLayout: UICollectionViewFlowLayout = {
        let l = UICollectionViewFlowLayout()
        l.scrollDirection = .horizontal
        l.itemSize = CGSize(width: 100, height: 77)
        l.minimumLineSpacing = 4
        l.minimumInteritemSpacing = 4
        l.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        return l
    }()

    private lazy var categoriesCollectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: collectionLayout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.dataSource = self
        cv.delegate = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(HomeCategoryCell.self, forCellWithReuseIdentifier: HomeCategoryCell.reuseIdentifier)
        return cv
    }()

    private let aiBannerContainer: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 28
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let aiBannerImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "home_ai_banner_background"))
        iv.contentMode = .scaleAspectFill
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let aiBannerTitleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .semibold)
        l.textColor = .appTextPrimary
        l.numberOfLines = 2
        l.lineBreakMode = .byWordWrapping
        l.textAlignment = .natural
        l.translatesAutoresizingMaskIntoConstraints = false
        l.setContentCompressionResistancePriority(.required, for: .vertical)
        return l
    }()

    private let aiAskButton: UIButton = {
        let b = UIButton(type: .custom)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let popularSectionContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let popularSectionTitleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .semibold)
        l.textColor = .appSectionTitle
        l.numberOfLines = 1
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var popularCollectionLayout: UICollectionViewFlowLayout = {
        let l = UICollectionViewFlowLayout()
        l.scrollDirection = .horizontal
        l.itemSize = CGSize(width: 125, height: 150)
        l.minimumLineSpacing = 12
        l.minimumInteritemSpacing = 12
        l.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        return l
    }()

    private lazy var popularCollectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: popularCollectionLayout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.dataSource = self
        cv.delegate = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(HomePopularInsectCell.self, forCellWithReuseIdentifier: HomePopularInsectCell.reuseIdentifier)
        return cv
    }()

    private let articlesSectionContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let articlesSectionTitleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .semibold)
        l.textColor = .appSectionTitle
        l.numberOfLines = 1
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var articlesCollectionLayout: UICollectionViewFlowLayout = {
        let l = UICollectionViewFlowLayout()
        l.scrollDirection = .horizontal
        l.itemSize = CGSize(width: 300, height: 139)
        l.minimumLineSpacing = 12
        l.minimumInteritemSpacing = 12
        l.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        return l
    }()

    private lazy var articlesCollectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: articlesCollectionLayout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.dataSource = self
        cv.delegate = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(HomeArticleCell.self, forCellWithReuseIdentifier: HomeArticleCell.reuseIdentifier)
        return cv
    }()

    private var settingsButtonTrailingToPremiumConstraint: NSLayoutConstraint!
    private var settingsButtonTrailingToNavConstraint: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .appBackground
        configureAskButtonAppearance()
        aiAskButton.addTarget(self, action: #selector(aiAskTapped), for: .touchUpInside)
        let aiBannerTap = UITapGestureRecognizer(target: self, action: #selector(aiAskTapped))
        aiBannerTap.delegate = self
        aiBannerTap.cancelsTouchesInView = false
        aiBannerContainer.addGestureRecognizer(aiBannerTap)
        buildHierarchy()
        layoutConstraints()
        scrollView.isHidden = true
        contentLoadingOverlay.setActive(true)
        configureHomeSearchField()
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        premiumButton.addTarget(self, action: #selector(premiumTapped), for: .touchUpInside)
        interactor?.load(request: Home.Load.Request())
        updatePremiumNavBarChrome()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applySubscriptionStatusForAppearance()
        updatePremiumNavBarChrome()
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || isBeingDismissed { return }
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let w = aiBannerTitleLabel.bounds.width
        if w > 0, abs(w - aiBannerTitleLabel.preferredMaxLayoutWidth) > 0.5 {
            aiBannerTitleLabel.preferredMaxLayoutWidth = w
        }
    }

    private func configureHomeSearchField() {
        insetSearchField.setTextInputEnabled(false)
        insetSearchField.onContainerTapWhenTextInputDisabled = { [weak self] in
            guard let self else { return }
            self.navigationController?.pushViewController(LibraryConfigurator.assemble(), animated: true)
        }
    }

    @objc
    private func settingsTapped() {
        navigationController?.pushViewController(SettingsViewController(), animated: true)
    }

    @objc
    private func premiumTapped() {
        presentPaywallFullScreen()
    }

    @objc
    private func aiAskTapped() {
        topPresenterForModal.presentAIConsultantChatFullScreen()
    }

    private func updatePremiumNavBarChrome() {
        let active = SubscriptionAccess.shared.isPremiumActive
        premiumButton.isHidden = active
        settingsButtonTrailingToPremiumConstraint?.isActive = !active
        settingsButtonTrailingToNavConstraint?.isActive = active
    }

    private func configureAskButtonAppearance() {
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = .white
        config.background.backgroundColor = .appTextPrimary
        config.background.cornerRadius = 16
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
            return out
        }
        aiAskButton.configuration = config
    }

    private func buildHierarchy() {
        view.addSubview(navBarContainer)
        navBarContainer.addSubview(titleLabel)
        navBarContainer.addSubview(settingsButton)
        navBarContainer.addSubview(premiumButton)

        view.addSubview(scrollView)
        view.addSubview(contentLoadingOverlay)
        scrollView.addSubview(scrollContentView)

        scrollContentView.addSubview(insetSearchField)

        scrollContentView.addSubview(categoriesCollectionView)
        scrollContentView.addSubview(aiBannerContainer)
        aiBannerContainer.addSubview(aiBannerImageView)
        aiBannerContainer.addSubview(aiBannerTitleLabel)
        aiBannerContainer.addSubview(aiAskButton)

        scrollContentView.addSubview(popularSectionContainer)
        popularSectionContainer.addSubview(popularSectionTitleLabel)
        popularSectionContainer.addSubview(popularCollectionView)

        scrollContentView.addSubview(articlesSectionContainer)
        articlesSectionContainer.addSubview(articlesSectionTitleLabel)
        articlesSectionContainer.addSubview(articlesCollectionView)
    }

    private func layoutConstraints() {
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            navBarContainer.topAnchor.constraint(equalTo: safe.topAnchor),
            navBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBarContainer.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.leadingAnchor.constraint(equalTo: navBarContainer.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: navBarContainer.centerYAnchor),

            premiumButton.trailingAnchor.constraint(equalTo: navBarContainer.trailingAnchor, constant: -16),
            premiumButton.centerYAnchor.constraint(equalTo: navBarContainer.centerYAnchor),
            premiumButton.widthAnchor.constraint(equalToConstant: 28),
            premiumButton.heightAnchor.constraint(equalToConstant: 28),

            settingsButton.centerYAnchor.constraint(equalTo: navBarContainer.centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 28),
            settingsButton.heightAnchor.constraint(equalToConstant: 28),

            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: settingsButton.leadingAnchor, constant: -8),

            scrollView.topAnchor.constraint(equalTo: navBarContainer.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: safe.bottomAnchor),

            contentLoadingOverlay.topAnchor.constraint(equalTo: navBarContainer.bottomAnchor),
            contentLoadingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentLoadingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentLoadingOverlay.bottomAnchor.constraint(equalTo: safe.bottomAnchor),

            scrollContentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            scrollContentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            scrollContentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            scrollContentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            scrollContentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            insetSearchField.topAnchor.constraint(equalTo: scrollContentView.topAnchor, constant: 16),
            insetSearchField.leadingAnchor.constraint(equalTo: scrollContentView.leadingAnchor, constant: 16),
            insetSearchField.trailingAnchor.constraint(equalTo: scrollContentView.trailingAnchor, constant: -16),

            categoriesCollectionView.topAnchor.constraint(equalTo: insetSearchField.bottomAnchor, constant: 20),
            categoriesCollectionView.leadingAnchor.constraint(equalTo: scrollContentView.leadingAnchor),
            categoriesCollectionView.trailingAnchor.constraint(equalTo: scrollContentView.trailingAnchor),
            categoriesCollectionView.heightAnchor.constraint(equalToConstant: 77),

            aiBannerContainer.topAnchor.constraint(equalTo: categoriesCollectionView.bottomAnchor, constant: 20),
            aiBannerContainer.leadingAnchor.constraint(equalTo: scrollContentView.leadingAnchor, constant: 16),
            aiBannerContainer.trailingAnchor.constraint(equalTo: scrollContentView.trailingAnchor, constant: -16),

            popularSectionContainer.topAnchor.constraint(equalTo: aiBannerContainer.bottomAnchor, constant: 20),
            popularSectionContainer.leadingAnchor.constraint(equalTo: scrollContentView.leadingAnchor),
            popularSectionContainer.trailingAnchor.constraint(equalTo: scrollContentView.trailingAnchor),
            popularSectionContainer.heightAnchor.constraint(equalToConstant: 181),

            articlesSectionContainer.topAnchor.constraint(equalTo: popularSectionContainer.bottomAnchor, constant: 20),
            articlesSectionContainer.leadingAnchor.constraint(equalTo: scrollContentView.leadingAnchor),
            articlesSectionContainer.trailingAnchor.constraint(equalTo: scrollContentView.trailingAnchor),
            articlesSectionContainer.heightAnchor.constraint(equalToConstant: 170),
            articlesSectionContainer.bottomAnchor.constraint(equalTo: scrollContentView.bottomAnchor, constant: -24),

            popularSectionTitleLabel.topAnchor.constraint(equalTo: popularSectionContainer.topAnchor, constant: 6),
            popularSectionTitleLabel.leadingAnchor.constraint(equalTo: popularSectionContainer.leadingAnchor, constant: 16),
            popularSectionTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: popularSectionContainer.trailingAnchor, constant: -16),

            popularCollectionView.topAnchor.constraint(equalTo: popularSectionContainer.topAnchor, constant: 31),
            popularCollectionView.leadingAnchor.constraint(equalTo: popularSectionContainer.leadingAnchor),
            popularCollectionView.trailingAnchor.constraint(equalTo: popularSectionContainer.trailingAnchor),
            popularCollectionView.bottomAnchor.constraint(equalTo: popularSectionContainer.bottomAnchor),

            popularSectionTitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: popularCollectionView.topAnchor, constant: -4),

            articlesSectionTitleLabel.topAnchor.constraint(equalTo: articlesSectionContainer.topAnchor, constant: 6),
            articlesSectionTitleLabel.leadingAnchor.constraint(equalTo: articlesSectionContainer.leadingAnchor, constant: 16),
            articlesSectionTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: articlesSectionContainer.trailingAnchor, constant: -16),

            articlesCollectionView.topAnchor.constraint(equalTo: articlesSectionContainer.topAnchor, constant: 31),
            articlesCollectionView.leadingAnchor.constraint(equalTo: articlesSectionContainer.leadingAnchor),
            articlesCollectionView.trailingAnchor.constraint(equalTo: articlesSectionContainer.trailingAnchor),
            articlesCollectionView.bottomAnchor.constraint(equalTo: articlesSectionContainer.bottomAnchor),

            articlesSectionTitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: articlesCollectionView.topAnchor, constant: -4),

            aiBannerImageView.topAnchor.constraint(equalTo: aiBannerContainer.topAnchor),
            aiBannerImageView.leadingAnchor.constraint(equalTo: aiBannerContainer.leadingAnchor),
            aiBannerImageView.trailingAnchor.constraint(equalTo: aiBannerContainer.trailingAnchor),
            aiBannerImageView.bottomAnchor.constraint(equalTo: aiBannerContainer.bottomAnchor),

            aiBannerTitleLabel.topAnchor.constraint(equalTo: aiBannerContainer.topAnchor, constant: 20),
            aiBannerTitleLabel.leadingAnchor.constraint(equalTo: aiBannerContainer.leadingAnchor, constant: 20),
            aiBannerTitleLabel.widthAnchor.constraint(equalTo: aiBannerContainer.widthAnchor, multiplier: 0.7),

            aiAskButton.leadingAnchor.constraint(equalTo: aiBannerContainer.leadingAnchor, constant: 20),
            aiAskButton.bottomAnchor.constraint(equalTo: aiBannerContainer.bottomAnchor, constant: -20),
            aiAskButton.heightAnchor.constraint(equalToConstant: 50),
            aiAskButton.topAnchor.constraint(equalTo: aiBannerTitleLabel.bottomAnchor, constant: 12)
        ])

        settingsButtonTrailingToPremiumConstraint = settingsButton.trailingAnchor.constraint(
            equalTo: premiumButton.leadingAnchor,
            constant: -16
        )
        settingsButtonTrailingToNavConstraint = settingsButton.trailingAnchor.constraint(
            equalTo: navBarContainer.trailingAnchor,
            constant: -16
        )
        settingsButtonTrailingToPremiumConstraint.isActive = true
        settingsButtonTrailingToNavConstraint.isActive = false
    }

    func displayLoad(viewModel: Home.Load.ViewModel) {
        contentLoadingOverlay.setActive(false)
        scrollView.isHidden = false

        titleLabel.text = viewModel.title
        insetSearchField.setAttributedPlaceholder(
            NSAttributedString(
                string: viewModel.searchPlaceholder,
                attributes: [.foregroundColor: UIColor.placeholderText]
            )
        )
        aiBannerTitleLabel.text = viewModel.bannerTitle
        if var config = aiAskButton.configuration {
            config.title = viewModel.bannerButtonTitle
            aiAskButton.configuration = config
        }
        categories = viewModel.categories
        popularInsects = viewModel.popularInsects
        popularSectionTitleLabel.text = viewModel.popularSectionTitle
        articles = viewModel.articles
        articlesSectionTitleLabel.text = viewModel.articlesSectionTitle
        categoriesCollectionView.reloadData()
        popularCollectionView.reloadData()
        articlesCollectionView.reloadData()
    }

    func displayGenericRequestError() {
        UserFacingRequestErrorAlert.presentTryAgainLater(from: self)
    }
}

extension HomeViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView === articlesCollectionView {
            return articles.count
        }
        if collectionView === popularCollectionView {
            return popularInsects.count
        }
        return categories.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView === articlesCollectionView {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: HomeArticleCell.reuseIdentifier,
                for: indexPath
            ) as? HomeArticleCell else {
                return UICollectionViewCell()
            }
            cell.configure(with: articles[indexPath.item])
            return cell
        }
        if collectionView === popularCollectionView {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: HomePopularInsectCell.reuseIdentifier,
                for: indexPath
            ) as? HomePopularInsectCell else {
                return UICollectionViewCell()
            }
            cell.configure(with: popularInsects[indexPath.item])
            return cell
        }
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: HomeCategoryCell.reuseIdentifier,
            for: indexPath
        ) as? HomeCategoryCell else {
            return UICollectionViewCell()
        }
        cell.configure(with: categories[indexPath.item])
        return cell
    }
}

extension HomeViewController: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer.view === aiBannerContainer else { return true }
        let point = touch.location(in: aiBannerContainer)
        return !aiAskButton.frame.contains(point)
    }
}

extension HomeViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView === articlesCollectionView {
            collectionView.deselectItem(at: indexPath, animated: true)
            let row = articles[indexPath.item]
            let detail = ArticleDetailViewController(articleId: row.articleId, preview: row.detail)
            navigationController?.pushViewController(detail, animated: true)
            return
        }
        if collectionView === popularCollectionView {
            collectionView.deselectItem(at: indexPath, animated: true)
            let row = popularInsects[indexPath.item]
            let detail = InsectDetailConfigurator.assemble(
                heroImageAssetName: row.imageAssetName,
                heroImageURL: row.imageURL,
                insectId: row.insectId,
                isInCollection: false
            )
            navigationController?.pushViewController(detail, animated: true)
            return
        }
        guard collectionView === categoriesCollectionView else { return }
        collectionView.deselectItem(at: indexPath, animated: true)
        let key = categories[indexPath.item].categoryLocalizationKey
        let insectsList = CategoryInsectsConfigurator.assemble(categoryLocalizationKey: key)
        navigationController?.pushViewController(insectsList, animated: true)
    }
}
