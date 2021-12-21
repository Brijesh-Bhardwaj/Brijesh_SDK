//  WalmartAuthenticator.swift
//  OrderScrapper

import Foundation
import WebKit

internal class WalmartAuthenticator: BSBaseAuthenticator {
    private let LoginURLDelimiter = "/"
    private let WalmartHomePage = "https://www.walmart.com/"
    private let WalmartOrderPage = "https://www.walmart.com/orders"
    private let URLLoadingTime = 20.0
    var count = 0
    var timer: Timer? = nil
    var retryCount = 0
    var pageLoadRetryCount = 0
    
    override func onPageFinish(url: String) throws {
        print("#### walmart",url)
        if let configurations = configurations {
            if url.contains(configurations.login) {
                self.injectWalmartAuthentication()
            } else if url.contains(WalmartOrderPage) {
                if let completionHandler = self.completionHandler {
                    completionHandler(true, nil)
                } else {
                    self.completionHandler?(true, nil)
                }
                self.timerHandler.stopTimer()
                var logConnectAccountEventAttributes:[String:String] = [:]
                logConnectAccountEventAttributes = [EventConstant.OrderSource: String(OrderSource.Walmart.rawValue),
                                                    EventConstant.OrderSourceID: account!.userID,
                                                    EventConstant.Status: EventStatus.Connected]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.AccountConnect, eventAttributes: logConnectAccountEventAttributes)
            } else if url.contains(WalmartHomePage) {
                DispatchQueue.main.async {
                    self.webClient.load(URLRequest(url: URL(string: self.WalmartOrderPage)!))
                }
            }
        } else {
            let error = ASLException(errorMessage: Strings.ErrorNoConfigurationsFound, errorType: .authChallenge)
            if let completionHandler = self.completionHandler {
                completionHandler(false, error)
            } else {
                self.completionHandler?(false, error)
            }
            FirebaseAnalyticsUtil.logSentryMessage(message: Strings.ErrorNoConfigurationsFound)
        }
    }
    
    override func onStartPageNavigation(url: String) {
        
    }
    
    override func onFailPageNavigation(for url: String, withError error: Error) {
        print("#### onFailPageNavigation",error.localizedDescription, url)
        if pageLoadRetryCount > 1{
            // Stop timer and webpage loading after second time failed
            DispatchQueue.main.async {
                self.webClient.stopLoading()
            }
            self.timerHandler.stopTimer()
            self.timerHandler.removeCallbackListener()
            self.completionHandler?(false,ASLException(errorMessage: error.localizedDescription, errorType: nil))
        }else{
            //Reload webpage if it's failed to load first time
            DispatchQueue.main.async {
                self.webClient.load(URLRequest(url: URL(string: url)!))
            }
            pageLoadRetryCount = pageLoadRetryCount + 1
            self.timerHandler.stopTimer()
            self.timerHandler.startTimer(action: Actions.BaseURLLoading, timerInterval: TimeInterval(URLLoadingTime))
            retryCount = retryCount + 1
        }
    }
    
    override func onNetworkDisconnected() {
        print("$$$ onNetworkDisconnected called ")
        self.webClient.scriptMessageHandler?.removeScriptMessageListener()
    }
    
    override func onTimerTriggered(action: String) {
        if action.contains(Actions.BaseURLLoading) {
            if retryCount <= 1 {
                FirebaseAnalyticsUtil.logSentryMessage(message: "#### onTimerTriggered \(action)" )
                print("#### onTimerTriggered \(action)")
                DispatchQueue.main.async {
                    self.webClient.stopLoading()
                    self.webClient.reload()
                }
                self.timerHandler.stopTimer()
                self.timerHandler.startTimer(action: Actions.BaseURLLoading, timerInterval: TimeInterval(URLLoadingTime))
                retryCount = retryCount + 1
            } else  {
                FirebaseAnalyticsUtil.logSentryMessage(message: "onTimerTriggered \(action)")
                self.injectWalmartAuthentication()
                self.timerHandler.startTimer(action: Actions.DoingAuthentication, timerInterval: TimeInterval(URLLoadingTime))
            }
        } else if action.contains(Actions.DoingAuthentication) {
            FirebaseAnalyticsUtil.logSentryMessage(message: "##### onTimerTriggered \(action)" )
            DispatchQueue.main.async {
                self.webClient.stopLoading()
                if let url = URL(string: self.WalmartOrderPage) {
                    self.webClient.load(URLRequest(url: url))
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) { [weak self] in
                guard let self = self else {return}
                if let completionHandler = self.completionHandler {
                    completionHandler(true, nil)
                }
            }
        } else {
            if self.listnerAdded {
                self.webClient.scriptMessageHandler?.removeScriptMessageListener()
            }
            DispatchQueue.main.async {
                self.webClient.stopLoading()
            }
            self.timerHandler.stopTimer()
            self.timerHandler.removeCallbackListener()
            self.authenticationDelegate?.didReceiveLoginChallenge(error: AppConstants.msgTimeout)
            
            if let panelistId = self.account?.panelistID, let userId = self.account?.userID {
                let eventLogs = EventLogs(panelistId: panelistId, platformId: userId, section: SectionType.connection.rawValue, type: FailureTypes.authentication.rawValue, status: EventState.fail.rawValue, message: AppConstants.msgTimeout, fromDate: nil, toDate: nil, scrapingType: ScrappingType.html.rawValue, scrapingContext: ScrapingMode.Foreground.rawValue)
                self.logEvents(logEvents: eventLogs)
            }
        }
    }
    
    private func logEvents(logEvents: EventLogs) {
        if let orderSource = self.account?.source.value {
            _ = AmazonService.logEvents(eventLogs: logEvents, orderSource: orderSource) { response, error in
                //TODO
            }
        }
    }
    
    override func isForegroundAuthentication() -> Bool {
        return true
    }
    
    // MARK:- Public Methods
    
    func injectWalmartAuthentication() {
        FirebaseAnalyticsUtil.logSentryMessage(message: "injectWalmartAuthentication called")
        self.addScriptListener()
        self.getIdentificationJS()
    }
    
    func getIdentificationJS() {
        self.authenticationDelegate?.didReceiveProgressChange(step: .authentication)
        guard let password = self.account?.userPassword else {
            self.completionHandler?(false, ASLException(errorMessage: Strings.ErrorPasswordIsNil, errorType: .authError))
            return
        }
        guard let email = self.account?.userID else {
            self.completionHandler?(false, ASLException(errorMessage: Strings.ErrorUserIdIsNil, errorType: .authError))
            return
        }
        let js = JSUtils.getWalmartIdentificationJS(email: email, password: password)
        self.evaluateJS(javascript: js) { response, error in
            print("$$$$$ getIdentificationJS",response)
        }
    }
    
    func addScriptListener() {
        self.webClient.scriptMessageHandler?.addScriptMessageListener(listener: self)
        self.listnerAdded = true
        if let userId = self.account?.userID {
        var logEventAttributes:[String:String] = [EventConstant.OrderSource: OrderSource.Walmart.value,
                                                      EventConstant.OrderSourceID: userId]
            logEventAttributes[EventConstant.Status] = EventStatus.Success
            FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSListnerAdded, eventAttributes: logEventAttributes)
        }
        
        
    }
    func checkError() {
        print("@@@@ check error called")
        let js = JSUtils.getWACheckErrorJS()
        self.evaluateJS(javascript: js) { response, error in
            if let response = response as? String {
                // TODO: check for the response
                self.timerHandler.stopTimer()
                self.authenticationDelegate?.didReceiveLoginChallenge(error: response)
                self.notifyAuthError(errorMessage: response)
                self.webClient.scriptMessageHandler?.removeScriptMessageListener()
            } else {
                self.timerHandler.stopTimer()
                self.webClient.scriptMessageHandler?.removeScriptMessageListener()
                self.completionHandler?(false,ASLException(errorMessage: Strings.ErrorInInjectingScript, errorType: .authError))
            }
        }
    }
    
    // MARK:- Private methods
    
    private func evaluateJS(javascript: String, completionHandler: ((Any?, Error?) -> Void)? = nil) {
        DispatchQueue.main.async {
            self.webClient.evaluateJavaScript(javascript) { (response, error) in
                if error != nil {
                    //Error condition
                    completionHandler?(error, error)
                } else {
                    //Success condition
                    completionHandler?(response, error)
                }
            }
        }
    }
    
    private func notifyAuthError(errorMessage: String) {
        let panelistId = LibContext.shared.authProvider.getPanelistID()
        let accountState = account?.accountState.rawValue
        if accountState == AccountState.NeverConnected.rawValue {
            
            if let userId = account?.userID, let orderSource = account?.source.value {
                _ = AmazonService.registerConnection(platformId: userId,
                                                     status: AccountState.NeverConnected.rawValue,
                                                     message: errorMessage, orderStatus: OrderStatus.None.rawValue, orderSource: OrderSource.Walmart.value) { response, error in
                    //TODO
                }
                let eventLog = EventLogs(panelistId: panelistId, platformId: userId, section: SectionType.connection.rawValue, type:  FailureTypes.authentication.rawValue, status: EventState.fail.rawValue, message: errorMessage, fromDate: nil, toDate: nil, scrapingType: nil, scrapingContext: ScrapingMode.Foreground.rawValue)
                _ = AmazonService.logEvents(eventLogs: eventLog, orderSource: orderSource) { response, error in
                    //TODO
                }
            }
           
        } else {
            self.updateAccountWithExceptionState(message: AppConstants.msgAuthError)
        }
        WebCacheCleaner.clear(completionHandler: nil)
    }
    private func updateAccountWithExceptionState(message: String) {
        let userId = account!.userID
        let panelistId = LibContext.shared.authProvider.getPanelistID()
        let accountState = account!.accountState
        let orderSource = account!.source
        var status: String = ""
        var orderStatus: String = ""
        
        switch accountState {
        case .NeverConnected:
            status = AccountState.NeverConnected.rawValue
            orderStatus = OrderStatus.None.rawValue
        case .ConnectedButException, .ConnectedAndDisconnected, .Connected:
            status = AccountState.ConnectedButException.rawValue
            orderStatus = OrderStatus.None.rawValue
            do {
                try CoreDataManager.shared.updateUserAccount(userId: userId, accountStatus: AccountState.ConnectedButException.rawValue, panelistId: panelistId, orderSource: orderSource.rawValue)
            } catch let error {
                print(AppConstants.tag, "updateAccountWithExceptionState", error.localizedDescription)
                FirebaseAnalyticsUtil.logSentryError(error: error)
            }
        case .ConnectedButScrappingFailed:
            status = AccountState.ConnectedButException.rawValue
            orderStatus = OrderStatus.Failed.rawValue
        case .ConnectionInProgress:
            print("")
        }
        _ = AmazonService.updateStatus(platformId: userId, status: status
                                       , message: message, orderStatus: orderStatus, orderSource:  OrderSource.Walmart.value) { response, error in
            //Todo
        }
        let eventLog = EventLogs(panelistId: panelistId, platformId: userId, section: SectionType.connection.rawValue, type:  FailureTypes.authentication.rawValue, status: EventState.fail.rawValue, message: message, fromDate: nil, toDate: nil, scrapingType: nil, scrapingContext: ScrapingMode.Foreground.rawValue)
        _ = AmazonService.logEvents(eventLogs: eventLog, orderSource: orderSource.value) { response, error in
            //TODO
        }
    }
}

