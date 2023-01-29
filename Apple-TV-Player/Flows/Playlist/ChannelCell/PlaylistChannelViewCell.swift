//
//  PlaylistChannelViewCell.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 14.11.2020.
//

import UIKit
import Reusable

final class PlaylistChannelViewCell: UITableViewCell, NibReusable {

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code

        detailTextLabel?.text = nil
    }
}
