//
//  DeletePlaylistViewController.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 20.12.2020.
//

import UIKit

final class DeletePlaylistViewController: UIAlertController {
    
    var deleteAction: ((Bool) -> Void)?

    override func viewDidLoad() {
        
        let delete = UIAlertAction.init(title: "Delete playlist ?", style: .destructive) { [weak self] action in
            self?.deleteAction?(true)
        }
        let cancel = UIAlertAction.init(title: "Cancel", style: .cancel) { [weak self] action in
            self?.deleteAction?(false)
        }
        
        addAction(delete)
        addAction(cancel)
        
        super.viewDidLoad()
    }
}
