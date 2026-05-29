//
//  ArticleDetailViewController.swift
//  Bugs
//

import UIKit

/// Экран статьи: при наличии `articleId` контент показывается только после `GET articles/insects/{id}/` (до этого — навбар и лоадер).
final class ArticleDetailViewController: UIViewController {

    private let articleId: String?
    private var displayedViewModel: Home.ArticleDetailViewModel

    private let scrollView: UIScrollView = {
        let s = UIScrollView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.alwaysBounceVertical = false
        s.bounces = false
        s.showsVerticalScrollIndicator = true
        s.contentInsetAdjustmentBehavior = .never
        return s
    }()

    private let contentStack: UIStackView = {
        let s = UIStackView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.axis = .vertical
        s.alignment = .fill
        s.spacing = 0
        return s
    }()

    private let contentLoadingOverlay = ContentLoadingOverlayView()

    private var articleFetchTask: Task<Void, Never>?
    private var navBarTitleText: String = ""
    private var hasVisibleNavBarChrome = true
    private lazy var transparentNavBarAppearance: UINavigationBarAppearance = {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.clear,
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
        ]
        return appearance
    }()

    /// - Parameters:
    ///   - articleId: Идентификатор для `GET articles/insects/{id}/`; если `nil`, остаётся превью со списка.
    ///   - preview: Данные из списка статей до ответа детального запроса.
    init(articleId: String?, preview: Home.ArticleDetailViewModel) {
        let trimmed = articleId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.articleId = trimmed.isEmpty ? nil : trimmed
        self.displayedViewModel = preview
        super.init(nibName: nil, bundle: nil)
    }

    /// Совместимость: только превью, без запроса деталки.
    convenience init(viewModel: Home.ArticleDetailViewModel) {
        self.init(articleId: nil, preview: viewModel)
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        articleFetchTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .appBackground
        overrideUserInterfaceStyle = .light
        navigationItem.largeTitleDisplayMode = .never
        configureNavigationBar()
        configureBackButton()

        view.addSubview(scrollView)
        scrollView.delegate = self
        scrollView.addSubview(contentStack)
        view.addSubview(contentLoadingOverlay)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            contentLoadingOverlay.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentLoadingOverlay.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentLoadingOverlay.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentLoadingOverlay.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
        ])

        view.bringSubviewToFront(contentLoadingOverlay)

        if let id = articleId {
            navigationItem.title = nil
            scrollView.isHidden = true
            contentLoadingOverlay.backgroundColor = .appBackground
            contentLoadingOverlay.setActive(true)
            articleFetchTask = Task { [weak self] in
                await self?.fetchFullArticle(id: id)
            }
        } else {
            scrollView.isHidden = false
            contentLoadingOverlay.backgroundColor = .clear
            contentLoadingOverlay.setActive(false)
            applyViewModel(displayedViewModel)
        }
    }

    private func applyViewModel(_ viewModel: Home.ArticleDetailViewModel) {
        navBarTitleText = viewModel.title
        updateNavigationTitleForCurrentOffset()

        for subview in contentStack.arrangedSubviews {
            contentStack.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        let heroHeight: CGFloat = 232
        let heroContainer = UIView()
        heroContainer.translatesAutoresizingMaskIntoConstraints = false
        heroContainer.clipsToBounds = true
        heroContainer.layer.cornerRadius = 32
        heroContainer.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        heroContainer.backgroundColor = .appCategoryCircle

        let heroImageView = UIImageView()
        heroImageView.translatesAutoresizingMaskIntoConstraints = false
        heroImageView.contentMode = .scaleAspectFill
        heroImageView.clipsToBounds = true
        RemoteImageLoader.load(into: heroImageView, url: viewModel.heroImageURL)
        heroContainer.addSubview(heroImageView)

        contentStack.addArrangedSubview(heroContainer)
        NSLayoutConstraint.activate([
            heroContainer.heightAnchor.constraint(equalToConstant: heroHeight),
            heroImageView.topAnchor.constraint(equalTo: heroContainer.topAnchor),
            heroImageView.leadingAnchor.constraint(equalTo: heroContainer.leadingAnchor),
            heroImageView.trailingAnchor.constraint(equalTo: heroContainer.trailingAnchor),
            heroImageView.bottomAnchor.constraint(equalTo: heroContainer.bottomAnchor),
        ])

        let textChrome = UIView()
        textChrome.translatesAutoresizingMaskIntoConstraints = false
        let innerStack = UIStackView()
        innerStack.translatesAutoresizingMaskIntoConstraints = false
        innerStack.axis = .vertical
        innerStack.spacing = 12
        innerStack.alignment = .fill
        textChrome.addSubview(innerStack)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 26, weight: .bold)
        titleLabel.textColor = .appTextPrimary
        titleLabel.numberOfLines = 0
        titleLabel.text = viewModel.title

        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .systemFont(ofSize: 16, weight: .regular)
        subtitleLabel.textColor = .appTextSecondary
        subtitleLabel.numberOfLines = 0
        subtitleLabel.text = viewModel.subtitle

        let trimmedSubtitle = viewModel.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        var titleStackRows: [UIView] = [titleLabel]
        if !trimmedSubtitle.isEmpty {
            titleStackRows.append(subtitleLabel)
        }
        let titleBlock = Self.hInsetWrap(
            arrangedSubviews: titleStackRows,
            axis: .vertical,
            spacing: 12,
            inset: 16
        )
        innerStack.addArrangedSubview(titleBlock)

        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
        innerStack.addArrangedSubview(spacer)

        for (index, block) in viewModel.blocks.enumerated() {
            if let sectionTitle = block.sectionTitle {
                let plaque = InsectSectionHeaderPlaqueView()
                plaque.setTitle(sectionTitle)
                innerStack.addArrangedSubview(Self.rowWithLeadingAlignedSubview(plaque))
            }
            let body = UILabel()
            body.translatesAutoresizingMaskIntoConstraints = false
            body.font = .systemFont(ofSize: 16, weight: .regular)
            body.textColor = .appDescriptionBody
            body.numberOfLines = 0
            body.text = block.body
            innerStack.addArrangedSubview(Self.hInsetWrap(single: body, inset: 16))

            if index < viewModel.blocks.count - 1 {
                let gap = UIView()
                gap.translatesAutoresizingMaskIntoConstraints = false
                gap.heightAnchor.constraint(equalToConstant: 20).isActive = true
                innerStack.addArrangedSubview(gap)
            }
        }

        contentStack.addArrangedSubview(textChrome)
        NSLayoutConstraint.activate([
            innerStack.topAnchor.constraint(equalTo: textChrome.topAnchor, constant: 20),
            innerStack.leadingAnchor.constraint(equalTo: textChrome.leadingAnchor),
            innerStack.trailingAnchor.constraint(equalTo: textChrome.trailingAnchor),
            innerStack.bottomAnchor.constraint(equalTo: textChrome.bottomAnchor, constant: -32),
        ])
    }

    private func fetchFullArticle(id: String) async {
        do {
            let data = try await CollectAPIClient.shared.get(path: "articles/insects/\(id)/")
            try Task.checkCancellation()
            let dict = try CollectHomeListPayload.singleJSONObject(from: data)
            try Task.checkCancellation()
            guard let item = CollectHomeDTOMapper.article(dict) else {
                await MainActor.run { [weak self] in self?.applyPreviewFallbackAfterFailedLoad() }
                return
            }
            let vm = Home.ArticleDetailViewModel(from: item)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.displayedViewModel = vm
                self.revealArticleContent()
                self.applyViewModel(vm)
            }
        } catch is CancellationError {
            await MainActor.run { [weak self] in self?.applyPreviewFallbackAfterFailedLoad() }
        } catch {
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.applyPreviewFallbackAfterFailedLoad()
                UserFacingRequestErrorAlert.presentTryAgainLater(from: self)
            }
        }
    }

    /// Показать скролл и контент после успешной загрузки.
    private func revealArticleContent() {
        contentLoadingOverlay.setActive(false)
        contentLoadingOverlay.backgroundColor = .clear
        scrollView.isHidden = false
    }

    /// Ошибка или невалидный JSON: убрать лоадер и показать превью со списка (если было).
    private func applyPreviewFallbackAfterFailedLoad() {
        contentLoadingOverlay.setActive(false)
        contentLoadingOverlay.backgroundColor = .clear
        scrollView.isHidden = false
        applyViewModel(displayedViewModel)
    }

    /// Строка на всю ширину стека: `subview` слева, ширина по контенту (как плашки на карточке насекомого).
    private static func rowWithLeadingAlignedSubview(_ subview: UIView) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.backgroundColor = .clear
        subview.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(subview)
        NSLayoutConstraint.activate([
            subview.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            subview.topAnchor.constraint(equalTo: row.topAnchor),
            subview.bottomAnchor.constraint(equalTo: row.bottomAnchor),
        ])
        return row
    }

    private static func hInsetWrap(single: UIView, inset: CGFloat) -> UIView {
        hInsetWrap(arrangedSubviews: [single], axis: .vertical, spacing: 0, inset: inset)
    }

    private static func hInsetWrap(
        arrangedSubviews: [UIView],
        axis: NSLayoutConstraint.Axis,
        spacing: CGFloat,
        inset: CGFloat
    ) -> UIView {
        let wrap = UIView()
        wrap.translatesAutoresizingMaskIntoConstraints = false
        let stack = UIStackView(arrangedSubviews: arrangedSubviews)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = axis
        stack.spacing = spacing
        stack.alignment = .fill
        wrap.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: inset),
            stack.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -inset),
            stack.topAnchor.constraint(equalTo: wrap.topAnchor),
            stack.bottomAnchor.constraint(equalTo: wrap.bottomAnchor),
        ])
        return wrap
    }

    private func configureNavigationBar() {
        guard let nav = navigationController?.navigationBar else { return }
        AppNavigationBarAppearance.apply(to: nav)
        applyNavBarChrome(visible: false)
    }

    private func configureBackButton() {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(named: "library_nav_back"), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 32),
            button.heightAnchor.constraint(equalToConstant: 32),
        ])
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: button)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applySubscriptionStatusForAppearance()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        restoreInteractivePopGestureIfNeeded()
    }

    @objc
    private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    private func updateNavigationTitleForCurrentOffset() {
        let showTitle = scrollView.contentOffset.y > 160
        applyNavBarChrome(visible: showTitle)
        navigationItem.title = showTitle ? navBarTitleText : nil
    }

    private func applyNavBarChrome(visible: Bool) {
        guard let nav = navigationController?.navigationBar else { return }
        guard hasVisibleNavBarChrome != visible else { return }
        hasVisibleNavBarChrome = visible
        if visible {
            AppNavigationBarAppearance.apply(to: nav)
        } else {
            nav.standardAppearance = transparentNavBarAppearance
            nav.scrollEdgeAppearance = transparentNavBarAppearance
            nav.compactAppearance = transparentNavBarAppearance
            nav.compactScrollEdgeAppearance = transparentNavBarAppearance
            nav.tintColor = .appTextPrimary
        }
    }
}

extension ArticleDetailViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateNavigationTitleForCurrentOffset()
    }
}
