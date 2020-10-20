//
//  TextInputViewController.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 21.10.2020.
//

import UIKit

final class TextInputViewController: UIAlertController {
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
    func addOkAction(title: String, completion: ((UIAlertAction) -> Void)?) {
        addAction(UIAlertAction(title: title, style: .default, handler: completion))
    }
    
    func addCancelAction(title: String, completion: ((UIAlertAction) -> Void)?) {
        addAction(UIAlertAction(title: title, style: .cancel, handler: completion))
    }
}
