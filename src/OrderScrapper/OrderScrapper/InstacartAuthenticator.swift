//  InstacartAuthenticator.swift
//  OrderScrapper


import Foundation
import WebKit

internal class InstacartAuthenticator: BSBaseAuthenticator {
    private let LoginURLDelimiter = "/?"
    private let URLDelimiter = "/store"
    var isAuthenticated: Bool = false
    var isNetworkDisconnect = false
    
    override func onPageFinish(url: String) throws {
        print("####",url)
        if let configurations = configurations {
            self.authenticationDelegate?.didReceiveAuthenticationChallenge(authError: false)
                let loginSubURL = Utils.getSubUrl(url: configurations.login, delimeter: self.LoginURLDelimiter)
                // TODO -: Check the hardcoded URL
                let subURL = AppConstants.ICLoginSuccessURL
                
                if  url.contains(AppConstants.InstacartOnBoardingURL) {
                    self.webClient.scriptMessageHandler?.removeScriptMessageListener()
                } else if url.contains(subURL) {
                    print("@@ subURL",subURL)
                    self.webClient.scriptMessageHandler?.removeScriptMessageListener()
                    if let completionHandler = self.completionHandler {
                        completionHandler(true, nil)
                    } else {
                        self.completionHandler?(true, nil)
                    }
                } else if (url.contains(loginSubURL) || loginSubURL.contains(url)) {
                    self.onContinueBrowser()
                } else {
                    self.authenticationDelegate = nil
                    if let completionHandler = self.completionHandler {
                        completionHandler(true, nil)
                    } else {
                        self.completionHandler?(true, nil)
                    }
                    self.webClient.scriptMessageHandler?.removeScriptMessageListener()
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
        self.completionHandler?(false,ASLException(errorMessage: error.localizedDescription, errorType: nil))
    }
    
    override func onNetworkDisconnected() {
        self.isNetworkDisconnect = true
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
                let eventLogs = EventLogs(panelistId: panelistId, platformId: userId, section: SectionType.connection.rawValue, type: FailureTypes.authentication.rawValue, status: EventState.fail.rawValue, message: AppConstants.msgTimeout, fromDate: nil, toDate: nil, scrapingType: ScrappingType.html.rawValue, scrapingContext: ScrapingMode.Foreground.rawValue)
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
    
    func getIdentificationJS() {
        self.addScriptListener()
        let js = JSUtils.getInstacartIdentification()
        self.evaluateJS(javascript: js) { response, error in
            print("Idnetification JS",response)
        }
    }
    
    func onContinueBrowser() {
        let js = JSUtils.getICProcide()
        self.evaluateJS(javascript: js) { response, error in
            if response != nil {
                self.onLoginScript()
            } else {
                self.completionHandler?(false,ASLException(errorMessage: Strings.ErrorInInjectingScript, errorType: .authError))
            }
        }
    }
    
    func onSignIn() {
        print("$$$ signIn called")
        guard let password = self.account?.userPassword else {
            self.completionHandler?(false, ASLException(errorMessage: Strings.ErrorPasswordIsNil, errorType: .authError))
            return
        }
        guard let email = self.account?.userID else {
            self.completionHandler?(false, ASLException(errorMessage: Strings.ErrorUserIdIsNil, errorType: .authError))
            return
        }
        let js = JSUtils.getICinjectLoginJS(email: email, password: password)
        let userId = self.account?.userID
        var logEventAttributes:[String:String] = [EventConstant.OrderSource: OrderSource.Instacart.value,
                                                  EventConstant.OrderSourceID: userId ?? ""]
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) { [weak self] in
            guard let self = self else {return}
            self.evaluateJS(javascript: js) { respone, error in
                if let error = error {
                    FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
                } else {
                    print("### valid JS")
                }
            }
        }
        self.captchaClosed()
        logEventAttributes[EventConstant.Status] = EventStatus.Success
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetectSignIn, eventAttributes: logEventAttributes)
        
    }
    
    func onWrongCredentials() {
            let js = JSUtils.getInstacartWrongPasswordInjectJS()
            self.evaluateJS(javascript: js) { response, error in
            if let response = response as? String {
                self.authenticationDelegate?.didReceiveLoginChallenge(error: response)
                self.notifyAuthError(errorMessage: response)
                self.webClient.scriptMessageHandler?.removeScriptMessageListener()
            } else {
                if let error = error {
                    FirebaseAnalyticsUtil.logSentryError(error: error)
                }
                self.completionHandler?(false,ASLException(errorMessage: Strings.ErrorInInjectingScript, errorType: .authError))
            }
        }
       }
    func onLoginScript() {
        let userId = self.account?.userID
        let js = JSUtils.getICOnClick()
        self.evaluateJS(javascript: js) { response, error in
            if response != nil {
                self.getIdentificationJS()
            } else {
               if let error = error {
                    FirebaseAnalyticsUtil.logSentryError(error: error)
                }
                self.completionHandler?(false,ASLException(errorMessage: Strings.ErrorInInjectingScript, errorType: .authError))
            }
            
        }
        var logEventAttributes:[String:String] = [EventConstant.OrderSource: OrderSource.Instacart.value,
                                                  EventConstant.OrderSourceID: userId ?? ""]
        logEventAttributes[EventConstant.Status] = EventStatus.Success
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetected, eventAttributes: logEventAttributes)

    }
    
