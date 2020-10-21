//
//  TextInputViewController.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 21.10.2020.
//

import UIKit

class TextInputViewController: UIAlertController {
    override func viewDidLoad() {
        super.viewDidLoad()
    }
}

extension TextInputViewController {
    func addTextInput(handler: ((UITextField) -> Void)? = nil) {
        addTextField(configurationHandler: handler)
    }
}

extension TextInputViewController {
    @discardableResult
    func addOkAction(title: String, completion: ((UIAlertAction) -> Void)?) -> UIAlertAction {
        let action = UIAlertAction(title: title, style: .default, handler: completion)
        addAction(action)
        return action
    }
    
    @discardableResult
    func addCancelAction(title: String, completion: ((UIAlertAction) -> Void)?) -> UIAlertAction {
        let action = UIAlertAction(title: title, style: .cancel, handler: completion)
        addAction(action)
        return action
    }
}
