//
//  AmazonOrderScrapper.swift
//  OrderScrapper
//

import Foundation
import SwiftUI

class AmazonOrderScrapper: OrderScrapper {
    let viewPresenter: ViewPresenter!
    let authProvider: AuthProvider!
    
    required init(authProvider:AuthProvider, viewPresenter:ViewPresenter) {
        self.authProvider = authProvider
        self.viewPresenter = viewPresenter
    }
    
    func getAccounts() -> [Account] {
        return []
    }
    
    func connectAccount(accountConnectionListener: AccountConnectedListener) {
        let viewController = UIHostingController(rootView: ConnectAccountView(email: "avinash.mohanta18@gmail.com", password: "Welcome@123"))
        self.viewPresenter.presentView(view: viewController)
    }
    
    func disconnectAccount(account: Account, accountDisconnectedListener: AccountDisconnectedListener) {
            
    }
    
    func startOrderExtraction() {
            
    }
    
    func verifyAccounts() {
            
    }
}
