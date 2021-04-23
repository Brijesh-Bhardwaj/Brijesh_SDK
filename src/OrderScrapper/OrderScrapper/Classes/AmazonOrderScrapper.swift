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
    public var analyticsProvider: AnalyticsProvider?
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
    
    func initialize(authProvider: AuthProvider, viewPresenter: ViewPresenter,
                    analyticsProvider: AnalyticsProvider?) -> Void {
        self.authProvider = authProvider
        self.viewPresenter = viewPresenter
        self.analyticsProvider = analyticsProvider
        
        LibContext.shared.authProvider = self.authProvider
        LibContext.shared.viewPresenter = self.viewPresenter
    }
    
    deinit {
        self.completionSubscriber?.cancel()
    }
    
    func connectAccount(account: Account, orderExtractionListener: OrderExtractionListener) {
        self.completionSubscriber = LibContext.shared.scrapeCompletionPublisher.receive(on: RunLoop.main).sink() { result, error in
            let (completed, successType) = result
            if completed {
                orderExtractionListener.onOrderExtractionSuccess(successType: successType!, account: account)
            } else {
                orderExtractionListener.onOrderExtractionFailure(error: ASLException(errorMessage: error ?? ""), account: account)
            }
            self.viewPresenter.dismissView()
        }
        
        let storyboard = UIStoryboard(name: "OSLibUI", bundle: AppConstants.bundle)
        let viewController = storyboard.instantiateViewController(identifier: "RegisterAccountVC") as! RegisterAccountViewController
        viewController.account = account as? UserAccountMO
        viewController.modalPresentationStyle = .fullScreen
    
        self.viewPresenter.presentView(view: viewController)
    }
    
    func disconnectAccount(account: Account, accountDisconnectedListener: AccountDisconnectedListener) {
        _ = AmazonService.updateStatus(amazonId: account.userID, status: AccountState.ConnectedAndDisconnected.rawValue, message: AppConstants.msgDisconnected, orderStatus: OrderStatus.None.rawValue) { response, error in
            if response != nil {
                let panelistId = LibContext.shared.authProvider.getPanelistID()
                CoreDataManager.shared.deleteAccounts(userId: account.userID, panelistId: panelistId)
                WebCacheCleaner.clear(completionHandler: nil)
                accountDisconnectedListener.onAccountDisconnected(account: account)
            } else {
                var errorMsg: String = "Failed while disconnecting account"
                if let error = error as? APIError{
                    errorMsg = error.errorMessage
                }
                accountDisconnectedListener.onAccountDisconnectionFailed(account: account, error: ASLException(errorMessage: errorMsg))
            }
        }
    }
    
    func startOrderExtraction(account: Account, orderExtractionListener: OrderExtractionListener) {
        self.completionSubscriber = LibContext.shared.scrapeCompletionPublisher.receive(on: RunLoop.main).sink() { result, error in
            let (completed, successType) = result
            if completed {
                orderExtractionListener.onOrderExtractionSuccess(successType: successType!, account: account)
            } else {
                orderExtractionListener.onOrderExtractionFailure(error: ASLException(errorMessage: error ?? ""), account: account)
            }
            self.viewPresenter.dismissView()
        }
        
        let storyboard = UIStoryboard(name: "OSLibUI", bundle: AppConstants.bundle)
        let viewController = storyboard.instantiateViewController(identifier: "ConnectAccountVC") as! ConnectAccountViewController
        viewController.account = account
        viewController.modalPresentationStyle = .fullScreen
    
        self.viewPresenter.presentView(view: viewController)
    }
}
