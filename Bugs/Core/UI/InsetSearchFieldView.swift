//
//  InsetSearchFieldView.swift
//  Bugs
//

import UIKit

final class InsetSearchFieldView: UIView {

    private let iconView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "home_search_icon"))
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    let textField: UITextField = {
        let t = UITextField()
        t.borderStyle = .none
        t.font = .preferredFont(forTextStyle: .body)
        t.textColor = .appTextPrimary
        t.returnKeyType = .search
        t.clearButtonMode = .whileEditing
        t.translatesAutoresizingMaskIntoConstraints = false
        return t
    }()

    var onContainerTapWhenTextInputDisabled: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        layer.cornerRadius = 22
        clipsToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 3)
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(textField)
        textField.inputAccessoryView = makeKeyboardToolbar()

        let tap = UITapGestureRecognizer(target: self, action: #selector(containerTapped))
        addGestureRecognizer(tap)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 44),
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            textField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
    }

    func setTextInputEnabled(_ enabled: Bool) {
        textField.isUserInteractionEnabled = enabled
    }

    func setAttributedPlaceholder(_ attributed: NSAttributedString) {
        textField.attributedPlaceholder = attributed
    }

    private func makeKeyboardToolbar() -> UIToolbar {
        let toolbar = UIToolbar()
        let done = UIBarButtonItem(
            title: L10n.string("common.done"),
            style: .plain,
            target: self,
            action: #selector(doneKeyboardTapped)
        )
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            done
        ]
        toolbar.sizeToFit()
        return toolbar
    }

    @objc
    private func doneKeyboardTapped() {
        textField.resignFirstResponder()
    }

    @objc
    private func containerTapped() {
        if textField.isUserInteractionEnabled {
            textField.becomeFirstResponder()
        } else {
            onContainerTapWhenTextInputDisabled?()
        }
    }
}
