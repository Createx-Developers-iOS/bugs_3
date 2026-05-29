//
//  ProfileViewController.swift
//  Bugs
//

import UIKit

/// Профиль: кастомный навбар как на главной, сегмент «Коллекция / Достижения», список насекомых в коллекции.
final class ProfileViewController: UIViewController {

    /// Пустой массив — показывается заглушка коллекции. Для превью списка временно добавьте элементы.
    private var collectionRows: [CategoryInsects.InsectCellViewModel] = []

    private struct ProfileAchievementGridItem {
        let title: String
        let imageURL: URL?
        let isCompleted: Bool
        let currentCount: Int
        let maxCount: Int
    }

    private var achievementRows: [ProfileAchievementGridItem] = []

    private let collectionEmptyStateView: ListSearchEmptyStateView = {
        let v = ListSearchEmptyStateView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()

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

    private lazy var segmentControl = ProfileSegmentedControl(
        leftTitle: L10n.string("profile.segment.collection"),
        rightTitle: L10n.string("profile.segment.achievements")
    )

    private lazy var listLayout: UICollectionViewFlowLayout = {
        let l = UICollectionViewFlowLayout()
        l.scrollDirection = .vertical
        l.minimumLineSpacing = 12
        l.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        return l
    }()

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: listLayout)
        cv.backgroundColor = .clear
        cv.alwaysBounceVertical = true
        cv.dataSource = self
        cv.delegate = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.contentInsetAdjustmentBehavior = .always
        cv.register(CategoryInsectsCell.self, forCellWithReuseIdentifier: CategoryInsectsCell.reuseIdentifier)
        return cv
    }()

    private lazy var achievementsGridLayout: UICollectionViewFlowLayout = {
        let l = UICollectionViewFlowLayout()
        l.scrollDirection = .vertical
        l.minimumLineSpacing = 16
        l.minimumInteritemSpacing = 12
        l.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        return l
    }()

    private lazy var achievementsCollectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: achievementsGridLayout)
        cv.backgroundColor = .clear
        cv.alwaysBounceVertical = true
        cv.dataSource = self
        cv.delegate = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.contentInsetAdjustmentBehavior = .always
        cv.register(HomeCategoryCell.self, forCellWithReuseIdentifier: HomeCategoryCell.reuseIdentifier)
        cv.isHidden = true
        return cv
    }()

    private let achievementsPlaceholder: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 16, weight: .regular)
        l.textColor = .black
        l.textAlignment = .center
        l.numberOfLines = 0
        l.isHidden = true
        return l
    }()

    private var lastCollectionWidthForLayout: CGFloat = 0

    private var collectionFetchTask: Task<Void, Never>?
    private var achievementsFetchTask: Task<Void, Never>?

    private let collectionLoadingIndicator: UIActivityIndicatorView = {
        let v = UIActivityIndicatorView(style: .large)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.hidesWhenStopped = true
        v.color = .appTextSecondary
        return v
    }()

    private var settingsButtonTrailingToPremiumConstraint: NSLayoutConstraint!
    private var settingsButtonTrailingToNavConstraint: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .appBackground
        titleLabel.text = L10n.string("profile.title")
        achievementsPlaceholder.text = L10n.string("profile.achievements.placeholder")
        collectionEmptyStateView.configure(
            title: L10n.string("profile.collection.empty.title"),
            subtitle: L10n.string("profile.collection.empty.subtitle"),
            imageAssetName: "profile_collection_empty",
            imageSide: 120
        )

        segmentControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        premiumButton.addTarget(self, action: #selector(premiumTapped), for: .touchUpInside)

        buildHierarchy()
        layoutConstraints()
        applyCollectionTabContentVisibility()
        updatePremiumNavBarChrome()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applySubscriptionStatusForAppearance()
        updatePremiumNavBarChrome()
        segmentControl.refreshSelectionShadows()
        navigationController?.setNavigationBarHidden(true, animated: animated)
        fetchCollectionFromAPI()
        if segmentControl.selectedIndex == 1 {
            fetchAchievementsFromAPI()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || isBeingDismissed { return }
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        segmentControl.refreshSelectionShadows()
        let w = collectionView.bounds.width
        guard w > 1 else { return }
        if abs(w - lastCollectionWidthForLayout) > 0.5 {
            lastCollectionWidthForLayout = w
            collectionView.collectionViewLayout.invalidateLayout()
            achievementsCollectionView.collectionViewLayout.invalidateLayout()
        }
    }

    private func fetchCollectionFromAPI() {
        guard segmentControl.selectedIndex == 0 else { return }
        collectionFetchTask?.cancel()

        collectionLoadingIndicator.startAnimating()
        let hasRows = !collectionRows.isEmpty
        if hasRows {
            collectionView.isUserInteractionEnabled = false
            view.bringSubviewToFront(collectionLoadingIndicator)
        } else {
            collectionView.isHidden = true
            collectionEmptyStateView.isHidden = true
        }

        collectionFetchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let data = try await CollectAPIClient.shared.get(path: "collection/")
                try Task.checkCancellation()
                let parsed = try CollectCollectionListParser.profileRows(from: data)
                try Task.checkCancellation()
                let rows: [CategoryInsects.InsectCellViewModel] = parsed.map { item in
                    CategoryInsects.InsectCellViewModel(
                        insectId: item.insectReference,
                        title: item.title,
                        subtitle: item.subtitle,
                        imageAssetName: "home_popular_insect",
                        imageURL: item.coverImageURL
                    )
                }
                await MainActor.run {
                    self.collectionLoadingIndicator.stopAnimating()
                    self.collectionView.isUserInteractionEnabled = true
                    self.collectionRows = rows
                    self.applyCollectionTabContentVisibility()
                    self.collectionView.reloadData()
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.collectionLoadingIndicator.stopAnimating()
                    self.collectionView.isUserInteractionEnabled = true
                    self.applyCollectionTabContentVisibility()
                }
            } catch {
                await MainActor.run {
                    self.collectionLoadingIndicator.stopAnimating()
                    self.collectionView.isUserInteractionEnabled = true
                    self.applyCollectionTabContentVisibility()
                    self.collectionView.reloadData()
                    // If user already switched to Achievements, do not surface Collection loading errors.
                    if self.segmentControl.selectedIndex == 0 {
                        UserFacingRequestErrorAlert.presentTryAgainLater(from: self)
                    }
                }
            }
        }
    }

    private func fetchAchievementsFromAPI() {
        guard segmentControl.selectedIndex == 1 else { return }
        achievementsFetchTask?.cancel()

        collectionLoadingIndicator.startAnimating()
        view.bringSubviewToFront(collectionLoadingIndicator)
        achievementsPlaceholder.isHidden = true
        achievementsCollectionView.isHidden = true
        applyCollectionTabContentVisibility()

        achievementsFetchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let data = try await CollectAPIClient.shared.get(path: "classification/achievements/")
                try Task.checkCancellation()
                Self.logAchievementsResponseToConsole(data)
                let dtos = try CollectAchievementsParser.results(from: data)
                try Task.checkCancellation()
                let rows = Self.sortedAchievementGridItems(from: dtos)
                await MainActor.run {
                    self.collectionLoadingIndicator.stopAnimating()
                    self.achievementRows = rows
                    self.applyCollectionTabContentVisibility()
                    self.achievementsCollectionView.reloadData()
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.collectionLoadingIndicator.stopAnimating()
                    self.applyCollectionTabContentVisibility()
                }
            } catch {
                print("[Profile achievements GET classification/achievements/] error: \(error)")
                await MainActor.run {
                    self.collectionLoadingIndicator.stopAnimating()
                    self.achievementRows = []
                    self.applyCollectionTabContentVisibility()
                    // If user already switched to Collection, do not surface Achievements loading errors.
                    if self.segmentControl.selectedIndex == 1 {
                        UserFacingRequestErrorAlert.presentTryAgainLater(from: self)
                    }
                }
            }
        }
    }

    /// Сначала выполненные (`current_count >= max_count`), затем по имени. Иконка всегда с цветного `image`; ч/б — в `HomeCategoryCell` через фильтр.
    private static func sortedAchievementGridItems(from dtos: [CollectAchievementItemDTO]) -> [ProfileAchievementGridItem] {
        let sorted = dtos.sorted { a, b in
            let ac = a.currentCount >= a.maxCount
            let bc = b.currentCount >= b.maxCount
            if ac != bc { return ac && !bc }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        return sorted.map { dto in
            ProfileAchievementGridItem(
                title: dto.name,
                imageURL: URL(string: dto.image),
                isCompleted: dto.currentCount >= dto.maxCount,
                currentCount: dto.currentCount,
                maxCount: dto.maxCount
            )
        }
    }

    private static func logAchievementsResponseToConsole(_ data: Data) {
        let tag = "[Profile achievements] GET classification/achievements/ response:"
        if let obj = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys, .prettyPrinted]),
           let s = String(data: pretty, encoding: .utf8)
        {
            print("\(tag)\n\(s)")
        } else if let s = String(data: data, encoding: .utf8) {
            print("\(tag)\n\(s)")
        } else {
            print("\(tag) <\(data.count) bytes, not UTF-8>")
        }
    }

    private func presentAchievementDetail(for item: ProfileAchievementGridItem) {
        let vm = AchievementDetailViewModel(
            title: item.title,
            categoryName: item.title,
            imageURL: item.imageURL,
            currentCount: item.currentCount,
            maxCount: item.maxCount,
            isCompleted: item.isCompleted
        )
        let sheet = AchievementDetailViewController(viewModel: vm)
        present(sheet, animated: true)
    }

    private func buildHierarchy() {
        view.addSubview(navBarContainer)
        navBarContainer.addSubview(titleLabel)
        navBarContainer.addSubview(settingsButton)
        navBarContainer.addSubview(premiumButton)

        view.addSubview(segmentControl)
        view.addSubview(collectionView)
        view.addSubview(achievementsCollectionView)
        view.addSubview(collectionEmptyStateView)
        view.addSubview(collectionLoadingIndicator)
        view.addSubview(achievementsPlaceholder)
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

            segmentControl.topAnchor.constraint(equalTo: navBarContainer.bottomAnchor, constant: 16),
            segmentControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            segmentControl.heightAnchor.constraint(equalToConstant: 52),

            collectionView.topAnchor.constraint(equalTo: segmentControl.bottomAnchor, constant: 12),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: safe.bottomAnchor),

            achievementsCollectionView.topAnchor.constraint(equalTo: segmentControl.bottomAnchor, constant: 12),
            achievementsCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            achievementsCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            achievementsCollectionView.bottomAnchor.constraint(equalTo: safe.bottomAnchor),

            achievementsPlaceholder.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            achievementsPlaceholder.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            achievementsPlaceholder.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            achievementsPlaceholder.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),

            collectionEmptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            collectionEmptyStateView.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor),
            collectionEmptyStateView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            collectionEmptyStateView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),

            collectionLoadingIndicator.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            collectionLoadingIndicator.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor),
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

    @objc
    private func settingsTapped() {
        navigationController?.pushViewController(SettingsViewController(), animated: true)
    }

    @objc
    private func premiumTapped() {
        presentPaywallFullScreen()
    }

    private func updatePremiumNavBarChrome() {
        let active = SubscriptionAccess.shared.isPremiumActive
        premiumButton.isHidden = active
        settingsButtonTrailingToPremiumConstraint?.isActive = !active
        settingsButtonTrailingToNavConstraint?.isActive = active
    }

    @objc
    private func segmentChanged() {
        if segmentControl.selectedIndex != 0 {
            collectionFetchTask?.cancel()
            collectionLoadingIndicator.stopAnimating()
            collectionView.isUserInteractionEnabled = true
            if segmentControl.selectedIndex == 1 {
                fetchAchievementsFromAPI()
            }
        } else {
            achievementsFetchTask?.cancel()
            fetchCollectionFromAPI()
        }
        applyCollectionTabContentVisibility()
    }

    private func applyCollectionTabContentVisibility() {
        let onCollection = segmentControl.selectedIndex == 0
        guard onCollection else {
            collectionView.isHidden = true
            collectionEmptyStateView.isHidden = true
            let loadingAchievements = collectionLoadingIndicator.isAnimating
            let hasAchievements = !achievementRows.isEmpty
            achievementsPlaceholder.isHidden = hasAchievements || loadingAchievements
            achievementsCollectionView.isHidden = !hasAchievements
            return
        }
        achievementsPlaceholder.isHidden = true
        achievementsCollectionView.isHidden = true
        if collectionLoadingIndicator.isAnimating {
            if collectionRows.isEmpty {
                collectionView.isHidden = true
                collectionEmptyStateView.isHidden = true
            } else {
                collectionView.isHidden = false
                collectionEmptyStateView.isHidden = true
            }
            return
        }
        let empty = collectionRows.isEmpty
        collectionView.isHidden = empty
        collectionEmptyStateView.isHidden = !empty
        if !empty {
            collectionView.reloadData()
        }
    }
}

