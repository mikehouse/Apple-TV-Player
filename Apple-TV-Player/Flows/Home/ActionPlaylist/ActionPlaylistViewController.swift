//
//  ActionPlaylistViewController.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 20.12.2020.
//

import UIKit

final class ActionPlaylistViewController: UIAlertController {
    
    var deleteAction: (() -> Void)?
    var updateAction: (() -> Void)?
    var cancelAction: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let delete = UIAlertAction.init(title: NSLocalizedString("Delete playlist", comment: ""), style: .destructive) { [weak self] action in
            self?.deleteAction?()
        }
        let cancel = UIAlertAction.init(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { [weak self] action in
            self?.cancelAction?()
        }

        addAction(delete)
        addAction(cancel)

        if let updateAction {
            let update = UIAlertAction.init(title: NSLocalizedString("Update playlist", comment: ""), style: .default) { [weak self] action in
                updateAction()
            }
            addAction(update)
        }
    }
}
