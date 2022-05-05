//
//  KrogerAuthenticator.swift
//  OrderScrapper

import Foundation
import WebKit

enum JSValuesInject {
    case click_Login_btn, sign_in, Continue_in_browser, error_email, flash_message, recaptcha, error_password
}

internal class KrogerAuthenticator: BSBaseAuthenticator {
    private let KrogerHomePage = "https://www.kroger.com/"
    private let KrogerOrderPage = "https://www.kroger.com/mypurchases"
    var isNetworkDisconnect = false
    
    func injectIdentificationJS() {
        self.addScriptListener()
        self.CheckValidationError()
    }
    override func onPageFinish(url: String) throws {
        print("#### Kroger Authenticator",url)
        if let configurations = configurations {
            if url.contains(configurations.login) {
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) { [weak self] in
                    self?.injectIdentificationJS()
                }
            } else if url == (KrogerHomePage) {
                DispatchQueue.main.async {
                    self.webClient.load(URLRequest(url: URL(string: self.KrogerOrderPage)!))
                }
            } else if url.contains(KrogerOrderPage) {
                if let completionHandler = self.completionHandler {
                    completionHandler(true, nil)
                } else {
                    self.completionHandler?(true, nil)
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
        print("#### onFailPageNavigation")
        self.completionHandler?(false,ASLException(errorMessage: error.localizedDescription, errorType: nil))
    }
    override func onNetworkDisconnected() {
        print("#### Network Diconnect Called")
        isNetworkDisconnect = true;
        self.webClient.scriptMessageHandler?.removeScriptMessageListener()
    }
    
    override func onTimerTriggered(action: String) {
            if action.contains(Actions.LoadingURl) {
                if self.listnerAdded {
                    self.webClient.scriptMessageHandler?.removeScriptMessageListener()
                }
                self.timerHandler.stopTimer()
                self.timerHandler.removeCallbackListener()
                DispatchQueue.main.async {
                    self.webClient.stopLoading()
                }
                self.authenticationDelegate?.didReceiveLoginChallenge(error: AppConstants.msgTimeout)
                
                if let panelistId = self.account?.panelistID, let userId = self.account?.userID {
                    let eventLogs = EventLogs(panelistId: panelistId, platformId: userId, section: SectionType.connection.rawValue, type: FailureTypes.authentication.rawValue, status: EventState.fail.rawValue, message: AppConstants.msgTimeout, fromDate: nil, toDate: nil, scrapingType: ScrappingType.html.rawValue, scrapingContext: ScrapingMode.Foreground.rawValue,url: webClient.url?.absoluteString)
                    self.logEvents(logEvents: eventLogs)
                }
            }
    }
    
    private func logEvents(logEvents: EventLogs) {
        if let orderSource = self.account?.source.value {
            _ = AmazonService.logEvents(eventLogs: logEvents, orderSource: orderSource) { response, error in
                if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
                    self.sendServicesDownCallback()
                }
            }
        }
    }
    
    override func isForegroundAuthentication() -> Bool {
        return true
    }
    
    func checkError() {
        let js = JSUtils.getKRCheckErrorJS()
        DispatchQueue.main.async {
            self.webClient.evaluateJavaScript(js) { [weak self] (response, error) in
                guard let self = self else {return}
                if let response = response as? String {
                    self.authenticationDelegate?.didReceiveLoginChallenge(error: response)
                    self.notifyAuthError(errorMessage: response)
                }
            }
        }
    }
    func checkError2() {
        let js = JSUtils.getKRCheckError2JS()
        DispatchQueue.main.async {
            self.webClient.evaluateJavaScript(js) { [weak self] (response, error) in
                guard let self = self else {return}
                if let response = response as? String {
                    self.authenticationDelegate?.didReceiveLoginChallenge(error: response)
                    self.notifyAuthError(errorMessage: response)
                }
            }
        }
    }
    func addScriptListener() {
        self.webClient.scriptMessageHandler?.addScriptMessageListener(listener: self)
        self.listnerAdded = true
        let userId = self.account?.userID
        var logEventAttributes:[String:String] = [EventConstant.OrderSource: OrderSource.Kroger.value,
                                                  EventConstant.OrderSourceID: userId ?? "" ]
        logEventAttributes[EventConstant.Status] = EventStatus.Failure
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSInjectUserName, eventAttributes: logEventAttributes)
        
    }
    func CheckValidationError() {
        let js = JSUtils.getKRIdentifyErrorJSAction()
        self.evaluateJS(javascript: js) { response, error in
            print("#### Check Username password error",response as Any, error as Any)
        }
    }
    func doSignIn() {
        guard let password = self.account?.userPassword else {
            print("#### password faield")
            self.completionHandler?(false, ASLException(errorMessage: Strings.ErrorPasswordIsNil, errorType: .authError))
            return
        }
        guard let email = self.account?.userID else {
            print("#### email faield")
            self.completionHandler?(false, ASLException(errorMessage: Strings.ErrorUserIdIsNil, errorType: .authError))
            return
        }
        
        let js = JSUtils.getKRSignInJS(email: email, password: password)
        self.evaluateJS(javascript: js) { response, error in
            if error != nil {
                self.authenticationDelegate?.didReceiveAuthenticationChallenge(authError: true)
            }else{
                print("#### Valid SignIn JS")
            }
        }
    }
    
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
            let userId = account?.userID
            _ = AmazonService.registerConnection(platformId: userId ?? "" ,
                                                 status: AccountState.NeverConnected.rawValue,
                                                 message: errorMessage, orderStatus: OrderStatus.None.rawValue, orderSource: OrderSource.Kroger.value) { response, error in
                if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
                    self.sendServicesDownCallback()
                }
            }
            let eventLog = EventLogs(panelistId: panelistId, platformId: userId ?? "", section: SectionType.connection.rawValue, type:  FailureTypes.authentication.rawValue, status: EventState.fail.rawValue, message: errorMessage, fromDate: nil, toDate: nil, scrapingType: nil, scrapingContext: ScrapingMode.Foreground.rawValue,url: webClient.url?.absoluteString)
            if let orderSource = account?.source.value {
                _ = AmazonService.logEvents(eventLogs: eventLog, orderSource: orderSource) { response, error in
                    if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
                        self.sendServicesDownCallback()
                    }
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
        let orderSource = account!.source.value
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
                try CoreDataManager.shared.updateUserAccount(userId: userId, accountStatus: AccountState.ConnectedButException.rawValue, panelistId: panelistId, orderSource: account!.source.rawValue)
            } catch let error {
                print(AppConstants.tag, "updateAccountWithExceptionState", error.localizedDescription)
            }
        case .ConnectedButScrappingFailed:
            status = AccountState.ConnectedButException.rawValue
            orderStatus = OrderStatus.Failed.rawValue
        case .ConnectionInProgress:
            print("")
        }
        _ = AmazonService.updateStatus(platformId: userId, status: status
                                       , message: message, orderStatus: orderStatus, orderSource:  OrderSource.Kroger.value) { response, error in
            if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
                self.sendServicesDownCallback()
            }
        }
        let eventLog = EventLogs(panelistId: panelistId, platformId: userId, section: SectionType.connection.rawValue, type:  FailureTypes.authentication.rawValue, status: EventState.fail.rawValue, message: message, fromDate: nil, toDate: nil, scrapingType: nil, scrapingContext: ScrapingMode.Foreground.rawValue,url: webClient.url?.absoluteString)
        _ = AmazonService.logEvents(eventLogs: eventLog, orderSource: orderSource) { response, error in
            if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
                self.sendServicesDownCallback()
            }
        }
    }
    private func sendServicesDownCallback() {
        if let scraperListener = scraperListener {
            scraperListener.onServicesDown(error: nil)
        }
    }
}

extension KrogerAuthenticator : ScriptMessageListener {
    func onScriptMessageReceive(message: WKScriptMessage) {
        print("######## onScriptMessageReceive ", message)
        if message.name == "iOS" {
            let data = message.body as! String
            print("######## MessageReceive ", data)
            if data.contains("pop up or ad blockers") {
                self.webClient.scriptMessageHandler?.removeScriptMessageListener()
                if let completionHandler = self.completionHandler {
                    completionHandler(false,ASLException(errorMessage: data, errorType: nil))
                }
            } else if data.contains("sign_in") {
                if !isNetworkDisconnect{
                    self.doSignIn()
                }else{
                    isNetworkDisconnect = false;
                    self.webClient.scriptMessageHandler?.removeScriptMessageListener()
                }
            } else {
                self.authenticationDelegate?.didReceiveLoginChallenge(error: data)
                self.notifyAuthError(errorMessage: data)
                self.webClient.scriptMessageHandler?.removeScriptMessageListener()
            }
        }
    }
}
