//  ConnectWalmartAccountVC.swift
//  OrderScrapper

import Foundation
import UIKit
import WebKit
import Combine
import Network
import Sentry

class ConnectWalmartAccountVC: BaseAccountConnectVC {
    private let baseURL = "https://www.walmart.com/account/login?redirectUrl=/orders"
    private let WalmartOrderPage = "https://www.walmart.com/orders"
    private let URLLoadingTime = 20.0
    var loginView: LoginView!
    var backgroundScrapper: BSScrapper!
    private var showLoadView = false
    private var configurations: Configurations {
        Configurations(login: "https://www.walmart.com/account/login")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.connectAccountView.connectAccountTitle.text = self.getHeaderTitle()
        self.connectAccountView.progressView.headerText = self.getHeaderMessage()
        self.baseAuthenticator = WalmartAuthenticator(webClient: self.webClient, delegate: self.webClientDelegate)
        self.baseAuthenticator.authenticationDelegate = self
        self.shouldAllowBack = false
        self.baseAuthenticator.timerHandler.startTimer(action: Actions.BaseURLLoading, timerInterval: TimeInterval(URLLoadingTime))
        self.publishProgress(steps: .authentication)
        self.baseAuthenticator.authenticate(account: self.account, configurations: self.configurations) { authenticated, error in
            if authenticated {
                self.baseAuthenticator.timerHandler.stopTimer()
                self.webClient.loadUrl(url: self.configurations.listing)
                if self.account.accountState == .NeverConnected {
                    self.publishProgress(steps: .scrape)
                    let userId = self.account.userID
                    _ = AmazonService.registerConnection(platformId: userId, status: AccountState.Connected.rawValue, message: AppConstants.msgAccountConnected, orderStatus: OrderStatus.Initiated.rawValue, orderSource: OrderSource.Walmart.value) { response, error in
                        if let response = response {
                            self.addUserAccountInDB()
                            self.account.isFirstConnectedAccount = response.firstaccount
                            self.timerHandler.startTimer(action: Actions.ForegroundHtmlScrapping)
                            self.scrapeHtml()
                        } else {
                            if self.networkReconnct {
                                print("#### Network Reconnect")
                                self.scrapeHtml()
                                self.networkReconnct = false
                            } else {
                                print("#### Account Register Error")
                                self.didReceiveLoginChallenge(error: AppConstants.userAccountConnected)
                                if let error = error {
                                    FirebaseAnalyticsUtil.logSentryError(error: error)
                                }
                                //Remove webview in case error occured while register so it won't reload in case of network off
                                self.removeWebview()
                            }
                        }
                    }
                } else {
                    self.updateAccountStatusToConnected(orderStatus: OrderStatus.Initiated.rawValue)
                    self.addUserAccountInDB()
                    self.timerHandler.startTimer(action: Actions.ForegroundHtmlScrapping)
                    self.scrapeHtml()
                }
            } else {
                self.didReceiveLoginChallenge(error: Strings.ErrorOnWebViewLoading)
            }
        }
    }
    
    
    override func onNetworkChange(isNetworkAvailable: Bool) {
        if isNetworkAvailable {
            // Network available
            if self.showLoadView {
                self.loadWebContent()
            }
        } else {
            // No network
            self.baseAuthenticator.onNetworkDisconnected()
            self.connectAccountView.bringSubviewToFront(self.connectAccountView.networkErrorView)
            self.shouldAllowBack = true
            
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.showLoadView = true
    }
    
    override func didFinishPageNavigation(url: URL?) {
        print("!!!! didFinishPageNavigation :: ",url?.absoluteString)
    }
    
    override func didStartPageNavigation(url: URL?) {
        print("!!!! didStartPageNavigation",url?.absoluteString)
    }
    
    override func didFailPageNavigation(for url: URL?, withError error: Error) {
        if  url != nil{
            print("@@@@ didFailPageNavigation",url!,error)
        }
        self.didReceiveLoginChallenge(error: Strings.ErrorOnWebViewLoading)
    }
    
    override func loadWebContent() {
        webClient.loadUrl(url: baseURL)
        self.networkReconnct = true
        self.connectAccountView.bringSubviewToFront(self.connectAccountView.progressView)
        self.connectAccountView.progressView.progress = 1/3
        self.connectAccountView.progressView.stepText = Utils.getString(key: Strings.Step1)
        self.shouldAllowBack = false
    }
    
    override func onTimerTriggered(action: String) {
        print("!!!! onTimerTriggered base class called ",action)
        if action == Actions.ForegroundHtmlScrapping {
            self.stopScrapping()
            self.onCompletion(isComplete: true)
        }
    }
  
    private func scrapeHtml() {
        var logEventAttributes:[String:String] = [EventConstant.OrderSource: OrderSource.Walmart.value,
                                                  EventConstant.OrderSourceID: account.userID,
                                                  EventConstant.PanelistID: account.panelistID]
        logEventAttributes[EventConstant.Status] = EventStatus.Success
        FirebaseAnalyticsUtil.logEvent(eventType: "ScrapeHtml_Called", eventAttributes: logEventAttributes)
        
        //Start html scrapping in the foreground
        self.publishProgress(steps: .scrape)
        self.backgroundScrapper = WalmartScrapper(webClient: self.webClient) { [weak self] result, error in
            guard let self = self else {return}
            let (completed, successType) = result
            DispatchQueue.main.async {
                self.backgroundScrapper.scraperListener = nil
                self.logEvent()
                self.timerHandler.stopTimer()
                self.timerHandler.removeCallbackListener()
                if completed {
                    if let successType = successType {
                        self.updateSuccessType(successType: successType)
                    }
                    self.onCompletion(isComplete: true)
                    
                    UserDefaults.standard.setValue(0, forKey: Strings.KrogerOnNumberOfCaptchaRetry)
                    FirebaseAnalyticsUtil.logEvent(eventType: "ScrapeHtml_completed", eventAttributes: logEventAttributes)
                } else {
                    self.updateSuccessType(successType: .failureButAccountConnected)
                    self.onCompletion(isComplete: true)
                    FirebaseAnalyticsUtil.logEvent(eventType: "ScrapeHtml_failed", eventAttributes: logEventAttributes)
                }
                self.publishProgress(steps: .complete)
            }
        }
        backgroundScrapper.scraperListener = self
        backgroundScrapper.scrappingMode = .Foreground
        if let fetchRequestSource = self.fetchRequestSource {
            backgroundScrapper.fetchRequestSource = fetchRequestSource
        }
        if let account = self.account {
            backgroundScrapper.startScrapping(account: account)
        }
    }
    func stopScrapping() {
        DispatchQueue.main.async {
            if self.backgroundScrapper != nil {
            self.backgroundScrapper.scraperListener = nil
            self.backgroundScrapper = nil
            }
            self.webClient.navigationDelegate = nil
            self.webClient.stopLoading()
        }
    }
    private func logEvent() {
        let eventLog = EventLogs(panelistId: self.account.panelistID, platformId:  self.account.userID, section: SectionType.connection.rawValue, type:  FailureTypes.authentication.rawValue, status: EventState.success.rawValue, message: AppConstants.fgScrappingCompleted, fromDate: nil, toDate: nil, scrappingType: ScrappingType.html.rawValue)
        _ = AmazonService.logEvents(eventLogs: eventLog, orderSource: self.account.source.value) { response, error in
            //TODO
        }
        
    }
    // MARK: - Public Methods
    
    func removeWebview() {
        self.webClient.navigationDelegate = nil
        DispatchQueue.main.async {
            self.webClient.stopLoading()
            self.webClient.removeFromSuperview()
        }
    }
    
    
    func publishProgress(steps: Steps) {
        let progressValue = Float(steps.rawValue) / AppConstants.steps
        self.connectAccountView.progress = CGFloat(progressValue)
        var stepMessage: String
        
        switch steps {
        case .authentication:
            stepMessage = Utils.getString(key: Strings.Step1)
        case .scrape:
            stepMessage = Utils.getString(key: Strings.Step2)
        case .complete:
            stepMessage = Utils.getString(key: Strings.Step3)
        }
        
        self.connectAccountView.progressView.stepText = stepMessage
        self.shouldAllowBack = false
        self.connectAccountView.bringSubviewToFront(self.connectAccountView.progressView)
        if steps == .complete {
            self.onCompletion(isComplete: true)
        }
    }
    
    func onCompletion(isComplete: Bool) {
        DispatchQueue.main.async {
            if isComplete {
                self.connectAccountView.backButton.isHidden = true
                self.connectAccountView.connectAccountTitle.text = self.getHeaderTitle()
                self.connectAccountView.fetchSuccess = self.getSuccessMessage()
                self.connectAccountView.bringSubviewToFront(self.connectAccountView.successView)
                self.removeWebview()                
                self.timerHandler.stopTimer()
            }
        }
    }
    
    // MARK:- Private methods
    private func addUserAccountInDB() {
        let account = self.account  as! UserAccountMO
        let panelistId = LibContext.shared.authProvider.getPanelistID()
        CoreDataManager.shared.addAccount(userId: account.userID, password: account.password, accountStatus: AccountState.Connected.rawValue, orderSource: account.orderSource, panelistId: panelistId)
    }
    
    private func updateAccountStatusToConnected(orderStatus: String) {
        let userId = self.account.userID
        _ = AmazonService.updateStatus(platformId: userId,
                                       status: AccountState.Connected.rawValue,
                                       message: AppConstants.msgConnected,
                                       orderStatus: orderStatus, orderSource:  OrderSource.Walmart.value) { response, error in
        }
    }
    
    private func getHeaderTitle() -> String {
        let source = self.fetchRequestSource ?? .general
        if source == .manual {
            return String.init(format: Strings.HeaderFetchOrders, OrderSource.Walmart.value)
        } else {
            return Utils.getString(key: Strings.HeadingConnectWalmartAccount)
        }
    }
    
    private func getHeaderMessage() -> String {
        let source = self.fetchRequestSource ?? .general
        if source == .manual {
            return String.init(format: Strings.HeaderFetchingOrders, OrderSource.Walmart.value)
        } else {
            return Utils.getString(key: Strings.HeadingConnectingWalmartAccount)
        }
    }
    
    private func getSuccessMessage() -> String {
        let source = self.fetchRequestSource ?? .general
        if source == .manual {
            return String.init(format: Strings.FetchSuccessMessage, OrderSource.Walmart.value)
        } else {
            return AppConstants.walmartAccountConnectedSuccess
        }
    }
}

extension ConnectWalmartAccountVC: BSAuthenticaorDelegate {
    func didReceiveAuthenticationChallenge(authError: Bool) {
        if authError {
            self.timerHandler.stopTimer()
            self.webClient.isHidden = false
            self.view.bringSubviewToFront(self.webClient)
        } else {
            self.webClient.isHidden = true
            self.view.bringSubviewToFront(self.webClient)
        }
    }
    
