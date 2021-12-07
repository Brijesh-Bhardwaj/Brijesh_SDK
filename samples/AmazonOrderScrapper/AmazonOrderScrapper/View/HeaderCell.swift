//  HeaderCell.swift
//  AmazonOrderScrapper

import Foundation
import UIKit

class HeaderCell: UITableViewCell {
    @IBOutlet weak var headerLabel: UILabel!
    
    func setHeaderLabel(label: String) {
        self.headerLabel.text = label
    }
}
