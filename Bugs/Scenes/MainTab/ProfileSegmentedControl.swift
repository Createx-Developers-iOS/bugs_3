//
//  ProfileSegmentedControl.swift
//  Bugs
//

import UIKit

/// Два равных сегмента: белый фон, выбранный #3AA176, внутренние отступы 2 pt.
final class ProfileSegmentedControl: UIControl {

    var selectedIndex: Int = 0 {
        didSet {
            guard oldValue != selectedIndex else { return }
            updateVisuals()
            sendActions(for: .valueChanged)
        }
    }

    private let stack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.spacing = 2
        s.distribution = .fillEqually
        s.alignment = .fill
        s.isLayoutMarginsRelativeArrangement = true
        s.layoutMargins = UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let leftButton = UIButton(type: .custom)
    private let rightButton = UIButton(type: .custom)

    /// Фон выбранного сегмента (#3AA176).
    private static let selectedFill = UIColor(red: 58 / 255, green: 161 / 255, blue: 118 / 255, alpha: 1)

    init(leftTitle: String, rightTitle: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = false
        backgroundColor = .white
        layer.cornerRadius = 22
        layer.masksToBounds = true

        configureButton(leftButton, title: leftTitle)
        configureButton(rightButton, title: rightTitle)
        leftButton.addTarget(self, action: #selector(leftTapped), for: .touchUpInside)
        rightButton.addTarget(self, action: #selector(rightTapped), for: .touchUpInside)

        addSubview(stack)
        stack.addArrangedSubview(leftButton)
        stack.addArrangedSubview(rightButton)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        updateVisuals()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func configureButton(_ b: UIButton, title: String) {
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        b.titleLabel?.adjustsFontForContentSizeCategory = true
        b.titleLabel?.lineBreakMode = .byTruncatingTail
        b.layer.cornerRadius = 20
        b.clipsToBounds = false
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
        let green = Self.selectedFill
        leftButton.backgroundColor = selectedIndex == 0 ? green : .white
        rightButton.backgroundColor = selectedIndex == 1 ? green : .white
        leftButton.setTitleColor(selectedIndex == 0 ? .white : .black, for: .normal)
        rightButton.setTitleColor(selectedIndex == 1 ? .white : .black, for: .normal)
        applySelectionShadow(for: leftButton, isSelected: selectedIndex == 0)
        applySelectionShadow(for: rightButton, isSelected: selectedIndex == 1)
    }

    private func applySelectionShadow(for button: UIButton, isSelected: Bool) {
        guard isSelected else {
            button.layer.shadowOpacity = 0
            return
        }
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.12
        button.layer.shadowRadius = 8
        button.layer.shadowOffset = CGSize(width: 0, height: 3)
        button.layer.shadowPath = UIBezierPath(
            roundedRect: button.bounds,
            cornerRadius: button.layer.cornerRadius
        ).cgPath
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applySelectionShadow(for: leftButton, isSelected: selectedIndex == 0)
        applySelectionShadow(for: rightButton, isSelected: selectedIndex == 1)
    }
}