extension WalmartAuthenticator: ScriptMessageListener {
    func onScriptMessageReceive(message: WKScriptMessage) {
            print("######## onScriptMessageReceive ", message)
            if message.name == "iOS" {
                let data = message.body as! String
                print("######## MessageReceive ", data)
                if data.contains("Validation error is shown") {
                    print("#### Validation error is shown")
                    self.checkError()
                    var logEventAttributes:[String:String] = [EventConstant.OrderSource: OrderSource.Walmart.value,
                                                              EventConstant.OrderSourceID: account!.userID]
                    logEventAttributes[EventConstant.Status] = EventStatus.Failure
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetectSignIn, eventAttributes: logEventAttributes)
                } else if data.contains("verify_identity") {
                    self.timerHandler.stopTimer()
                    self.authenticationDelegate?.didReceiveAuthenticationChallenge(authError: true)
                    var logEventAttributes:[String:String] = [EventConstant.OrderSource: OrderSource.Walmart.value,
                                                              EventConstant.OrderSourceID: account!.userID]
                    logEventAttributes[EventConstant.Status] = EventStatus.Success
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetectedCaptcha, eventAttributes: logEventAttributes)
                }else if data.contains("sign_in") {
                    print("##### sign_in")
                    var logEventAttributes:[String:String] = [EventConstant.OrderSource: OrderSource.Walmart.value,
                                                              EventConstant.OrderSourceID: account!.userID]
                    logEventAttributes[EventConstant.Status] = EventStatus.Success
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetectSignIn, eventAttributes: logEventAttributes)
                } else if data.contains("Captcha is open") {
                    print("#### Captcha is open")
                    self.timerHandler.stopTimer()
                    self.authenticationDelegate?.didReceiveAuthenticationChallenge(authError: true)
                    var logEventAttributes:[String:String] = [EventConstant.OrderSource: OrderSource.Walmart.value,
                                                              EventConstant.OrderSourceID: account!.userID]
                    logEventAttributes[EventConstant.Status] = EventStatus.Success
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetectedCaptcha, eventAttributes: logEventAttributes)
                } else if data.contains("Captcha is closed") {
                    print("#### Captcha is closed")
                    self.authenticationDelegate?.didReceiveLoginChallenge(error: Strings.authenticationFailed)
                    self.notifyAuthError(errorMessage: Strings.authenticationFailed)
                }
            }
        }
}