    func onErrorPassword() {
        let js = JSUtils.getICErrorPasswordInjectJS()
        self.evaluateJS(javascript: js) { response, error in
            if let response = response as? String {
                self.authenticationDelegate?.didReceiveLoginChallenge(error: response)
                self.notifyAuthError(errorMessage: response)
                self.webClient.scriptMessageHandler?.removeScriptMessageListener()
            } else {
                if let error = error {
                    FirebaseAnalyticsUtil.logSentryError(error: error)
                }
                self.completionHandler?(false,ASLException(errorMessage: Strings.ErrorInInjectingScript, errorType: .authError))
            }
        }
    }
    
    func onErrorEmail() {
        let js = JSUtils.getICErrorEmailInjectJS()
        self.evaluateJS(javascript: js) { response, error in
            if let response = response as? String  {
                self.authenticationDelegate?.didReceiveLoginChallenge(error: response)
                self.notifyAuthError(errorMessage: response)
                self.webClient.scriptMessageHandler?.removeScriptMessageListener()
            } else {
                if let error = error {
                    FirebaseAnalyticsUtil.logSentryError(error: error)
                }
                self.completionHandler?(false,ASLException(errorMessage: Strings.ErrorInInjectingScript, errorType: .authError))
            }
        }
    }
    
    func onRecaptcha() {
        // Handled on Sign in
    }
    
    func captchaClosed() {
        print("$$$$ captchaClosed called")
        let js = JSUtils.captchaClosed()
        self.evaluateJS(javascript: js) { response, error in
        }
    }
    
    func onFlashMessage() {
        let js = JSUtils.getICFlashMessage()
        self.evaluateJS(javascript: js) { response, error in
            if let response = response as? String {
                self.authenticationDelegate?.didReceiveLoginChallenge(error: response)
                self.webClient.scriptMessageHandler?.removeScriptMessageListener()
            } else {
                if let error = error {
                    FirebaseAnalyticsUtil.logSentryError(error: error)
                }
                self.completionHandler?(false,ASLException(errorMessage: Strings.ErrorInInjectingScript, errorType: .authError))
            }
        }
    }
    
    func verificationCodeSuccess() {
        let js = JSUtils.verificationCodeSuccess()
        self.evaluateJS(javascript: js) { response, error in
            print("verificationCodeSuccess",response)
        }

    }

