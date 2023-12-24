//
//  DeletePinViewController.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 24.12.2023.
//

import UIKit

final class DeletePinViewController: TextInputViewController {
    private var okAction: UIAlertAction?
    private let textFieldViewTag = 9
}

extension DeletePinViewController {

    func configure(_ completion: @escaping (Bool, String?) -> Void) {
        let textFieldViewTag = self.textFieldViewTag
        addTextField { field in
            field.delegate = self
            field.tag = textFieldViewTag
            field.placeholder = NSLocalizedString("Enter pin code", comment: "")
            field.isSecureTextEntry = true
        }
        okAction = addOkAction(title: NSLocalizedString("Delete pin code", comment: "")) { _ in
            guard let pin = self.view.viewWithTag(textFieldViewTag) as? UITextField else {
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

extension DeletePinViewController: UITextFieldDelegate {
    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        guard textField.tag == textFieldViewTag,
              reason == .committed else {
            return
        }
        let text = textField.text ?? ""
        self.okAction?.isEnabled = text.isEmpty == false
    }
}