    func didReceiveProgressChange(step: Steps) {
        self.publishProgress(steps: step)
    }
    
    func didReceiveLoginChallenge(error: String) {
        let userId = self.account.userID
        let isError: (Bool, String) = (true,error)
        LibContext.shared.webAuthErrorPublisher.send((isError.0, isError.1))
        WebCacheCleaner.clear(completionHandler: nil)
        self.dismiss(animated: true, completion: nil)
        var logEventAttributes:[String:String] = [EventConstant.OrderSource: OrderSource.Walmart.value,
                                                  EventConstant.OrderSourceID: userId]
        logEventAttributes[EventConstant.ErrorReason] = error
        logEventAttributes[EventConstant.Status] = EventStatus.Failure
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetectSignIn, eventAttributes: logEventAttributes)
        //Stop timer if user failed to login
        self.timerHandler.stopTimer()
    }
}

extension ConnectWalmartAccountVC: ScraperProgressListener   {
    func onWebviewError(isError: Bool) {
    }
    
    func updateProgressValue(progressValue: Float) {
    }
    
    func updateStepMessage(stepMessage: String) {
        self.connectAccountView.stepText = stepMessage
    }
    
    func updateProgressStep(htmlScrappingStep: HtmlScrappingStep) {
    }
    
    func updateSuccessType(successType: OrderFetchSuccessType) {
        self.successType = successType
    }
}
