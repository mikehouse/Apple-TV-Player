//
//  SetPinViewController.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 24.12.2023.
//

import UIKit

final class SetPinViewController: TextInputViewController {
    private var okAction: UIAlertAction?
    private enum ViewTag: Int { case enter = 1; case confirm }
}

extension SetPinViewController {

    func configure(_ completion: @escaping (Bool, String?) -> Void) {
        addTextField { field in
            field.delegate = self
            field.tag = ViewTag.enter.rawValue
            field.placeholder = NSLocalizedString("Enter pin code", comment: "")
            field.isSecureTextEntry = true
        }
        addTextField { field in
            field.delegate = self
            field.tag = ViewTag.confirm.rawValue
            field.placeholder = NSLocalizedString("Confirm pin code", comment: "")
            field.isSecureTextEntry = true
        }
        okAction = addOkAction(title: NSLocalizedString("Ok", comment: "")) { _ in
            guard let pin = self.view.viewWithTag(ViewTag.enter.rawValue) as? UITextField else {
                completion(false, nil)
                return
            }
            completion(true, pin.text)
        }
        okAction?.isEnabled = false
        addCancelAction(title: NSLocalizedString("Cancel", comment: "")) { _ in
            completion(false, nil)
        }
    }
}

extension SetPinViewController: UITextFieldDelegate {
    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        guard reason == .committed else {
            return
        }
        let enter = self.view.viewWithTag(ViewTag.enter.rawValue) as? UITextField
        let confirm = self.view.viewWithTag(ViewTag.confirm.rawValue) as? UITextField
        if let pin = enter?.text, let confirm = confirm?.text, pin.isEmpty == false, pin == confirm {
            self.okAction?.isEnabled = true
        } else {
            self.okAction?.isEnabled = false
        }
    }
}
