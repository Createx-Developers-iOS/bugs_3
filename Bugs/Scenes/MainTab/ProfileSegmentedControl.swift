//
//  ProfileSegmentedControl.swift
//  Bugs
//

import UIKit

/// Два равных сегмента: белый фон, выбранный #3AA176 с тенью.
final class ProfileSegmentedControl: UIControl {

    var selectedIndex: Int = 0 {
        didSet {
            guard oldValue != selectedIndex else { return }
            updateVisuals()
            sendActions(for: .valueChanged)
        }
    }

    private let trackView: UIView = {
        let v = UIView()
        v.backgroundColor = .white
        v.layer.cornerRadius = 22
        v.clipsToBounds = false
        v.layer.masksToBounds = false
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let stack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = 2
        s.distribution = .fillEqually
        s.alignment = .fill
        s.isLayoutMarginsRelativeArrangement = true
        s.layoutMargins = UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)
        s.clipsToBounds = false
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let leftTab = SegmentTab()
    private let rightTab = SegmentTab()

    private static let selectedFill = UIColor(red: 58 / 255, green: 161 / 255, blue: 118 / 255, alpha: 1)

    init(leftTitle: String, rightTitle: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = false
        layer.masksToBounds = false
        isAccessibilityElement = false
        backgroundColor = .clear

        leftTab.button.setTitle(leftTitle, for: .normal)
        rightTab.button.setTitle(rightTitle, for: .normal)
        leftTab.button.addTarget(self, action: #selector(leftTapped), for: .touchUpInside)
        rightTab.button.addTarget(self, action: #selector(rightTapped), for: .touchUpInside)

        addSubview(trackView)
        trackView.addSubview(stack)
        stack.addArrangedSubview(leftTab)
        stack.addArrangedSubview(rightTab)

        NSLayoutConstraint.activate([
            trackView.topAnchor.constraint(equalTo: topAnchor),
            trackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            trackView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.topAnchor.constraint(equalTo: trackView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: trackView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trackView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: trackView.bottomAnchor),
        ])

        updateVisuals()
    }

    required init?(coder: NSCoder) {
        nil
    }

    @objc
    private func leftTapped() {
        selectedIndex = 0
    }

    @objc
    private func rightTapped() {
        selectedIndex = 1
    }

    private func updateVisuals() {
        let leftSelected = selectedIndex == 0
        leftTab.setSelected(leftSelected, fillColor: Self.selectedFill)
        rightTab.setSelected(!leftSelected, fillColor: Self.selectedFill)
        // Выбранный таб поверх соседа — иначе тень перекрывается непрозрачным фоном соседнего таба.
        leftTab.layer.zPosition = leftSelected ? 2 : 0
        rightTab.layer.zPosition = leftSelected ? 0 : 2
        if leftSelected {
            stack.bringSubviewToFront(leftTab)
        } else {
            stack.bringSubviewToFront(rightTab)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        refreshSelectionShadows()
    }

    /// Вызвать после layout — иначе у первого выбранного таба `shadowPath` с нулевым frame.
    func refreshSelectionShadows() {
        layoutIfNeeded()
        leftTab.refreshShadow()
        rightTab.refreshShadow()
    }
}

// MARK: - Segment tab

private final class SegmentTab: UIView {

    let selectionSurface: UIView = {
        let v = UIView()
        v.clipsToBounds = false
        v.layer.masksToBounds = false
        v.layer.cornerRadius = 20
        v.isHidden = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    let button: UIButton = {
        let b = UIButton(type: .custom)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        b.titleLabel?.adjustsFontForContentSizeCategory = true
        b.titleLabel?.lineBreakMode = .byTruncatingTail
        b.backgroundColor = .clear
        b.isOpaque = false
        b.layer.cornerRadius = 20
        return b
    }()

    private static let shadowInsets = UIEdgeInsets(top: 0, left: 0, bottom: 8, right: 0)

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
        layer.masksToBounds = false
        backgroundColor = .clear
        isOpaque = false

        addSubview(selectionSurface)
        addSubview(button)

        let inset = Self.shadowInsets
        NSLayoutConstraint.activate([
            selectionSurface.topAnchor.constraint(equalTo: topAnchor),
            selectionSurface.leadingAnchor.constraint(equalTo: leadingAnchor),
            selectionSurface.trailingAnchor.constraint(equalTo: trailingAnchor),
            selectionSurface.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset.bottom),

            button.topAnchor.constraint(equalTo: topAnchor),
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset.bottom),
        ])

        applyShadowStyle()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func setSelected(_ selected: Bool, fillColor: UIColor) {
        selectionSurface.isHidden = !selected
        selectionSurface.backgroundColor = fillColor
        button.backgroundColor = .clear
        button.setTitleColor(selected ? .white : .black, for: .normal)
        if selected {
            applyShadowStyle()
        } else {
            selectionSurface.layer.shadowOpacity = 0
            selectionSurface.layer.shadowPath = nil
        }
    }

    func refreshShadow() {
        guard !selectionSurface.isHidden else {
            selectionSurface.layer.shadowOpacity = 0
            selectionSurface.layer.shadowPath = nil
            return
        }
        applyShadowStyle()
        layoutIfNeeded()
        let bounds = selectionSurface.bounds
        guard bounds.width > 1, bounds.height > 1 else {
            selectionSurface.layer.shadowPath = nil
            return
        }
        selectionSurface.layer.shadowPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: selectionSurface.layer.cornerRadius
        ).cgPath
    }

    private func applyShadowStyle() {
        let layer = selectionSurface.layer
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.28
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 4)
    }
}
