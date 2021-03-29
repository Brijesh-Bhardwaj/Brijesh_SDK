//
//  AmazonOrderScrapper.swift
//  OrderScrapper
//

import Foundation
import SwiftUI
import Combine

class AmazonOrderScrapper {
    private var authProvider: AuthProvider!
    private var viewPresenter: ViewPresenter!
    private var completionSubscriber: AnyCancellable?
    
    private static var instance: AmazonOrderScrapper!
    
    public static let shared: AmazonOrderScrapper = {
        if instance == nil {
            instance = AmazonOrderScrapper()
        }
        return instance
    }()
    
    private init(){}
    
    static func isInitialized() -> Bool {
        return instance != nil
    }
    
    func initialize(authProvider: AuthProvider, viewPresenter: ViewPresenter) -> Void {
        self.authProvider = authProvider
        self.viewPresenter = viewPresenter
        
        LibContext.shared.authProvider = self.authProvider
        LibContext.shared.viewPresenter = self.viewPresenter
    }
    
    deinit {
        self.completionSubscriber?.cancel()
    }
    
    func connectAccount(account: Account, orderExtractionListener: OrderExtractionListener) {
        self.completionSubscriber = LibContext.shared.scrapeCompletionPublisher.receive(on: RunLoop.main).sink() { completed, error in
            if completed {
                orderExtractionListener.onOrderExtractionSuccess()
            } else {
                orderExtractionListener.onOrderExtractionFailure(error: ASLException(errorMessage: error ?? ""))
            }
        }
        
        let storyboard = UIStoryboard(name: "OSLibUI", bundle: AppConstants.bundle)
        let viewController = storyboard.instantiateViewController(identifier: "RegisterAccountVC") as! RegisterAccountViewController
        viewController.account = account as? UserAccountMO
        viewController.modalPresentationStyle = .fullScreen
    
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
    
    func startOrderExtraction(account: Account, orderExtractionListener: OrderExtractionListener) {
        self.completionSubscriber = LibContext.shared.scrapeCompletionPublisher.receive(on: RunLoop.main).sink() { completed, error in
            if completed {
                orderExtractionListener.onOrderExtractionSuccess()
            } else {
                orderExtractionListener.onOrderExtractionFailure(error: ASLException(errorMessage: error ?? ""))
            }
        }
        
        let storyboard = UIStoryboard(name: "OSLibUI", bundle: AppConstants.bundle)
        let viewController = storyboard.instantiateViewController(identifier: "ConnectAccountVC") as! ConnectAccountViewController
        viewController.account = account
        viewController.modalPresentationStyle = .fullScreen
    
        self.viewPresenter.presentView(view: viewController)
    }
}
