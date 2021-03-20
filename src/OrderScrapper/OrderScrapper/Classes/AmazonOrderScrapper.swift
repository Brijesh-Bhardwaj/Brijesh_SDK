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
        
        let authToken = self.authProvider.getAuthToken()
        let panelistId = self.authProvider.getPanelistID()
        
        if (authToken.isEmpty || panelistId.isEmpty) {
            // TODO: throw error
        }
        
        LibContext.sharedInstance.authToken = authToken
        LibContext.sharedInstance.panelistID = panelistId
    }
    
    func getAccounts() -> [Account] {
        return CoreDataManager.shared.fetch(orderSource: OrderSource.Amazon.rawValue)
    }
    
    func connectAccount(accountConnectionListener: AccountConnectedListener) {
        let viewController = UIHostingController(rootView: LoginView())
        self.viewPresenter.presentView(view: viewController)
    }
    
    func disconnectAccount(account: Account, accountDisconnectedListener: AccountDisconnectedListener) {
            
    }
    
    func startOrderExtraction() {
            
    }
    
    func verifyAccounts() {
            
    }
}
