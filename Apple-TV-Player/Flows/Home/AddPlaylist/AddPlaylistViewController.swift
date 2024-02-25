//
//  AddPlaylistViewController.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 22.10.2020.
//

import UIKit

final class AddPlaylistViewController: TextInputViewController {
    private var okAction: UIAlertAction?
}

extension AddPlaylistViewController {
    private enum TextFieldKind: Int {
        case url = 1; case name; case pin
    }
    
    func configure(completion: ((URL?, String?, String?) -> Void)?) {
        addTextField { field in
            field.delegate = self
            field.tag = TextFieldKind.url.rawValue
            field.placeholder = "https://example.com/playlist.m3u8"
        }
        addTextField { field in
            field.delegate = self
            field.tag = TextFieldKind.name.rawValue
            field.placeholder = NSLocalizedString("Playlist name", comment: "")
        }
        addTextField { field in
            field.delegate = self
            field.tag = TextFieldKind.pin.rawValue
            field.placeholder = NSLocalizedString("Pin Code", comment: "")
            field.isSecureTextEntry = true
        }
        okAction = addOkAction(title: NSLocalizedString("Add", comment: "")) { _ in
            guard let utv = self.view.viewWithTag(TextFieldKind.url.rawValue) as? UITextField,
                  let ntv = self.view.viewWithTag(TextFieldKind.name.rawValue) as? UITextField,
                  let ptv = self.view.viewWithTag(TextFieldKind.pin.rawValue) as? UITextField else {
                completion?(nil, nil, nil)
                return
            }
            let url: URL? = utv.text.flatMap(URL.init(string:))
            let name: String? = ntv.text == nil || ntv.text?.isEmpty == .some(true) ? nil : ntv.text
            let pin: String? = ptv.text.flatMap({$0.isEmpty ? nil : $0})
            completion?(url, name, pin)
        }
        okAction?.isEnabled = false
        addCancelAction(title: NSLocalizedString("Cancel", comment: ""), completion: nil)
    }
}

extension AddPlaylistViewController: UITextFieldDelegate {
    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        guard textField.tag == TextFieldKind.url.rawValue,
              reason == .committed else {
            return
        }
        let text = textField.text ?? ""
        DispatchQueue.global(qos: .userInitiated).async {
            let components = URLComponents(string: text)
            let isEnabled = components?.scheme != nil
                && components?.host != nil
                && components?.path != nil
            RunLoop.main.perform {
                self.okAction?.isEnabled = isEnabled
            }
        }
    }
}
