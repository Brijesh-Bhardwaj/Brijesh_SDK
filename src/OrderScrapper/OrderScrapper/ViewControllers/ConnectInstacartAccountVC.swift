//  ConnectInstacartAccountVC.swift
//  OrderScrapper

import Foundation
import UIKit
import WebKit
import Combine
import Network
import Sentry

enum Steps: Int16 {
    case authentication = 1
    case scrape = 2
    case complete = 3
}

class ConnectInstacartAccountVC: BaseAccountConnectVC {
    private let baseURL = "https://www.instacart.com/?return_to=http%3A%2F%2Fwww.instacart.com%2Fstore%2Faccount%2Forders"
    
    var loginView: LoginView!
    var backgroundScrapper: BSScrapper!
    private var showLoadView = false
    private var configurations: Configurations {
        Configurations(login: baseURL)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.connectAccountView.connectAccountTitle.text = getHeaderTitle()
        self.connectAccountView.headerText = getHeaderMessage()
        self.baseAuthenticator = InstacartAuthenticator(webClient: self.webClient, delegate: self.webClientDelegate)
        self.shouldAllowBack = false
        self.baseAuthenticator.authenticationDelegate = self
        self.publishProgress(step: .authentication)
        self.baseAuthenticator.authenticate(account: self.account, configurations: self.configurations) { authenticated, error in
            if authenticated  {
                self.publishProgress(step: .scrape)
                if self.account.accountState == .NeverConnected {
                    let userId = self.account.userID
                    _ = AmazonService.registerConnection(platformId: userId, status: AccountState.Connected.rawValue, message: AppConstants.msgAccountConnected, orderStatus: OrderStatus.Initiated.rawValue, orderSource: OrderSource.Instacart.value) { response, error in
                        if let response = response  {
                            self.timerHandler.stopTimer()
                            self.addUserAccountInDB()
                            self.account.isFirstConnectedAccount = response.firstaccount
                            var logConnectAccountEventAttributes:[String:String] = [:]
                            logConnectAccountEventAttributes = [EventConstant.OrderSource: OrderSource.Instacart.value,
                                                                EventConstant.OrderSourceID: self.account.userID,
                                                                EventConstant.Status: EventStatus.Connected]
                            FirebaseAnalyticsUtil.logEvent(eventType: EventType.AccountConnect, eventAttributes: logConnectAccountEventAttributes)
                            
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
                //On authentication add user account details to DB
            } else {
                //TODO :- need to review this
                self.didReceiveLoginChallenge(error: Strings.ErrorOnWebViewLoading)
            }
        }
        
    }
    
    //MARK:- Protected Methods
    override func onNetworkChange(isNetworkAvailable: Bool) {
        if isNetworkAvailable {
            //Network is available now
            if showLoadView {   
                self.loadWebContent()
            }
        } else {
            //No network
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
        if let url = url {
            print("@@@ didFinishPageNavigation",url)
        }
      
    }
    
    override func didStartPageNavigation(url: URL?) {
        //TODO - Add sentry meesage
        if let url = url {
        print("@@@ didStartPageNavigation called",url)
        }
    }
    
    override func didFailPageNavigation(for url: URL?, withError error: Error) {
        if  url != nil{
            print("@@@@ didFailPageNavigation",url!,error)
        }
        self.didReceiveLoginChallenge(error: Strings.ErrorOnWebViewLoading)
    }
    
    override func loadWebContent() {
        print("!!! loadWebContent called")
        webClient.loadUrl(url: self.configurations.login)
        self.networkReconnct = true
        self.connectAccountView.bringSubviewToFront(self.connectAccountView.progressView)
        self.connectAccountView.progressView.progress = 1/3
        self.connectAccountView.progressView.stepText = Utils.getString(key: Strings.Step1)
        self.shouldAllowBack = false
    }
    
    override func onTimerTriggered(action: String) {
        if action == Actions.ForegroundHtmlScrapping {
            self.stopScrapping()
            self.onCompletion(isComplete: true)
        }
    }
    
    func stopScrapping() {
        DispatchQueue.main.async {
            if self.backgroundScrapper != nil {
                self.backgroundScrapper.scraperListener = nil
                self.backgroundScrapper = nil
                }
            self.webClient.navigationDelegate = nil
            DispatchQueue.main.async {
                self.webClient.stopLoading()
            }
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
    
    func publishProgress(step: Steps) {
        let progressValue = Float(step.rawValue) / AppConstants.steps
        self.connectAccountView.progress = CGFloat(progressValue)
        
        var stepMessage: String
        
        switch step {
        case .authentication:
            stepMessage = Utils.getString(key: Strings.Step1)
            
        case .scrape:
            stepMessage = Utils.getString(key: Strings.Step2)
            
        case .complete:
            stepMessage = Utils.getString(key: Strings.Step3)
        }
        
        self.connectAccountView.progressView.stepText = stepMessage
        self.connectAccountView.bringSubviewToFront(self.connectAccountView.progressView)
        
        if step == .complete {
            onCompletion(isComplete: true)
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
            }
        }
    }
    
    // MARK: - Private Methods
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
                                       orderStatus: orderStatus, orderSource:  OrderSource.Instacart.value) { response, error in
        }
    }
    
    private func scrapeHtml() {
        var logEventAttributes:[String:String] = [EventConstant.OrderSource: OrderSource.Instacart.value,
                                                  EventConstant.OrderSourceID: account.userID,
                                                  EventConstant.PanelistID: account.panelistID]
        logEventAttributes[EventConstant.Status] = EventStatus.Success
        FirebaseAnalyticsUtil.logEvent(eventType: "ScrapeHtml_Called", eventAttributes: logEventAttributes)
        //Start html scrapping in the foreground
        self.backgroundScrapper = InstacartScrapper(webClient: self.webClient) { [weak self] result, error in
            guard let self = self else {return}
            let (completed, successType) = result
            DispatchQueue.main.async {
                self.timerHandler.stopTimer()
                self.timerHandler.removeCallbackListener()
                self.backgroundScrapper.scraperListener = nil
                self.logEvent()
                if completed {
                    if let successType = successType {
                        self.updateSuccessType(successType: successType)
                    }
                    UserDefaults.standard.setValue(0, forKey: Strings.InstacartOnNumberOfCaptchaRetry)
                } else {
                    self.updateSuccessType(successType: .failureButAccountConnected)
                }
                self.publishProgress(step: .complete)
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
    
    private func logEvent() {
        let eventLog = EventLogs(panelistId: self.account.panelistID, platformId:  self.account.userID, section: SectionType.connection.rawValue, type:  FailureTypes.authentication.rawValue, status: EventState.success.rawValue, message: AppConstants.fgScrappingCompleted, fromDate: nil, toDate: nil, scrappingType: ScrappingType.html.rawValue)
        _ = AmazonService.logEvents(eventLogs: eventLog, orderSource: self.account.source.value) { response, error in
            //TODO
        }
        
    }
    
    private func getHeaderTitle() -> String {
        let source = self.fetchRequestSource ?? .general
        if source == .manual {
            return String.init(format: Strings.HeaderFetchOrders, OrderSource.Instacart.value)
        } else {
            return Utils.getString(key: Strings.HeadingConnectInstacartAccount)
        }
    }
    
    private func getHeaderMessage() -> String {
        let source = self.fetchRequestSource ?? .general
        if source == .manual {
            return String.init(format: Strings.HeaderFetchingOrders, OrderSource.Instacart.value)
        } else {
            return Utils.getString(key: Strings.HeadingConnectingInstacartAccount)
        }
    }
    
    private func getSuccessMessage() -> String {
        let source = self.fetchRequestSource ?? .general
        if source == .manual {
            return String.init(format: Strings.FetchSuccessMessage, OrderSource.Instacart.value)
        } else {
            return AppConstants.instacartAccountConnectedSuccess
        }
    }
}

extension ConnectInstacartAccountVC: BSAuthenticaorDelegate {
    func didReceiveAuthenticationChallenge(authError: Bool) {
        if authError {
            self.webClient.isHidden = false
            self.view.bringSubviewToFront(self.webClient)
        } else {
            self.webClient.isHidden = true
            self.view.bringSubviewToFront(self.webClient)
        }
    }
    
    func didReceiveProgressChange(step: Steps) {
        self.publishProgress(step: step)
        
    }
    
    func didReceiveLoginChallenge(error: String) {
        let userId = self.account.userID
        let isError: (Bool, String) = (true,error)
        LibContext.shared.webAuthErrorPublisher.send((isError.0, isError.1))
        WebCacheCleaner.clear(completionHandler: nil)
        self.dismiss(animated: true, completion: nil)
        var logEventAttributes:[String:String] = [EventConstant.OrderSource: OrderSource.Instacart.value,
                                                  EventConstant.OrderSourceID: userId]
        logEventAttributes[EventConstant.ErrorReason] = error
        logEventAttributes[EventConstant.Status] = EventStatus.Failure
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetectSignIn, eventAttributes: logEventAttributes)
        
    }
}

extension  ConnectInstacartAccountVC: ScraperProgressListener   {
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