extension ProfileViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView === achievementsCollectionView {
            return achievementRows.count
        }
        return collectionRows.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView === achievementsCollectionView {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: HomeCategoryCell.reuseIdentifier,
                for: indexPath
            ) as? HomeCategoryCell else {
                return UICollectionViewCell()
            }
            let item = achievementRows[indexPath.item]
            cell.configureAchievement(title: item.title, imageURL: item.imageURL, isCompleted: item.isCompleted)
            return cell
        }
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: CategoryInsectsCell.reuseIdentifier,
            for: indexPath
        ) as? CategoryInsectsCell else {
            return UICollectionViewCell()
        }
        cell.configure(with: collectionRows[indexPath.item])
        return cell
    }
}

extension ProfileViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        if collectionView === achievementsCollectionView {
            let sectionInset: CGFloat = 32
            let interItem: CGFloat = 12
            let columns: CGFloat = 3
            let contentW = collectionView.bounds.width
            let totalInter = interItem * (columns - 1)
            let w = floor((contentW - sectionInset - totalInter) / max(columns, 1))
            let rowHeight: CGFloat = 82
            return CGSize(width: max(0, w), height: rowHeight)
        }
        let horizontalInset: CGFloat = 32
        let w = max(0, collectionView.bounds.width - horizontalInset)
        return CGSize(width: w, height: 104)
    }
}

extension ProfileViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        if collectionView === achievementsCollectionView {
            presentAchievementDetail(for: achievementRows[indexPath.item])
            return
        }
        let row = collectionRows[indexPath.item]
        let detail = InsectDetailConfigurator.assemble(
            heroImageAssetName: row.imageAssetName,
            heroImageURL: row.imageURL,
            insectId: row.insectId,
            isInCollection: true
        )
        navigationController?.pushViewController(detail, animated: true)
    }
}
