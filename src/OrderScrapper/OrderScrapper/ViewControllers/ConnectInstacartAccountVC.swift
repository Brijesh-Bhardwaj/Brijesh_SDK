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
    private var isAuthenticationCompleted = false
    private var configurations: Configurations {
        Configurations(login: baseURL)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.connectAccountView?.connectAccountTitle.text = getHeaderTitle()
        self.connectAccountView?.headerText = getHeaderMessage(isUploadingPreviousOrder: false)
        self.baseAuthenticator = InstacartAuthenticator(webClient: self.webClient, delegate: self.webClientDelegate, scraperListener: self)
        self.shouldAllowBack = false
        self.baseAuthenticator?.authenticationDelegate = self
        self.publishProgress(step: .authentication)
//        webClient.isHidden = true
//        self.view.bringSubviewToFront(self.webClient)
        if self.fetchRequestSource == .manual {
            self.connectAccountView?.hideCancelScrapeBtn = false
        }
        LibContext.shared.timeoutType = TimeoutTypes.timeoutAuth.rawValue
        BSScriptFileManager.shared.getAuthenticationScripts(orderSource: .Instacart, isAuthScript: ScriptType.auth.rawValue) { response in
            if response {
                self.baseAuthenticator?.authenticate(account: self.account, configurations: self.configurations, scrapingMode: ScrapingMode.Foreground.rawValue) { authenticated, error in
                    if authenticated  {
                        self.publishProgress(step: .scrape)
                        if self.account.accountState == .NeverConnected {
                            let userId = self.account.userID
                            _ = AmazonService.registerConnection(platformId: userId, status: AccountState.ConnectionInProgress.rawValue, message: AppConstants.msgAccountConnected, orderStatus: OrderStatus.Initiated.rawValue, orderSource: OrderSource.Instacart.value) { response, error in
                                if let response = response  {
                                    self.timerHandler.stopTimer()
                                    self.account.accountState = .ConnectionInProgress
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
                                    if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
                                        self.handleServicesDown()
                                    } else {
                                        if self.networkReconnct {
                                            self.scrapeHtml()
                                            self.networkReconnct = false
                                        } else {
                                            self.didReceiveLoginChallenge(error: AppConstants.userAccountConnected)
                                            if let error = error {
                                                FirebaseAnalyticsUtil.logSentryError(error: error)
                                            }
                                            //Remove webview in case error occured while register so it won't reload in case of network off
                                            self.removeWebview()
                                        }
                                    }
                                }
                            }
                        } else {
                            if self.account.accountState != .Connected {
                                self.account.accountState = .ConnectionInProgress
                            }
                            self.updateAccountStatusToConnected(orderStatus: OrderStatus.Initiated.rawValue)
                            self.addUserAccountInDB()
                            
                            if self.fetchRequestSource == .manual {
                                self.getTimerValue { timerValue in
                                    self.timerHandler.startTimer(action: Actions.ForegroundHtmlScrapping, timerInterval: TimeInterval(timerValue))
                                    self.scrapeHtml()
                                }
                            } else {
                                self.timerHandler.startTimer(action: Actions.ForegroundHtmlScrapping)
                                self.scrapeHtml()
                            }
                            
                        }
                        //On authentication add user account details to DB
                    } else {
                        if let error = error {
                            self.didReceiveLoginChallenge(error: AppConstants.msgTimeout)
                            self.logEvents(message:error.errorMessage,failureType: TimeoutTypes.timeoutAuth.rawValue)
                            FirebaseAnalyticsUtil.logSentryError(error: ASLException(errorMessage: error.errorMessage, errorType: .authError))
                        } else {
                            self.didReceiveLoginChallenge(error: Strings.ErrorOnWebViewLoading)
                            self.logEvents(message: Strings.ErrorOnWebViewLoading,failureType: TimeoutTypes.timeoutAuth.rawValue)
                            FirebaseAnalyticsUtil.logSentryError(error: ASLException(errorMessage: Strings.ErrorOnWebViewLoading, errorType: .authError))
                        }
                        self.webClient.stopLoading()
                        self.baseAuthenticator?.onNetworkDisconnected()
                    }
                }
            } else {
                self.didReceiveLoginChallenge(error: AppConstants.authScriptNotFound)
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
            self.baseAuthenticator?.onNetworkDisconnected()
            self.connectAccountView?.backButton.isHidden = false
            self.connectAccountView?.bringSubviewToFront(self.connectAccountView.networkErrorView)
            self.shouldAllowBack = true
            self.webClient.stopLoading()
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
        print("$$$ loadWebContent called")
        webClient?.loadUrl(url: self.configurations.login)
        self.networkReconnct = true
        self.connectAccountView?.bringSubviewToFront(self.connectAccountView.progressView)
        self.connectAccountView?.progressView.progress = 1/3
        self.connectAccountView?.progressView.stepText = Utils.getString(key: Strings.Step1)
        self.shouldAllowBack = false
    }
    
    override func onTimerTriggered(action: String) {
        if action == Actions.ForegroundHtmlScrapping {
            self.isTimeOut = true
//            self.updateSuccessType(successType: .failureButAccountConnected)
            let orderState = UserDefaults.standard.string(forKey: Strings.OrderStateInstacart)
            if orderState == AppConstants.Completed {
                self.account.accountState = .Connected
            }
            
            if self.fetchRequestSource == .manual {
                showScrapeAgainView()
            } else {
                self.stopScrapping()
                self.onCompletion(isComplete: true)
            }
            
            _ = AmazonService.updateStatus(platformId: self.account.panelistID,
                                           status: self.account.accountState.rawValue,
                                           message: AppConstants.msgTimeout,
                                           orderStatus: OrderStatus.Failed.rawValue,
                                           orderSource: self.account.source.value) { response, error in
                if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
                    self.handleServicesDown()
                }
            }
            chooseTimeoutOption()
            //self.logEvents(logEvents: eventLogs)
        }
    }
    
    private func chooseTimeoutOption(){
        if(isAuthenticationCompleted){
            self.logEvents(message: AppConstants.msgTimeout, failureType: LibContext.shared.timeoutType)
        }else{
            self.logEvents(message: AppConstants.msgTimeout, failureType: TimeoutTypes.timeoutAuth.rawValue)
        }
    }
    
    private func logEvents(message: String,failureType:String) {
        let eventLogs = EventLogs(panelistId: self.account.panelistID, platformId:self.account.userID, section: SectionType.connection.rawValue, type: failureType, status: EventState.fail.rawValue, message: message, fromDate: nil, toDate: nil, scrapingType: ScrappingType.html.rawValue, scrapingContext: ScrapingMode.Foreground.rawValue,url: self.webClient.url?.absoluteString)
        _ = AmazonService.logEvents(eventLogs: eventLogs, orderSource: self.account.source.value) { response, error in
            if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
                self.handleServicesDown()
            }
        }
    }
    
    override func stopScrapping() {
        DispatchQueue.main.async {
            if self.backgroundScrapper != nil {
                self.backgroundScrapper.scraperListener = nil
                self.backgroundScrapper = nil
                }
            self.webClient?.navigationDelegate = nil
            DispatchQueue.main.async {
                self.webClient?.stopLoading()
            }
        }
    }
    
    // MARK: - Public Methods
    
    func removeWebview() {
        self.webClient?.navigationDelegate = nil
        DispatchQueue.main.async {
            self.webClient?.stopLoading()
            self.webClient?.removeFromSuperview()
        }
    }
    
    func publishProgress(step: Steps) {
        let progressValue = Float(step.rawValue) / AppConstants.steps
        self.connectAccountView?.progress = CGFloat(progressValue)
        
        var stepMessage: String
        
        switch step {
        case .authentication:
            stepMessage = Utils.getString(key: Strings.Step1)
            
        case .scrape:
            stepMessage = Utils.getString(key: Strings.Step2)
            
        case .complete:
            stepMessage = Utils.getString(key: Strings.Step3)
        }
        
        self.connectAccountView?.progressView.stepText = stepMessage
        self.connectAccountView?.bringSubviewToFront(self.connectAccountView.progressView)
        
        if step == .complete {
            onCompletion(isComplete: true)
        }
    }
    
    func onCompletion(isComplete: Bool) {
        DispatchQueue.main.async {
            if isComplete {
                self.webClient.isHidden = false
                self.view.bringSubviewToFront(self.webClient)
                if self.fetchRequestSource == .manual || self.fetchRequestSource == .notification {
                    if self.hasNetwork() {
                        self.connectAccountView?.backButton.isHidden = true
                        self.connectAccountView?.connectAccountTitle.text = self.getHeaderTitle()
                        self.connectAccountView?.successView.hideOkButton = false
                        self.connectAccountView?.successView.hideCancelButton = true
                        self.connectAccountView?.successView.hideContinueButton = true
                        self.connectAccountView.successView.successIncentiveMessage = ""
                        self.connectAccountView?.fetchSuccess = self.getSuccessMessage()
                        if let statusImage = self.getStatusImage() {
                            self.connectAccountView?.statusImage = statusImage
                        }
                        self.showSuccessScreen()
                        self.removeWebview()
                        self.timerHandler.stopTimer()
                    } else {
                        self.connectAccountView.scrapePercentage = ""
                        self.timerHandler.stopTimer()
                        self.baseAuthenticator?.onNetworkDisconnected()
                        self.connectAccountView?.bringSubviewToFront(self.connectAccountView.networkErrorView)
                        self.shouldAllowBack = true
                        self.webClient.stopLoading()
                    }
                } else {
                    self.sendSuccessCallBack()
                    self.removeWebview()
                    self.timerHandler.stopTimer()
                }
            }
        }
    }
    
    // MARK: - Private Methods
    private func addUserAccountInDB() {
        let account = self.account  as! UserAccount
        let panelistId = LibContext.shared.authProvider.getPanelistID()
        CoreDataManager.shared.addAccount(userId: account.userID, password: account.password, accountStatus: self.account.accountState.rawValue, orderSource: account.orderSource, panelistId: panelistId)
    }
    
    private func updateAccountStatusToConnected(orderStatus: String) {
        let userId = self.account.userID
        _ = AmazonService.updateStatus(platformId: userId,
                                       status: self.account.accountState.rawValue,
                                       message: AppConstants.msgConnected,
                                       orderStatus: orderStatus, orderSource:  OrderSource.Instacart.value) { response, error in
            if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
                self.handleServicesDown()
            }
        }
    }
    
    private func scrapeHtml() {
        isAuthenticationCompleted = true
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
                self.backgroundScrapper?.stopScrapping()
                self.backgroundScrapper?.scraperListener = nil
                self.backgroundScrapper = nil
                self.isTimeOut = false
                if completed {
                    if let successType = successType {
                        self.updateSuccessType(successType: successType)
                    }
                    UserDefaults.standard.setValue(0, forKey: Strings.InstacartOnNumberOfCaptchaRetry)
                    
                } else {
                    self.updateSuccessType(successType: .failureButAccountConnected)
                }
                UserDefaults.standard.setValue("", forKey: Strings.OrderStateInstacart)
                self.onCompletion(isComplete: true)
            }
        }
        backgroundScrapper?.scraperListener = self
        backgroundScrapper?.scrappingMode = .Foreground
        if let fetchRequestSource = self.fetchRequestSource {
            backgroundScrapper?.fetchRequestSource = fetchRequestSource
        }
        if let account = self.account {
            backgroundScrapper?.startScrapping(account: account)
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
    
    private func getHeaderMessage(isUploadingPreviousOrder: Bool) -> String {
        let source = self.fetchRequestSource ?? .general
        if source == .manual {
            if isUploadingPreviousOrder {
                return String.init(format: Strings.HeaderFetchingPendingOrders, OrderSource.Instacart.value)
            } else {
                return String.init(format: Strings.HeaderFetchingOrders, OrderSource.Instacart.value)
            }
        } else {
            return Utils.getString(key: Strings.HeadingConnectingInstacartAccount)
        }
    }
    
    private func getSuccessMessage() -> String {
        let source = self.fetchRequestSource ?? .general
        if source == .manual {
            if  isTimeOut  {
                return LibContext.shared.manualScrapeTimeOutMessage
            } else if successType == .failureButAccountConnected || successType == .fetchSkipped {
                return String.init(format: Strings.FetchFailureMessage, OrderSource.Instacart.value)
            } else {
                return LibContext.shared.manualScrapeSuccess
            }
        } else {
            return AppConstants.instacartAccountConnectedSuccess
        }
    }
    
    private func getStatusImage() -> UIImage? {
        let source = self.fetchRequestSource ?? .general
        if source == .manual {
            if isTimeOut  {
                return Utils.getImage(named: IconNames.SuccessScreen)
            } else if  successType == .failureButAccountConnected || successType == .fetchSkipped {
                return Utils.getImage(named: IconNames.FailureScreen)
            } else if isTimeOut {
                return Utils.getImage(named: IconNames.SuccessScreen)
            } else {
                return Utils.getImage(named: IconNames.SuccessScreen)
            }
         
        } else {
            return Utils.getImage(named: IconNames.SuccessScreen)
        }
    }
    
    private func handleServicesDown() {
        self.webClient?.stopLoading()
        let isError: (Bool, String) = (true,Strings.ErrorServicesDown)
        LibContext.shared.webAuthErrorPublisher.send((isError.0, isError.1))
        WebCacheCleaner.clear(completionHandler: nil)
        self.dismiss(animated: true, completion: nil)
        self.timerHandler.stopTimer()
        let error = ASLException(error: nil, errorMessage: Strings.ErrorServicesDown, failureType: .servicesDown)
        LibContext.shared.servicesStatusListener.onServicesFailure(exception: error)
    }
    
    private func showScrapeAgainView() {
        DispatchQueue.main.async {
        self.connectAccountView?.backButton.isHidden = true
        self.connectAccountView?.successView.hideOkButton = true
        self.connectAccountView?.successView.hideCancelButton = false
        self.connectAccountView?.successView.hideContinueButton = false
        self.connectAccountView.successView.successIncentiveMessage = ""
        self.connectAccountView?.connectAccountTitle.text = self.getHeaderTitle()
        self.connectAccountView?.fetchSuccess = self.getSuccessMessage()
        if let statusImage = self.getStatusImage() {
            self.connectAccountView?.statusImage = statusImage
        }
        self.connectAccountView?.bringSubviewToFront(self.connectAccountView.successView)
        self.timerHandler.stopTimer()
        }
    }
    
    override func reStartTimerForManualScraping() {
        print("####### reStartTimerForManualScraping")
        self.getTimerValue { timerValue in
            self.timerHandler.startTimer(action: Actions.ForegroundHtmlScrapping, timerInterval: TimeInterval(timerValue))
        }
    }
    
    private func showSuccessScreen() {
        if  successType == .failureButAccountConnected || successType == .fetchSkipped || isTimeOut {
            self.connectAccountView?.bringSubviewToFront(self.connectAccountView.successView)
        } else {
            self.connectAccountView.onlineSuccessView.successMessage.text = LibContext.shared.manualScrapeSuccess
            self.connectAccountView.onlineSuccessView.successNoteMessage.text = LibContext.shared.manualScrapeNote
            self.connectAccountView.onlineSuccessView.successHeader.text = "Congratulations!"
            self.connectAccountView.onlineSuccessView.okButton.setTitle("Great!", for: .normal)
            self.connectAccountView?.bringSubviewToFront(self.connectAccountView.onlineSuccessView)
        }
    }
}

