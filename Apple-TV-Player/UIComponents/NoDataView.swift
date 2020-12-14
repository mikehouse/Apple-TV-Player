//
//  NoDataView.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 05.12.2020.
//

import UIKit

extension UIView {
    static func make(title: String) -> UIView {
        let view = UIView()
        let label = UILabel()
        label.text = title
        label.textAlignment = .center
        label.numberOfLines = 0
        view.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 16),
            label.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 16)
        ])
        return view
    }
}
