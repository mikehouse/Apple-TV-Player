//
//  ContainerViewController.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 10.01.2021.
//

import UIKit

protocol ContainerViewControllerDelegate: AnyObject {
    func containerWillAppear(_ container: ContainerViewController)
    func containerDidAppear(_ container: ContainerViewController)
    func containerWillDisappear(_ container: ContainerViewController)
    func containerDidDisappear(_ container: ContainerViewController)
}

class ContainerViewController: UIViewController {
    weak var delegate: ContainerViewControllerDelegate?
    
    deinit {
        logger.info("deinit \(String(describing: self))")
    }
}

extension ContainerViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        delegate?.containerWillAppear(self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        delegate?.containerDidAppear(self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        delegate?.containerWillDisappear(self)
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        delegate?.containerDidDisappear(self)
    }
}
