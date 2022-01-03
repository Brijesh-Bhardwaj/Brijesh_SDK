//  AccountActionCell.swift
//  AmazonOrderScrapper

import Foundation
import UIKit
import OrderScrapper

protocol AccountActionDelegate {
    func disconnectAccount(account: Account, action: String)
    func backgroundScrapping(account: Account)
}

class AccountActionCell: UITableViewCell {
    @IBOutlet weak var accountIDLabel: UILabel!
    @IBOutlet weak var accountStatusImage: UIImageView!
    @IBOutlet weak var accountActionButton: UIButton!
    @IBOutlet weak var bgScrapeButton: UIButton!
    private var currentAccount: Account!
    public var delegate: AccountActionDelegate?

    func setAccountDetails(account: Account) {
        self.currentAccount = account
        self.accountIDLabel.text = account.userID
        if account.accountState == .ConnectedButException {
            self.bgScrapeButton.isHidden = true
            self.accountActionButton.setTitle("Reconnect", for: .normal)
            self.accountStatusImage.isHidden = true
            self.accountActionButton.frame.size.width = 35
        } else if account.accountState == .Connected{
            self.bgScrapeButton.isHidden = false
            self.accountStatusImage.isHidden = false
            self.accountActionButton.setTitle("Disconnect", for: .normal)
        }
    }
    
    @IBAction func accountAction(_ sender: Any) {
        if let title = self.accountActionButton.title(for: .normal) {
            self.delegate?.disconnectAccount(account: currentAccount, action: title)
        }
    }
    
    @IBAction func backgroundScrapping(_ sender: Any) {
        self.delegate?.backgroundScrapping(account: currentAccount)
    }
}
