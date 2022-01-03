//  ConnectAccountCell.swift
//  AmazonOrderScrapper

import Foundation
import UIKit

protocol ConnectAccountDelegate {
    func connectAccount(section: Int)
}

class ConnectAccountCell: UITableViewCell {
    @IBOutlet weak var connectAccount: UIButton!
    public var delegate: ConnectAccountDelegate?

    @IBAction func connectAccount(_ sender: Any) {
        self.delegate?.connectAccount(section: connectAccount.tag)
    }
}