extension ConnectInstacartAccountVC: BSAuthenticaorDelegate {
    func didReceiveAuthenticationChallenge(authError: Bool) {
        if authError {
            self.webClient?.isHidden = false
            self.view.bringSubviewToFront(self.webClient)
        } else {
            self.webClient?.isHidden = true
            self.view.bringSubviewToFront(self.webClient)
        }
    }
    
    func didReceiveProgressChange(step: Steps) {
        self.publishProgress(step: step)
        
    }
    
    func didReceiveLoginChallenge(error: String) {
        let userId = self.account.userID
        let isError: (Bool, String) = (true,error)
        self.webClient.stopLoading()
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
        self.connectAccountView?.stepText = stepMessage
    }
    
    func updateProgressStep(htmlScrappingStep: HtmlScrappingStep) {
        
    }
    
    func updateSuccessType(successType: OrderFetchSuccessType) {
        
        self.successType = successType
        
    }
    
    func onServicesDown(error: ASLException?) {
        self.handleServicesDown()
    }
    
    func updateScrapeProgressPercentage(value: Int) {
        DispatchQueue.main.async {
            self.connectAccountView.scrapePercentage = "\(value) %"
        }
    }
    
    func updateProgressHeaderLabel(isUploadingPreviousOrder: Bool) {
        DispatchQueue.main.async {
            self.connectAccountView?.progressView.headerText = self.getHeaderMessage(isUploadingPreviousOrder: isUploadingPreviousOrder)
        }
    }
}
