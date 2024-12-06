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
    var removeCacheAction: (() -> Void)?
    var setPinAction: (() -> Void)?
    var removePinAction: (() -> Void)?
    var resetPlaylistOrderAction: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let cancel = UIAlertAction.init(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { [weak self] action in
            self?.cancelAction?()
        }
        addAction(cancel)
        
        if let deleteAction {
            let delete = UIAlertAction.init(title: NSLocalizedString("Delete playlist", comment: ""), style: .destructive) { _ in
                deleteAction()
            }
            addAction(delete)
        }

        if let resetPlaylistOrderAction {
            let delete = UIAlertAction.init(title: NSLocalizedString("Reset playlist order", comment: ""), style: .default) { _ in
                resetPlaylistOrderAction()
            }
            addAction(delete)
        }

        if let setPinAction {
            let setPin = UIAlertAction.init(title: NSLocalizedString("Set pin code", comment: ""), style: .default) { _ in
                setPinAction()
            }
            addAction(setPin)
        }
        if let removePinAction {
            let removePin = UIAlertAction.init(title: NSLocalizedString("Delete pin code", comment: ""), style: .default) { _ in
                removePinAction()
            }
            addAction(removePin)
        }
        if let updateAction {
            let update = UIAlertAction.init(title: NSLocalizedString("Update playlist", comment: ""), style: .default) { _ in
                updateAction()
            }
            addAction(update)
        }
        if let removeCacheAction {
            let remove = UIAlertAction.init(title: NSLocalizedString("Remove playlist cache", comment: ""), style: .default) {_ in
                removeCacheAction()
            }
            addAction(remove)
        }
    }
}
