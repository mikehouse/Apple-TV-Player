//
//  FailureViewController.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 21.10.2020.
//

import UIKit

final class FailureViewController: UIAlertController {
    
    static func make(title: String? = nil, error: Error) -> Self {
        let error = error as NSError
        let message = error.userInfo[NSLocalizedDescriptionKey] as? String
        return Self.init(
            title: title ?? NSLocalizedString("Error", comment: ""),
            message: message ?? "\(error)", preferredStyle: .alert)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    deinit {
        logger.info("deinit \(self)")
    }
}

extension FailureViewController {
    func addOkAction(title: String, completion: ((UIAlertAction) -> Void)?) {
        addAction(UIAlertAction(title: title, style: .default, handler: completion))
    }
    
    func addCancelAction(title: String, completion: ((UIAlertAction) -> Void)?) {
        addAction(UIAlertAction(title: title, style: .cancel, handler: completion))
    }
}
