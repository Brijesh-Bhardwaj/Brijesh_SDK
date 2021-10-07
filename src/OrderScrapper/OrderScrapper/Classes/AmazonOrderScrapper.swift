//
//  AmazonOrderScrapper.swift
//  OrderScrapper
//

import Foundation
import SwiftUI
import Combine
import WebKit
import Sentry

class AmazonOrderScrapper {
    private var authProvider: AuthProvider!
    private var viewPresenter: ViewPresenter!
    public var analyticsProvider: AnalyticsProvider?
    private var completionSubscriber: AnyCancellable?
    private var backgroundScrapper: BSScrapper!
    
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
        self.setupCompletionHandler(account, orderExtractionListener)
        
        let storyboard = UIStoryboard(name: "OSLibUI", bundle: AppConstants.bundle)
        let viewController = storyboard.instantiateViewController(identifier: "RegisterAccountVC") as! RegisterAccountViewController
        viewController.account = account as? UserAccountMO
        viewController.modalPresentationStyle = .fullScreen
        
        self.viewPresenter.presentView(view: viewController)
    }
    
    func disconnectAccount(account: Account, accountDisconnectedListener: AccountDisconnectedListener, orderSource: String) {
        _ = AmazonService.updateStatus(amazonId: account.userID, status: AccountState.ConnectedAndDisconnected.rawValue, message: AppConstants.msgDisconnected, orderStatus: OrderStatus.None.rawValue) { response, error in
            if response != nil {
                if self.backgroundScrapper != nil {
                    self.backgroundScrapper.stopScrapping()
                    self.backgroundScrapper = nil
                }
                let panelistId = LibContext.shared.authProvider.getPanelistID()
                CoreDataManager.shared.deleteAccounts(userId: account.userID, panelistId: panelistId)
                CoreDataManager.shared.deleteOrderDetails(userID: account.userID, panelistID: panelistId, orderSource: orderSource)
                WebCacheCleaner.clear(completionHandler: nil)
                accountDisconnectedListener.onAccountDisconnected(account: account)
                UserDefaults.standard.setValue(0, forKey: Strings.OnNumberOfCaptchaRetry)
            } else {
                var errorMsg: String = "Failed while disconnecting account"
                if let error = error as? APIError{
                    errorMsg = error.errorMessage
                }
                let error = ASLException(errorMessage: errorMsg, errorType: nil)
                accountDisconnectedListener.onAccountDisconnectionFailed(account: account, error: error)
                FirebaseAnalyticsUtil.logSentryError(error: error)
            }
        }
    }
    
    func startOrderExtraction(account: Account,
                              orderExtractionListener: OrderExtractionListener,
                              source: FetchRequestSource) {
        self.shouldStartScrapping() { [weak self] shouldScrape in
            guard let self = self else { return }
            
            if shouldScrape {
                if source == .notification {
                    self.performForegroundScraping(account, orderExtractionListener)
                } else {
                    self.performBackgroundScraping(account, orderExtractionListener)
                }
            } else {
                let error = ASLException(errorMessage: "bg process in cool off period" , errorType: nil)
                orderExtractionListener.onOrderExtractionFailure(error: error, account: account)
            }
        }
    }
    
    private func shouldStartScrapping(completion: @escaping(Bool) -> Void) {
        // ConfigObject to
        ConfigManager.shared.getConfigurations(orderSource: .Amazon) { (configurations, error) in
            if let configuration = configurations {
                let lastFailureTime = UserDefaults.standard.double(forKey: Strings.OnBackgroundScrappingTimeOfPeriod)
                let currentTime = Date().timeIntervalSince1970
                let elapsedTime = currentTime - lastFailureTime
                let coolOffTime = configuration.cooloffPeriodCaptcha ?? Strings.BGScrappingCoolOffTime
                completion(elapsedTime > coolOffTime)
            } else {
                completion(false)
            }
        }
    }
    
    private func performForegroundScraping(_ account: Account,
                                           _ orderExtractionListener: OrderExtractionListener) {
        self.setupCompletionHandler(account, orderExtractionListener)
        
        let storyboard = UIStoryboard(name: "OSLibUI", bundle: Bundle(identifier: AppConstants.identifier))
        let viewController = storyboard.instantiateViewController(identifier: "ConnectAccountVC") as! ConnectAccountViewController
        viewController.account = account
        viewController.modalPresentationStyle = .fullScreen
        self.viewPresenter.presentView(view: viewController)
    }
    
    private func performBackgroundScraping(_ account: Account,
                                           _ orderExtractionListener: OrderExtractionListener) {
        if self.backgroundScrapper == nil {
            //Start scrapping in the background
            let scriptMessageHandler = BSScriptMessageHandler()
            let contentController = WKUserContentController()
            contentController.add(scriptMessageHandler, name: "iOS")
            let config = WKWebViewConfiguration()
            config.userContentController = contentController
            let frame = CGRect(x: 0, y: 0, width: 250, height: 400)
            let webClient = BSWebClient(frame: frame, configuration: config, scriptMessageHandler: scriptMessageHandler)
            
            self.backgroundScrapper = AmazonScrapper(webClient: webClient) { [weak self] result, error in
                guard let self = self else {return}
                let (completed, successType) = result
                DispatchQueue.main.async {
                    if completed {
                        orderExtractionListener.onOrderExtractionSuccess(successType: successType!, account: account)
                        UserDefaults.standard.setValue(0, forKey: Strings.OnNumberOfCaptchaRetry)
                    } else {
                        if error?.errorMessage == Strings.ErrorOnAuthenticationChallenge {
                            orderExtractionListener.showNotification(account: account)
                        } else {
                            orderExtractionListener.onOrderExtractionFailure(error: error!, account: account)
                        }
                    }
                }
                self.backgroundScrapper = nil
            }
            //Start scrapping in the background
            self.backgroundScrapper.startScrapping(account: account)
        }
    }
    
    private func setupCompletionHandler(_ account: Account,
                                        _ orderExtractionListener: OrderExtractionListener) {
        self.completionSubscriber = LibContext.shared.scrapeCompletionPublisher.receive(on: RunLoop.main).sink() { [weak self] result, error in
            guard let self = self else { return }
            let (completed, successType) = result
            if completed {
                orderExtractionListener.onOrderExtractionSuccess(successType: successType!, account: account)
                UserDefaults.standard.setValue(0, forKey: Strings.OnNumberOfCaptchaRetry)
            } else {
                let error = ASLException(errorMessage: error?.errorMessage ?? "", errorType: error?.errorType)
                orderExtractionListener.onOrderExtractionFailure(error: error, account: account)
                FirebaseAnalyticsUtil.logSentryError(error: error)
            }
            self.viewPresenter.dismissView()
        }
    }
}
