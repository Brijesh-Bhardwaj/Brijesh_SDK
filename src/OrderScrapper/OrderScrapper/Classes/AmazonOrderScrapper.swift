//
//  AmazonOrderScrapper.swift
//  OrderScrapper
//

import Foundation
import SwiftUI
import Combine
import WebKit
import Sentry
import Network

class AmazonOrderScrapper {
    private var authProvider: AuthProvider!
    private var viewPresenter: ViewPresenter!
    public var analyticsProvider: AnalyticsProvider?
    private var completionSubscriber: AnyCancellable?
    private var backgroundScrapper: BSScrapper!
    let timerValue = BSTimer()
    
    private let monitor = NWPathMonitor()
    
    private lazy var queue: Queue<ScrapingAccountInfo>! = {
        return Queue<ScrapingAccountInfo>(queue: [])
    }()
    
    private lazy var disconnectOperation: [OrderSource:AccountDisconnectedListener] = {
        return [:]
    }()
    
    private lazy var isScrapping: [OrderSource: Bool] = {
        return [:]
    }()
    
    public var isScrappingGoingOn: Bool = false
    
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
        self.setupNetworkMonitor()
        
        LibContext.shared.authProvider = self.authProvider
        LibContext.shared.viewPresenter = self.viewPresenter
        LibContext.shared.servicesStatusListener = servicesStatusListener
    }
    
    deinit {
        self.completionSubscriber?.cancel()
    }
    
    private func setupNetworkMonitor() {
        let queue = DispatchQueue(label: "BackgroundMonitor")
        
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            // Monitor runs on a background thread so we need to publish
            // on the main thread
            DispatchQueue.main.async {
                if path.status == .unsatisfied {
                    if self.backgroundScrapper != nil {
                        self.backgroundScrapper.stopScrapping()
                        self.backgroundScrapper = nil
                    }
                    FirebaseAnalyticsUtil.logSentryMessage(message: "ON network disconnect in bg \(queue) \( self.queue.dataQueue.count)")
                    self.queue.dataQueue.removeAll()
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    func connectAccount(account: Account, orderExtractionListener: OrderExtractionListener) {
        isScrappingGoingOn = true
        self.setupCompletionHandler(account, orderExtractionListener)
        self.terminateScrapping(account: account)
        let viewController = self.getAccountsView(account: account)
    
        DispatchQueue.main.async {
            self.viewPresenter.presentView(view: viewController)
        }
    }
    
    func disconnectAccount(account: Account, accountDisconnectedListener: AccountDisconnectedListener, orderSource: String) {
        let source = account.source
        self.disconnectOperation[source] = accountDisconnectedListener
        
        _ = AmazonService.updateStatus(platformId: account.userID, status: AccountState.ConnectedAndDisconnected.rawValue, message: AppConstants.msgDisconnected, orderStatus: OrderStatus.None.rawValue, orderSource: source.value) { response, error in
            let panelistId = LibContext.shared.authProvider.getPanelistID()
            if response != nil {
                self.terminateScrapping(account: account)
                AmazonService.cancelAPI()
                CoreDataManager.shared.deleteAccounts(userId: account.userID, panelistId: panelistId, orderSource: account.source.rawValue)
                CoreDataManager.shared.deleteOrderDetails(userID: account.userID, panelistID: panelistId, orderSource: source.value)
                WebCacheCleaner.clear(completionHandler: nil)
                if let accountDisconnectListener = self.disconnectOperation[source] {
                    accountDisconnectListener.onAccountDisconnected(account: account)
                    self.disconnectOperation.removeValue(forKey: source)
                }
                let numberOfCapchaRetry = Utils.getKeyForNumberOfCaptchaRetry(orderSorce: source)
                UserDefaults.standard.setValue(0, forKey: numberOfCapchaRetry)
            } else {
                if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
                    let error = ASLException(error: nil, errorMessage: Strings.ErrorServicesDown, failureType: .servicesDown)
                    LibContext.shared.servicesStatusListener.onServicesFailure(exception: error)
                } else {var logEventAttributes:[String:String] = [:]
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
                    if let accountDisconnectListener = self.disconnectOperation[source] {
                        accountDisconnectListener.onAccountDisconnectionFailed(account: account, error: error)
                        self.disconnectOperation.removeValue(forKey: source)
                    }
                    FirebaseAnalyticsUtil.logSentryError(error: error)
                }
            }
        }
    }
    func startOrderExtraction(account: Account,
                              orderExtractionListener: OrderExtractionListener,
                              source: FetchRequestSource) -> RetailerScrapingStatus {
        var scrappingProcess = RetailerScrapingStatus.Other
        if source == .notification || source == .manual{
            self.terminateScrapping(account: account)
            if isScrappingGoingOn && self.backgroundScrapper != nil {
                self.backgroundScrapper.stopScrapping()
                self.backgroundScrapper = nil
            }
            FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_foreground_scrapping \(account.source)")
            print("####### FetchRequestSource ", source.rawValue)
            self.performForegroundScraping(account, orderExtractionListener, source)
        } else {
            let isScrappingSource = self.isScrapping[account.source] ?? false || self.isScrappingGoingOn
            if isScrappingSource == false {
                self.isScrapping[account.source] = false
                print("isScrappingSource",isScrappingSource)
                let dataQueue = self.queue.dataQueue
                let details = ScrapingAccountInfo(account: account, orderExtractionListner: orderExtractionListener, source: source)
                var dataPresent = false
                for data in dataQueue {
                    if data == details {
                        dataPresent = true
                        scrappingProcess = RetailerScrapingStatus.InProgress
                        break
                    }
                }
                if !dataPresent {
                    self.queue.dataQueue.append(details)
                    self.scrappingQueue()
                    scrappingProcess = RetailerScrapingStatus.Enqueued
                }
            } else {
                scrappingProcess = RetailerScrapingStatus.Enqueued
            }
            
        }
        return scrappingProcess
    }
    
    private func scrappingQueue() {
        let scrappingData = queue.peekData()
        if scrappingData != nil && (self.isScrapping[(scrappingData?.account.source)!] == false) {
            self.isScrapping[(scrappingData?.account.source)!] = true
            if !isScrappingGoingOn {
                self.shouldStartScrapping(orderSource: (scrappingData?.account.source)!) { [weak self] shouldScrape in
                    guard let self = self else { return }
                    if shouldScrape {
                        FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_background_scrapping \((scrappingData?.account.source)!)")
                        self.performBackgroundScraping((scrappingData?.account)!, (scrappingData?.orderExtractionListner)!)
                    } else {
                        let logEventAttributes:[String:String] = [EventConstant.OrderSource: (scrappingData?.account.source.value) ?? "",
                                                                  EventConstant.PanelistID: (scrappingData?.account.panelistID) ?? "",
                                                                  EventConstant.OrderSourceID: (scrappingData?.account.userID) ?? "",
                                                                  EventConstant.ScrappingMode: ScrapingMode.Background.rawValue,
                                                                  EventConstant.Status: EventStatus.Success]
                        let error = ASLException(errorMessage: AppConstants.ErrorBgScrappingCoolOff , errorType: nil)
                        if let orderSource = (scrappingData?.account.source.value) {
                            let logEvent = EventLogs(panelistId: scrappingData?.account.panelistID ?? "", platformId: scrappingData?.account.userID ?? "", section: SectionType.orderUpload.rawValue, type: FailureTypes.other.rawValue, status: EventState.fail.rawValue, message: AppConstants.ErrorBgScrappingCoolOff, fromDate: nil, toDate: nil, scrapingType: nil, scrapingContext: ScrapingMode.Background.rawValue)
                                                
                            _ = AmazonService.logEvents(eventLogs: logEvent, orderSource: orderSource ) { response, error in}
                        }
                        scrappingData?.orderExtractionListner.onOrderExtractionFailure(error: error, account: (scrappingData?.account)!)
                        FirebaseAnalyticsUtil.logEvent(eventType: EventType.InCoolOffPeriod, eventAttributes: logEventAttributes)
                    }
                }
            }
        }
    }
    
    private func shouldStartScrapping(orderSource: OrderSource, completion: @escaping(Bool) -> Void) {
        // ConfigObject to
        ConfigManager.shared.getConfigurations(orderSource: orderSource) { (configurations, error) in
            if let configuration = configurations {
                let coolOffTimePeriod = Utils.getKeyForCoolOfTime(orderSorce: orderSource)
                
                let lastFailureTime = UserDefaults.standard.double(forKey: coolOffTimePeriod)
                let currentTime = Date().timeIntervalSince1970
                let elapsedTime = currentTime - lastFailureTime
                let coolOffTime = configuration.cooloffPeriodCaptcha ?? Strings.BGScrappingCoolOffTime
                completion(elapsedTime > coolOffTime)
            } else {
                if let error = error {
                    let panelistId = LibContext.shared.authProvider.getPanelistID()
                    var logEventAttributes:[String:String] = [:]
                
                    logEventAttributes = [EventConstant.OrderSource: orderSource.value,
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
                                           _ orderExtractionListener: OrderExtractionListener,
                                           _ source: FetchRequestSource) {
        isScrappingGoingOn = true
        self.setupCompletionHandler(account, orderExtractionListener)
        
        switch account.source {
        case .Amazon:
            let storyboard = UIStoryboard(name: "OSLibUI", bundle: Bundle(identifier: AppConstants.identifier))
            let viewController = storyboard.instantiateViewController(identifier: "ConnectAccountVC") as! ConnectAccountViewController
            viewController.account = account
            viewController.fetchRequestSource = source
            viewController.modalPresentationStyle = .fullScreen
            self.viewPresenter.presentView(view: viewController)
            
        case .Instacart:
            let storyboard = UIStoryboard(name: "OSLibUI", bundle: Bundle(identifier: AppConstants.identifier))
            let viewController = storyboard.instantiateViewController(identifier: "InstacartConnectAccountVC") as! ConnectInstacartAccountVC
            viewController.account = account
            viewController.fetchRequestSource = source
            viewController.modalPresentationStyle = .fullScreen
            self.viewPresenter.presentView(view: viewController)
            
        case .Kroger:
            let storyboard = UIStoryboard(name: "OSLibUI", bundle: Bundle(identifier: AppConstants.identifier))
            let viewController = storyboard.instantiateViewController(identifier: "KrogerConnectAccountVC") as! ConnectKrogerAccountVC
            viewController.account = account
            viewController.fetchRequestSource = source
            viewController.modalPresentationStyle = .fullScreen
            self.viewPresenter.presentView(view: viewController)
            
        case .Walmart:
            let storyboard = UIStoryboard(name: "OSLibUI", bundle: Bundle(identifier: AppConstants.identifier))
            let viewController = storyboard.instantiateViewController(identifier: "WalmartConnectAccountVC") as! ConnectWalmartAccountVC
            viewController.account = account
            viewController.fetchRequestSource = source
            viewController.modalPresentationStyle = .fullScreen
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
            
            self.backgroundScrapper = self.getScrappingClient(account: account, webClient: webClient, orderExtractionListener: orderExtractionListener)
            
            //Start scrapping in the background
            timerValue.start()
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
                
                let numberOfCapchaRetry = Utils.getKeyForNumberOfCaptchaRetry(orderSorce: account.source)
                UserDefaults.standard.setValue(0, forKey: numberOfCapchaRetry)
            } else {
                let error = ASLException(errorMessage: error?.errorMessage ?? "", errorType: error?.errorType)
                orderExtractionListener.onOrderExtractionFailure(error: error, account: account)
                FirebaseAnalyticsUtil.logSentryError(error: error)
            }
            self.isScrappingGoingOn = false
            self.viewPresenter.dismissView()
        }
    }
    
    func getAccountsView(account: Account) -> UIViewController {
        
        switch account.source {
        case .Amazon:
            let storyboard = UIStoryboard(name: "OSLibUI", bundle: AppConstants.bundle)
            let viewController = storyboard.instantiateViewController(identifier: "RegisterAccountVC") as AmazonLogin
            viewController.account = account as? UserAccountMO
            viewController.modalPresentationStyle = .fullScreen
            
            return viewController
        case .Instacart:
            let storyboard = UIStoryboard(name: "OSLibUI", bundle: AppConstants.bundle)
            let viewController = storyboard.instantiateViewController(identifier: "InstacartRegisterAccountVC") as InstacartLogin
            viewController.account = account as? UserAccountMO
            viewController.modalPresentationStyle = .fullScreen
            
            return viewController
        case .Kroger:
            let storyboard = UIStoryboard(name: "OSLibUI", bundle: AppConstants.bundle)
            let viewController = storyboard.instantiateViewController(identifier: "KrogerRegisterAccountVC") as KrogerLogin
            viewController.account = account as? UserAccountMO
            viewController.modalPresentationStyle = .fullScreen
            
            return viewController
        case .Walmart:
            let storyboard = UIStoryboard(name: "OSLibUI", bundle: AppConstants.bundle)
            let viewController = storyboard.instantiateViewController(identifier: "WalmartRegisterAccountVC") as WalmartLogin
            viewController.account = account as? UserAccountMO
            viewController.modalPresentationStyle = .fullScreen
            
            return viewController
        }
    }
    
    func getScrappingClient(account: Account, webClient: BSWebClient, orderExtractionListener: OrderExtractionListener) -> BSScrapper {
        
        switch  account.source {
        case .Amazon:
            self.backgroundScrapper = AmazonScrapper(webClient: webClient) { [weak self] result, error in
                guard let self = self else {return}
                let (completed, successType) = result
                DispatchQueue.main.async {
                    var accountDetail: Account = account
                    if completed {
                        if let successType = successType {
                            orderExtractionListener.onOrderExtractionSuccess(successType: successType, account: account)
                        } else {
                            orderExtractionListener.onOrderExtractionSuccess(successType: .fetchCompleted, account: account)
                        }
                        UserDefaults.standard.setValue(0, forKey: Strings.AmazonOnNumberOfCaptchaRetry)
                    } else {
                        if error?.errorMessage == Strings.ErrorOnAuthenticationChallenge {
                            accountDetail.accountState = .ConnectedButScrappingFailed
                            orderExtractionListener.showNotification(account: accountDetail)
                        } else {
                            if let error = error {
                                orderExtractionListener.onOrderExtractionFailure(error: error, account: account)
                            } else {
                                orderExtractionListener.onOrderExtractionFailure(error: ASLException(errorMessage: Strings.ErrorOrderExtractionFailed, errorType: nil), account: account)
                            }
                        }
                    }
                    self.scrapeNextAccount(account: account)
                }
                self.backgroundScrapper = nil
            }
            return self.backgroundScrapper
        case .Instacart:
            self.backgroundScrapper = InstacartScrapper(webClient: webClient) { [weak self] result, error in
                guard let self = self else {return}
                let (completed, successType) = result
                DispatchQueue.main.async {
                    var accountDetail: Account = account
                    if completed {
                        if let successType = successType {
                            orderExtractionListener.onOrderExtractionSuccess(successType: successType, account: account)
                        } else {
                            orderExtractionListener.onOrderExtractionSuccess(successType: .fetchCompleted, account: account)
                        }
                        UserDefaults.standard.setValue(0, forKey: Strings.InstacartOnNumberOfCaptchaRetry)
                    } else {
                        if error?.errorMessage == Strings.ErrorOnAuthenticationChallenge {
                            accountDetail.accountState = .ConnectedButScrappingFailed
                            orderExtractionListener.showNotification(account: accountDetail)
                        } else {
                            if let error = error {
                                orderExtractionListener.onOrderExtractionFailure(error: error, account: account)
                            } else {
                                orderExtractionListener.onOrderExtractionFailure(error: ASLException(errorMessage: Strings.ErrorOrderExtractionFailed, errorType: nil), account: account)
                            }
                        }
                    }
                    self.scrapeNextAccount(account: account)
                }
                self.backgroundScrapper = nil
            }
            return self.backgroundScrapper
        case .Kroger:
            self.backgroundScrapper = KrogerScrapper(webClient: webClient) { [weak self] result, error in
                guard let self = self else {return}
                let (completed, successType) = result
                DispatchQueue.main.async {
                    var accountDetail: Account = account
                    if completed {
                        
                        if let successType = successType {
                            orderExtractionListener.onOrderExtractionSuccess(successType: successType, account: account)
                        } else {
                            orderExtractionListener.onOrderExtractionSuccess(successType: .fetchCompleted, account: account)
                        }
                        
                        UserDefaults.standard.setValue(0, forKey: Strings.KrogerOnNumberOfCaptchaRetry)
                    } else {
                        if error?.errorMessage == Strings.ErrorOnAuthenticationChallenge {
                            accountDetail.accountState = .ConnectedButScrappingFailed
                            orderExtractionListener.showNotification(account: account)
                        } else {
                            if let error = error {
                                orderExtractionListener.onOrderExtractionFailure(error: error, account: account)
                            } else {
                                orderExtractionListener.onOrderExtractionFailure(error: ASLException(errorMessage: Strings.ErrorOrderExtractionFailed, errorType: nil), account: account)
                            }
                        }
                    }
                    self.scrapeNextAccount(account: account)
                }
                self.backgroundScrapper = nil
            }
            return self.backgroundScrapper
        case .Walmart:
            self.backgroundScrapper = WalmartScrapper(webClient: webClient) { [weak self] result, error in
                guard let self = self else {return}
                let (completed, successType) = result
                DispatchQueue.main.async {
                    if completed {
                        if let successType = successType {
                            orderExtractionListener.onOrderExtractionSuccess(successType: successType, account: account)
                        } else {
                            orderExtractionListener.onOrderExtractionSuccess(successType: .fetchCompleted, account: account)
                        }
                        
                        UserDefaults.standard.setValue(0, forKey: Strings.KrogerOnNumberOfCaptchaRetry)
                    } else {
                        if error?.errorMessage == Strings.ErrorOnAuthenticationChallenge {
                            orderExtractionListener.showNotification(account: account)
                        } else {
                            if let error = error {
                                orderExtractionListener.onOrderExtractionFailure(error: error, account: account)
                            } else {
                                orderExtractionListener.onOrderExtractionFailure(error: ASLException(errorMessage: Strings.ErrorOrderExtractionFailed, errorType: nil), account: account)
                            }
                            
                        }
                    }
                    self.scrapeNextAccount(account: account)
                }
                self.backgroundScrapper = nil
            }
            return self.backgroundScrapper
        }
    }
    
    private func terminateScrapping(account: Account) {
        if self.backgroundScrapper != nil {
            self.backgroundScrapper.stopScrapping()
            self.backgroundScrapper = nil
        }
        for key in Array(isScrapping.keys)  {
            self.isScrapping[key] = false
        }
        self.queue.dataQueue.removeAll()
    }
    private func scrapeNextAccount(account: Account) {
        let timerCount = self.timerValue.stop()
        let logEventAttributes = [EventConstant.OrderSource: account.source.value,
                              EventConstant.OrderSourceID: account.userID,
                              EventConstant.ScrappingTime: timerCount,
                              EventConstant.Status: EventStatus.Success]
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.onCompleteScrapping, eventAttributes: logEventAttributes)
        self.isScrapping[account.source] = false
        let _ = self.queue.peek()
        self.scrappingQueue()
    }
    
}
