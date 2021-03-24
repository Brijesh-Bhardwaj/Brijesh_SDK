//
//  AmazonOrderScrapper.swift
//  OrderScrapper
//

import Foundation
import SwiftUI
import Combine

class AmazonOrderScrapper: OrderScrapper {
    private let authProvider: AuthProvider
    private let viewPresenter: ViewPresenter
    
    private var completionSubscriber: AnyCancellable?
    
    required init(authProvider:AuthProvider, viewPresenter:ViewPresenter) {
        self.authProvider = authProvider
        self.viewPresenter = viewPresenter
        
        let authToken = authProvider.getAuthToken()
        let panelistId = authProvider.getPanelistID()
        
        if (authToken.isEmpty || panelistId.isEmpty) {
            // TODO: throw error
        }
        LibContext.shared.authProvider = self.authProvider
        LibContext.shared.viewPresenter = self.viewPresenter
    }
    
    deinit {
        self.completionSubscriber?.cancel()
    }
    
    func getAccounts() -> [Account] {
        return CoreDataManager.shared.fetch(orderSource: OrderSource.Amazon.rawValue)
    }
    
    func connectAccount(orderExtractionListener: OrderExtractionListener) {
        self.completionSubscriber = LibContext.shared.scrapeCompletionPublisher.receive(on: RunLoop.main).sink() { completed in
            if completed {
                orderExtractionListener.onOrderExtractionSuccess()
            } else {
                orderExtractionListener.onOrderExtractionFailure(error: ASLException())
            }
        }
        let viewController = UIHostingController(rootView: LoginView())
        self.viewPresenter.presentView(view: viewController)
    }
    
    func disconnectAccount(account: Account, accountDisconnectedListener: AccountDisconnectedListener) {
        do {
            try CoreDataManager.shared.updateUserAccount(userId: account.userID, accountStatus: AccountState.ConnectedAndDisconnected.rawValue)
            
            WebCacheCleaner.clear()
            
            accountDisconnectedListener.onAccountDisconnected(account: account)
        } catch _ {
            accountDisconnectedListener.onAccountDisconnectionFailed(account: account)
        }
    }
    
    func startOrderExtraction(orderExtractionListener: OrderExtractionListener) {
        let accounts = CoreDataManager.shared.fetch(orderSource: OrderSource.Amazon.rawValue)
        let connectedAccounts = accounts.filter() { $0.accountStatus != AccountState.ConnectedAndDisconnected.rawValue }
        if connectedAccounts.count > 0 {
            let account = connectedAccounts[0]
            let email = account.userId
            let password = RNCryptoUtil.decryptData(userId: email, value: account.password)
            
            let viewController = UIHostingController(rootView: ConnectAccountView(email: email, password: password))
            self.viewPresenter.presentView(view: viewController)
        }
    }
}
