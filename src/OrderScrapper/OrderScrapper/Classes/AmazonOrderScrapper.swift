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
    public var isScrapping: Bool = false
    
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
                    analyticsProvider: AnalyticsProvider?, servicesStatusListener: ServicesStatusListener) -> Void {
        self.authProvider = authProvider
        self.viewPresenter = viewPresenter
        self.analyticsProvider = analyticsProvider
        
        LibContext.shared.authProvider = self.authProvider
        LibContext.shared.viewPresenter = self.viewPresenter
        LibContext.shared.servicesStatusListener = servicesStatusListener
    }
    
    deinit {
        self.completionSubscriber?.cancel()
    }
    
    func connectAccount(account: Account, orderExtractionListener: OrderExtractionListener) {
        isScrapping = true
        self.setupCompletionHandler(account, orderExtractionListener)
        
        let storyboard = UIStoryboard(name: "OSLibUI", bundle: AppConstants.bundle)
        let viewController = storyboard.instantiateViewController(identifier: "RegisterAccountVC") as! RegisterAccountViewController
        viewController.account = account as? UserAccountMO
        viewController.modalPresentationStyle = .fullScreen
        DispatchQueue.main.async {
            self.viewPresenter.presentView(view: viewController)
        }
    }
    
    func disconnectAccount(account: Account, accountDisconnectedListener: AccountDisconnectedListener, orderSource: String) {
        _ = AmazonService.updateStatus(amazonId: account.userID, status: AccountState.ConnectedAndDisconnected.rawValue, message: AppConstants.msgDisconnected, orderStatus: OrderStatus.None.rawValue) { response, error in
            let panelistId = LibContext.shared.authProvider.getPanelistID()
            if response != nil {
                if self.backgroundScrapper != nil {
                    self.backgroundScrapper.stopScrapping()
                    self.backgroundScrapper = nil
                }
                CoreDataManager.shared.deleteAccounts(userId: account.userID, panelistId: panelistId)
                CoreDataManager.shared.deleteOrderDetails(userID: account.userID, panelistID: panelistId, orderSource: orderSource)
                WebCacheCleaner.clear(completionHandler: nil)
                DispatchQueue.main.async {
                    accountDisconnectedListener.onAccountDisconnected(account: account)
                }
                UserDefaults.standard.setValue(0, forKey: Strings.OnNumberOfCaptchaRetry)
                UserDefaults.standard.setValue(0, forKey: Strings.OnAuthenticationChallenegeRetryCount)
            } else {
                if let error = error, error.errorEventLog == .servicesDown {
                    let error = ASLException(error: nil, errorMessage: Strings.ErrorServicesDown, failureType: .servicesDown)
                    LibContext.shared.servicesStatusListener.onServicesFailure(exception: error)
                } else {
                    var logEventAttributes:[String:String] = [:]
                    logEventAttributes = [EventConstant.OrderSource: orderSource,
                                          EventConstant.PanelistID: panelistId,
                                          EventConstant.OrderSourceID: account.userID]
                    if let error = error {
                        logEventAttributes[EventConstant.EventName] = EventType.UpdateStatusAPIFailedWhileDisconnect
                        FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
                    } else {
                        FirebaseAnalyticsUtil.logEvent(eventType: EventType.UpdateStatusAPIFailedWhileDisconnect, eventAttributes: logEventAttributes)
                    }
                    
                    var errorMsg: String = "Failed while disconnecting account"
                    if let error = error as? APIError{
                        errorMsg = error.errorMessage
                    }
                    let error = ASLException(errorMessage: errorMsg, errorType: nil)
                    DispatchQueue.main.async {
                        accountDisconnectedListener.onAccountDisconnectionFailed(account: account, error: error)
                    }
                }
            }
        }
    }
    
    func startOrderExtraction(account: Account,
                              orderExtractionListener: OrderExtractionListener,
                              source: FetchRequestSource) {
        if source == .notification {
            if isScrapping && self.backgroundScrapper != nil {
                self.backgroundScrapper.stopScrapping()
                self.backgroundScrapper = nil
            }
            FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_foreground_scrapping \(source)")
            self.performForegroundScraping(account, orderExtractionListener)
        } else {
            if !isScrapping {
                self.shouldStartScrapping() { [weak self] shouldScrape in
                    guard let self = self else { return }
                    if shouldScrape {
                        FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_background_scrapping \(source)")
                        self.performBackgroundScraping(account, orderExtractionListener)
                    } else {
                        var logEventAttributes:[String:String] = [:]
                        logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                              EventConstant.PanelistID: account.panelistID,
                                              EventConstant.OrderSourceID: account.userID,
                                              EventConstant.ScrappingMode: ScrapingMode.Background.rawValue,
                                              EventConstant.Status: EventStatus.Success]
                        
                        let error = ASLException(errorMessage: "bg process in cool off period" , errorType: nil)
                        orderExtractionListener.onOrderExtractionFailure(error: error, account: account)
                        FirebaseAnalyticsUtil.logEvent(eventType: EventType.InCoolOffPeriod, eventAttributes: logEventAttributes)
                    }
                }
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
                if let error = error {
                    let panelistId = LibContext.shared.authProvider.getPanelistID()
                    var logEventAttributes:[String:String] = [:]
                    logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                          EventConstant.PanelistID: panelistId,
                                          EventConstant.ScrappingMode: ScrapingMode.Background.rawValue,
                                          EventConstant.Status: EventStatus.Failure]
                    FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
                }
                completion(false)
            }
        }
    }
    
    private func performForegroundScraping(_ account: Account,
                                           _ orderExtractionListener: OrderExtractionListener) {
        isScrapping = true
        self.setupCompletionHandler(account, orderExtractionListener)
        
        let storyboard = UIStoryboard(name: "OSLibUI", bundle: Bundle(identifier: AppConstants.identifier))
        let viewController = storyboard.instantiateViewController(identifier: "ConnectAccountVC") as! ConnectAccountViewController
        viewController.account = account
        viewController.modalPresentationStyle = .fullScreen
        DispatchQueue.main.async {
            self.viewPresenter.presentView(view: viewController)
        }
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
                        UserDefaults.standard.setValue(0, forKey: Strings.OnAuthenticationChallenegeRetryCount)
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
            self.backgroundScrapper.scrappingMode = .Background
            self.backgroundScrapper.startScrapping(account: account)
        }
    }
    
    private func setupCompletionHandler(_ account: Account,
                                        _ orderExtractionListener: OrderExtractionListener) {
        self.completionSubscriber = LibContext.shared.scrapeCompletionPublisher.receive(on: RunLoop.main).sink() { [weak self] result, error in
            guard let self = self else { return }
            let (completed, successType) = result
            DispatchQueue.main.async {
                if completed {
                    orderExtractionListener.onOrderExtractionSuccess(successType: successType!, account: account)
                    UserDefaults.standard.setValue(0, forKey: Strings.OnNumberOfCaptchaRetry)
                    UserDefaults.standard.setValue(0, forKey: Strings.OnAuthenticationChallenegeRetryCount)
                } else {
                    let error = ASLException(errorMessage: error?.errorMessage ?? "", errorType: error?.errorType)
                    orderExtractionListener.onOrderExtractionFailure(error: error, account: account)
                    
                    var logEventAttributes:[String:String] = [:]
                    logEventAttributes = [EventConstant.PanelistID: account.panelistID,
                                          EventConstant.OrderSourceID: account.userID,
                                          EventConstant.Status: EventStatus.Failure]
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.OrderExtractionFailure, eventAttributes: logEventAttributes)
                }
            }
            self.isScrapping = false
            DispatchQueue.main.async {
                self.viewPresenter.dismissView()
            }
        }
    }
}
