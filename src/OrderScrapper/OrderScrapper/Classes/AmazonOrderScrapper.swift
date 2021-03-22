//
//  AmazonOrderScrapper.swift
//  OrderScrapper
//

import Foundation
import SwiftUI

class AmazonOrderScrapper: OrderScrapper {
    
    required init(authProvider:AuthProvider, viewPresenter:ViewPresenter) {
        let authToken = authProvider.getAuthToken()
        let panelistId = authProvider.getPanelistID()
        
        if (authToken.isEmpty || panelistId.isEmpty) {
            // TODO: throw error
        }
        
        LibContext.shared.authProvider = authProvider
        LibContext.shared.viewPresenter = viewPresenter
    }
    
    func getAccounts() -> [Account] {
        return CoreDataManager.shared.fetch(orderSource: OrderSource.Amazon.rawValue)
    }
    
    func connectAccount(accountConnectionListener: AccountConnectedListener) {
        let viewController = UIHostingController(rootView: LoginView())
        LibContext.shared.viewPresenter.presentView(view: viewController)
    }
    
    func disconnectAccount(account: Account, accountDisconnectedListener: AccountDisconnectedListener) {
            
    }
    
    func startOrderExtraction() {
            
    }
    
    func verifyAccounts() {
            
    }
}
