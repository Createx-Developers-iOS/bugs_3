//
//  UIViewController+AIConsultantChatPresentation.swift
//  Bugs
//

import UIKit

extension UIViewController {

    /// Верхний контроллер для модалки (учитывает уже показанные экраны).
    var topPresenterForModal: UIViewController {
        guard let presented = presentedViewController else { return self }
        if let nav = presented as? UINavigationController {
            return (nav.visibleViewController ?? nav).topPresenterForModal
        }
        return presented.topPresenterForModal
    }

    var isAIConsultantChatPresented: Bool {
        var walker: UIViewController? = self
        while let current = walker {
            if let presented = current.presentedViewController {
                if let nav = presented as? UINavigationController,
                   nav.viewControllers.first is AIConsultantChatViewController {
                    return true
                }
                walker = presented
            } else {
                break
            }
        }
        return false
    }

    func presentAIConsultantChatFullScreen(animated: Bool = true) {
        guard !isAIConsultantChatPresented else { return }
        let chat = AIConsultantChatViewController()
        chat.presentsAsModalFromTabBar = true
        let nav = UINavigationController(rootViewController: chat)
        AppNavigationBarAppearance.apply(to: nav.navigationBar)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: animated)
    }
}