    func authenticationChallenge() {
        let userId = self.account?.userID
        var logEventAttributes:[String:String] = [EventConstant.OrderSource: OrderSource.Instacart.value,
                                                  EventConstant.OrderSourceID: userId ?? ""]
        self.timerHandler.stopTimer()
        self.authenticationDelegate?.didReceiveAuthenticationChallenge(authError: true)
        self.verificationCodeSuccess()
        
        logEventAttributes[EventConstant.ErrorReason] = EventType.JSDetectedDeviceAuth
        logEventAttributes[EventConstant.Status] = EventStatus.Success
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetectedDeviceAuth, eventAttributes: logEventAttributes)
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
            _ = AmazonService.registerConnection(platformId: userId!,
                                                 status: AccountState.NeverConnected.rawValue,
                                                 message: errorMessage, orderStatus: OrderStatus.None.rawValue, orderSource: OrderSource.Instacart.value) { response, error in
                if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
                    self.sendServicesDownCallback()
                }
            }
            let eventLog = EventLogs(panelistId: panelistId, platformId: userId! , section: SectionType.connection.rawValue, type:  FailureTypes.authentication.rawValue, status: EventState.fail.rawValue, message: errorMessage, fromDate: nil, toDate: nil, scrapingType: nil, scrapingContext: ScrapingMode.Foreground.rawValue)
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
                FirebaseAnalyticsUtil.logSentryError(error: error)
            }
        case .ConnectedButScrappingFailed:
            status = AccountState.ConnectedButException.rawValue
            orderStatus = OrderStatus.Failed.rawValue
        case .ConnectionInProgress:
            print("")
        }
        _ = AmazonService.updateStatus(platformId: userId, status: status
                                       , message: message, orderStatus: orderStatus, orderSource:  OrderSource.Instacart.value) { response, error in
            if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
                self.sendServicesDownCallback()
            }
        }
        let eventLog = EventLogs(panelistId: panelistId, platformId: userId, section: SectionType.connection.rawValue, type:  FailureTypes.authentication.rawValue, status: EventState.fail.rawValue, message: message, fromDate: nil, toDate: nil, scrapingType: nil, scrapingContext: ScrapingMode.Foreground.rawValue)
        _ = AmazonService.logEvents(eventLogs: eventLog, orderSource: orderSource) { response, error in
            if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
                self.sendServicesDownCallback()
            }
        }
    }
    
    func addScriptListener() {
        self.webClient.scriptMessageHandler?.addScriptMessageListener(listener: self)
        self.listnerAdded = true
        let userId = self.account?.userID
        var logEventAttributes:[String:String] = [EventConstant.OrderSource: OrderSource.Instacart.value,
                                                  EventConstant.OrderSourceID: userId ?? ""]
        logEventAttributes[EventConstant.Status] = EventStatus.Failure
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetectedCaptcha, eventAttributes: logEventAttributes)
        
    }
    
    private func sendServicesDownCallback() {
        if let scraperListener = scraperListener {
            scraperListener.onServicesDown(error: nil)
        }
    }
}

extension InstacartAuthenticator: ScriptMessageListener {
    func onScriptMessageReceive(message: WKScriptMessage) {
        print("######## onScriptMessageReceive ", message)
        if message.name == "iOS" {
            let data = message.body as! String
            print("######## MessageReceive ", data)
            if data.contains("captcha_closed") {
                self.authenticationDelegate?.didReceiveLoginChallenge(error: Strings.authenticationFailed)
                self.notifyAuthError(errorMessage: Strings.authenticationFailed)
                self.webClient.scriptMessageHandler?.removeScriptMessageListener()
            } else if data.contains("Verification screen callback") {
                self.authenticationChallenge()
            } else if data.contains("Password error callback") {
                self.onErrorPassword()
                self.webClient.scriptMessageHandler?.removeScriptMessageListener()
            } else if data.contains("Email error callback") {
                self.onErrorEmail()
                self.webClient.scriptMessageHandler?.removeScriptMessageListener()
            } else if data.contains("Flash message callback") {
                self.onFlashMessage()
            } else if data.contains("Email field Availablity callback") {
                print("$$$ data",data)
                self.authenticationDelegate?.didReceiveAuthenticationChallenge(authError: false)
                if !isNetworkDisconnect {
                    if !isAuthenticated {
                        self.onSignIn()
                    }
                } else {
                    isNetworkDisconnect = false
                    self.webClient.scriptMessageHandler?.removeScriptMessageListener()
                }
            } else if data.contains("Captcha_open") {
                print("$$$ data",data)
                self.authenticationChallenge()
            } else if data.contains("verification_closed") {
                self.authenticationDelegate?.didReceiveLoginChallenge(error: Strings.authenticationFailed)
                self.notifyAuthError(errorMessage: Strings.authenticationFailed)
                self.webClient.scriptMessageHandler?.removeScriptMessageListener()
            } else if data.contains("verification_success") {
                print("$$$ data",data)
                self.authenticationDelegate?.didReceiveAuthenticationChallenge(authError: false)
            } else if data.contains("Invalid_user_or_passwrd") {
                print("$$$ data",data)
                self.onWrongCredentials()
            }
        }
    }
}
