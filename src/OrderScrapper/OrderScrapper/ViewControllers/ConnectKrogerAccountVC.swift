//
//  ConnectKrogerAccountVC.swift
//  OrderScrapper

import Foundation
import UIKit
import WebKit
import Combine
import Network
import Sentry

class ConnectKrogerAccountVC: BaseAccountConnectVC {
    private let baseURL = "https://www.kroger.com/signin?redirectUrl=%2Fmypurchases"
    var loginView: LoginView!
    var backgroundScrapper: BSScrapper!
    private var showLoadView = false
    private var configurations: Configurations {
        Configurations(login: "https://www.kroger.com/signin")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.connectAccountView.connectAccountTitle.text = getHeaderTitle()
        self.connectAccountView.progressView.headerText = getHeaderMessage()
        self.shouldAllowBack = false
        self.baseAuthenticator = KrogerAuthenticator(webClient: self.webClient, delegate: self.webClientDelegate)
        self.baseAuthenticator.authenticationDelegate = self
        self.publishProgress(step: .authentication)
        self.baseAuthenticator.authenticate(account: self.account, configurations: self.configurations) { authenticated, error in
            if authenticated  {
                self.publishProgress(step: .scrape)
                if self.account.accountState == .NeverConnected {
                    let userId = self.account.userID
                    _ = AmazonService.registerConnection(platformId: userId, status: AccountState.Connected.rawValue, message: AppConstants.msgAccountConnected, orderStatus: OrderStatus.Initiated.rawValue, orderSource: OrderSource.Kroger.value) { response, error in
                        if let response = response  {
                            self.timerHandler.stopTimer()
                            self.account.accountState = .Connected
                            self.addUserAccountInDB()
                            self.account.isFirstConnectedAccount = response.firstaccount
                            var logConnectAccountEventAttributes:[String:String] = [:]
                            logConnectAccountEventAttributes = [EventConstant.OrderSource: OrderSource.Kroger.value,
                                                                EventConstant.OrderSourceID: self.account.userID,
                                                                EventConstant.Status: EventStatus.Connected]
                            FirebaseAnalyticsUtil.logEvent(eventType: EventType.AccountConnect, eventAttributes: logConnectAccountEventAttributes)
                            self.timerHandler.startTimer(action: Actions.ForegroundHtmlScrapping)
                            self.scrapeHtml()
                        } else {
                            if self.networkReconnct {
                                self.scrapeHtml()
                                self.networkReconnct = false
                            } else {
                                self.didReceiveLoginChallenge(error: AppConstants.userAccountConnected)
                                if let error = error {
                                    FirebaseAnalyticsUtil.logSentryError(error: error)
                                }
                            }
                        }
                    }
                } else {
                    self.account.accountState = .Connected
                    self.updateAccountStatusToConnected(orderStatus: OrderStatus.Initiated.rawValue)
                    self.addUserAccountInDB()
                    self.timerHandler.startTimer(action: Actions.ForegroundHtmlScrapping)
                    self.scrapeHtml()
                }
            }else {
                print("#### Auth ERROR",error as Any)
                if error!.errorMessage.contains("pop up or ad blockers"){
                    print("#### POP UP ERROR")
//                    self.webClient.loadUrl(url: self.configurations.listing)
                    if self.account.accountState == .NeverConnected {
                        let userId = self.account.userID
                        _ = AmazonService.registerConnection(platformId: userId, status: AccountState.Connected.rawValue, message: AppConstants.msgAccountConnected, orderStatus: OrderStatus.Failed.rawValue, orderSource: OrderSource.Kroger.value) { response, error in
                            if let response = response  {
                                self.account.accountState = .Connected
                                self.addUserAccountInDB()
                                self.account.isFirstConnectedAccount = response.firstaccount
                                self.publishProgress(step: .complete)
                            } else {
                                if self.networkReconnct {
                                    print("#### Network Reconnect")
                                    self.publishProgress(step: .complete)
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
                        print("#### Reconnect State")
                        self.account.accountState = .Connected
                        self.updateAccountStatusToConnected(orderStatus: OrderStatus.Initiated.rawValue)
                        self.addUserAccountInDB()
                        self.publishProgress(step: .complete)
                    }
                }else{
                    print("#### OTHRE ERROR")
                    //Stop webview in case other error occured so it won't reload in case of network off
                    self.didReceiveLoginChallenge(error: error!.errorMessage)
                    if let error = error {
                        FirebaseAnalyticsUtil.logSentryError(error: error)
                    }
                    self.removeWebview()
                }
            }
        }
    }
    
    //MARK:- Protected Methods
    override func onNetworkChange(isNetworkAvailable: Bool) {
        if isNetworkAvailable {
            print("#### Network available")
            //Network is available now
            if showLoadView {
                self.showLoadView = false
                self.loadWebContent()
            }
        } else {
            print("#### Network not available")
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
        print("@@@ didFinishPageNavigation",url!)
    }
    
    override func didStartPageNavigation(url: URL?) {
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
        print("#### loadWebContent called")
        self.networkReconnct = true;
        webClient.loadUrl(url: self.configurations.login)
        self.connectAccountView.bringSubviewToFront(self.connectAccountView.progressView)
        self.connectAccountView.progressView.progress = 1/3
        self.connectAccountView.progressView.stepText = Utils.getString(key: Strings.Step1)
        self.shouldAllowBack = false
    }
    
    override func onTimerTriggered(action: String) {
        if action == Actions.ForegroundHtmlScrapping {
            self.stopScrapping()
            self.onCompletion(isComplete: true)
            
            _ = AmazonService.updateStatus(platformId: self.account.panelistID,
                                           status: self.account.accountState.rawValue,
                                           message: AppConstants.msgTimeout,
                                           orderStatus: OrderStatus.Failed.rawValue,
                                           orderSource: self.account.source.value) { response, error in
            }
            
            let eventLogs = EventLogs(panelistId: self.account.panelistID, platformId:self.account.userID, section: SectionType.connection.rawValue, type: FailureTypes.timeout.rawValue, status: EventState.fail.rawValue, message: AppConstants.msgTimeout, fromDate: nil, toDate: nil, scrapingType: ScrappingType.html.rawValue, scrapingContext: ScrapingMode.Foreground.rawValue)
            self.logEvents(logEvents: eventLogs)
        }
    }
    
    private func logEvents(logEvents: EventLogs) {
        _ = AmazonService.logEvents(eventLogs: logEvents, orderSource: self.account.source.value) { response, error in
                //TODO
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
        self.shouldAllowBack = false
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
                self.connectAccountView.statusImage = self.getStatusImage()
                self.connectAccountView.bringSubviewToFront(self.connectAccountView.successView)
                self.removeWebview()
            }
        }
    }
    
    func removeWebview() {
        self.webClient.navigationDelegate = nil
        DispatchQueue.main.async {
            self.webClient.stopLoading()
            self.webClient.removeFromSuperview()
        }
    }
    // MARK: - Private Methods
    private func addUserAccountInDB() {
        let account = self.account  as! UserAccountMO
        let panelistId = LibContext.shared.authProvider.getPanelistID()
        CoreDataManager.shared.addAccount(userId: account.userID, password: account.password, accountStatus: self.account.accountState.rawValue, orderSource: account.orderSource, panelistId: panelistId)
    }
    
    private func updateAccountStatusToConnected(orderStatus: String) {
        let userId = self.account.userID
        _ = AmazonService.updateStatus(platformId: userId,
                                       status: self.account.accountState.rawValue,
                                       message: AppConstants.msgConnected,
                                       orderStatus: orderStatus, orderSource:  OrderSource.Kroger.value) { response, error in
        }
    }
    
    private func scrapeHtml() {
        var logEventAttributes:[String:String] = [EventConstant.OrderSource: OrderSource.Kroger.value,
                                                  EventConstant.OrderSourceID: account.userID,
                                                  EventConstant.PanelistID: account.panelistID]
        logEventAttributes[EventConstant.Status] = EventStatus.Success
        FirebaseAnalyticsUtil.logEvent(eventType: "ScrapeHtml_Called", eventAttributes: logEventAttributes)
        
        self.backgroundScrapper = KrogerScrapper(webClient: self.webClient) { [weak self] result, error in
            guard let self = self else {return}
            let (completed, successType) = result
            DispatchQueue.main.async {
                self.timerHandler.stopTimer()
                self.timerHandler.removeCallbackListener()
                self.backgroundScrapper.stopScrapping()
                self.backgroundScrapper.scraperListener = nil
                self.backgroundScrapper = nil
                self.logEvent()
                if completed {
                    if let successType = successType {
                        self.updateSuccessType(successType: successType)
                    }
                    self.onCompletion(isComplete: true)
                    UserDefaults.standard.setValue(0, forKey: Strings.KrogerOnNumberOfCaptchaRetry)
                } else {
                    self.updateSuccessType(successType: .failureButAccountConnected)
                    self.onCompletion(isComplete: true)
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
        let eventLog = EventLogs(panelistId: self.account.panelistID, platformId:  self.account.userID, section: SectionType.connection.rawValue, type:  FailureTypes.authentication.rawValue, status: EventState.success.rawValue, message: AppConstants.fgScrappingCompleted, fromDate: nil, toDate: nil, scrapingType: ScrappingType.html.rawValue, scrapingContext: ScrapingMode.Foreground.rawValue)
        _ = AmazonService.logEvents(eventLogs: eventLog, orderSource: self.account.source.value) { response, error in
            //TODO
        }
        
    }
    
    private func getHeaderTitle() -> String {
        let source = self.fetchRequestSource ?? .general
        if source == .manual {
            return String.init(format: Strings.HeaderFetchOrders, OrderSource.Kroger.value)
        } else {
            return Utils.getString(key: Strings.HeadingConnectKrogerAccount)
        }
    }
    
    private func getHeaderMessage() -> String {
        let source = self.fetchRequestSource ?? .general
        if source == .manual {
            return String.init(format: Strings.HeaderFetchingOrders, OrderSource.Kroger.value)
        } else {
            return Utils.getString(key: Strings.HeadingConnectingKrogerAccount)
        }
    }
    
    private func getSuccessMessage() -> String {
        let source = self.fetchRequestSource ?? .general
        if source == .manual {
            if successType == .failureButAccountConnected || successType == .fetchSkipped {
                return String.init(format: Strings.FetchFailureMessage, OrderSource.Kroger.value)
            } else {
                return String.init(format: Strings.FetchSuccessMessage, OrderSource.Kroger.value)
            }
        } else {
            return Utils.getString(key: Strings.KrogerAccountConnectedSuccessMsg)
        }
    }
    
    private func getStatusImage() -> UIImage {
        let source = self.fetchRequestSource ?? .general
        if source == .manual {
            if successType == .failureButAccountConnected || successType == .fetchSkipped {
                return Utils.getImage(named: IconNames.FailureScreen)!
            } else {
                return Utils.getImage(named: IconNames.SuccessScreen)!
            }
         
        } else {
            return Utils.getImage(named: IconNames.SuccessScreen)!
        }
    }
}

extension ConnectKrogerAccountVC: BSAuthenticaorDelegate {
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
        //TODO
        let userId = self.account.userID
        let isError: (Bool, String) = (true,error)
        LibContext.shared.webAuthErrorPublisher.send((isError.0, isError.1))
        WebCacheCleaner.clear(completionHandler: nil)
        self.dismiss(animated: true, completion: nil)
        var logEventAttributes:[String:String] = [EventConstant.OrderSource: OrderSource.Kroger.value,
                                                  EventConstant.OrderSourceID: userId]
        logEventAttributes[EventConstant.ErrorReason] = error
        logEventAttributes[EventConstant.Status] = EventStatus.Failure
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetectSignIn, eventAttributes: logEventAttributes)

    }
}

extension  ConnectKrogerAccountVC: ScraperProgressListener   {
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
