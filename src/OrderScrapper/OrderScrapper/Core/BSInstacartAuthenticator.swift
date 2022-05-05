//  BSInstacartAuthenticator.swift
//  OrderScrapper


import Foundation
import WebKit

class BSInstacartAuthenticator: BSBaseAuthenticator {
    private let LoginURLDelimiter = "/"
    var isAuthenticated: Bool = false
    
    override func onPageFinish(url: String) throws {
        print("####",url)
        if let configurations = configurations {
            let loginSubURL = Utils.getSubUrl(url: configurations.login, delimeter: self.LoginURLDelimiter)
            let subURL = AppConstants.ICLoginSuccessURL
            if  url.contains(AppConstants.InstacartOnBoardingURL) {
                self.webClient.scriptMessageHandler?.removeScriptMessageListener()
            } else if url.contains(subURL) {
                if let completionHandler = self.completionHandler {
                    completionHandler(true, nil)
                } else {
                    self.completionHandler?(true, nil)
                }
            } else if (url.contains(loginSubURL) || loginSubURL.contains(url)) {
                self.onLoginScript()
            } else {
                self.authenticationDelegate = nil
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
    
    override func onNetworkDisconnected() {
        self.webClient.scriptMessageHandler?.removeScriptMessageListener()
    }
    
    func onLoginScript() {
        self.getScript(orderSource: .Instacart, scriptKey: AppConstants.getInstacartOnClick) { script in
            if !script.isEmpty {
                self.evaluateJS(javascript: script) { response, error in
                    if response != nil {
                        self.getIdentificationJS()
                    } else {
                        if let error = error {
                            FirebaseAnalyticsUtil.logSentryError(error: error)
                        }
                        let errorMessage = ASLException(errorMessages: error.debugDescription ?? Strings.ErrorScriptNotFound , errorTypes: .authChallenge, errorEventLog: .authentication, errorScrappingType: .html)
                        self.completionHandler?(false, errorMessage)
                    }
                }
            } else {
                let errorMessage = ASLException(errorMessages: Strings.ErrorScriptNotFound + "onLoginScript for instacart bg" , errorTypes: .authChallenge, errorEventLog: .authentication, errorScrappingType: .html)
                self.completionHandler?(false, errorMessage)
            }
        }
    }
    
    func getIdentificationJS() {
        self.addScriptListener()
        self.getScript(orderSource: .Instacart, scriptKey: AppConstants.getInstacartIdentification) { script in
            if !script.isEmpty {
                self.evaluateJS(javascript: script) { response, error in
                    print("Idnetification JS",response)
                }
            } else {
                let errorMessage = ASLException(errorMessages: Strings.ErrorScriptNotFound + "getIdentificationJS for instacart bg" , errorTypes: .authChallenge, errorEventLog: .authentication, errorScrappingType: .html)
                self.completionHandler?(false, errorMessage)
            }
            
        }
     
    }
    
    func addScriptListener() {
        self.webClient.scriptMessageHandler?.addScriptMessageListener(listener: self)
        let userId = self.account?.userID
        var logEventAttributes:[String:String] = [EventConstant.OrderSource: OrderSource.Instacart.value,
                                                  EventConstant.OrderSourceID: userId!]
        logEventAttributes[EventConstant.Status] = EventStatus.Failure
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetectedCaptcha, eventAttributes: logEventAttributes)
        
    }
    func onErrorPassword() {
        guard let userId = account?.userID else {
            return
        }
        self.getScript(orderSource: .Instacart, scriptKey: AppConstants.getInstacartErrorPasswordInjectJS) { script in
            if !script.isEmpty {
                self.evaluateJS(javascript: script) { response, error in
                    var logEventAttributes:[String:String] = [:]
                    if response != nil {
                        let error = ASLException(errorMessages: Strings.ErrorPasswordJSInjectionFailed, errorTypes: .authError, errorEventLog: .authentication, errorScrappingType: .html)
                        self.completionHandler?(false, error)
                        
                        logEventAttributes = [EventConstant.OrderSource: OrderSource.Instacart.value,
                                              EventConstant.OrderSourceID: userId,
                                              EventConstant.ErrorReason: Strings.ErrorJSICAuthenticationResposne,
                                              EventConstant.Status: EventStatus.Failure]
                        FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgJSInjectPassword, eventAttributes: logEventAttributes)
                    } else {
                        if let error = error {
                            FirebaseAnalyticsUtil.logSentryError(error: error )
                            print("error",error)
                        }
                    }
                }
            } else {
                let errorMessage = ASLException(errorMessages: Strings.ErrorScriptNotFound + "onErrorPassword for instacart bg", errorTypes: .authChallenge, errorEventLog: .authentication, errorScrappingType: .html)
                self.completionHandler?(false, errorMessage)
            }
            
        }
      
    }
    
    func onErrorEmail() {
        guard let userId = account?.userID else {
            return
        }
        self.getScript(orderSource: .Instacart, scriptKey: AppConstants.getInstacartErrorEmailInjectJS) { script in
            if !script.isEmpty {
                self.evaluateJS(javascript: script) { response, error in
                    var logEventAttributes:[String:String] = [EventConstant.OrderSource: OrderSource.Instacart.value,
                                                              EventConstant.OrderSourceID: userId]
                    if response != nil {
                        let error = ASLException(errorMessages: Strings.ErrorEmailJSInjectionFailed, errorTypes: .authError, errorEventLog: .authentication, errorScrappingType: .html)
                        self.completionHandler?(false, error)
                        
                        logEventAttributes[EventConstant.ErrorReason] = Strings.ErrorJSICAuthenticationResposne
                        logEventAttributes[EventConstant.Status] = EventStatus.Failure
                        FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgJSInjectPassword, eventAttributes: logEventAttributes)
                    } else {
                        if let error = error {
                            FirebaseAnalyticsUtil.logSentryError(error: error )
                            print("error",error)
                        }
                    }
                }
            } else {
                let errorMessage = ASLException(errorMessages: Strings.ErrorScriptNotFound + "onErrorEmail for instacart bg" , errorTypes: .authChallenge, errorEventLog: .authentication, errorScrappingType: .html)
                self.completionHandler?(false, errorMessage)
            }
        }
    }
    
    func onRecaptcha() {
        // Handled on Sign in
    }
    
    func onFlashMessage() {
        self.getScript(orderSource: .Instacart, scriptKey: AppConstants.getInstacartFlashMessage) { script in
            if !script.isEmpty {
                self.evaluateJS(javascript: script) { response, error in
                    if response != nil {
                        let response = response as? String
                        let error = ASLException(errorMessages: response ?? Strings.ErrorInFlashMessage , errorTypes: .authChallenge, errorEventLog: .authentication, errorScrappingType: .html)
                        self.completionHandler?(false, error)
                    } else {
                        if let error = error {
                            FirebaseAnalyticsUtil.logSentryError(error: error)
                            print("error",error)
                        }
                    }
                }
                
            } else {
                let errorMessage = ASLException(errorMessages: Strings.ErrorScriptNotFound + "onFlashMessage for instacart bg", errorTypes: .authChallenge, errorEventLog: .authentication, errorScrappingType: .html)
                self.completionHandler?(false, errorMessage)
            }
        }
    }
    
    func onWrongCredentials() {
        self.getScript(orderSource: .Instacart, scriptKey: AppConstants.getInstacartWrongPasswordInjectJS) { script in
            if !script.isEmpty {
                self.evaluateJS(javascript: script) { response, error in
                    if let response = response as? String {
                        let error = ASLException(errorMessages: response, errorTypes: .authError, errorEventLog: .authentication, errorScrappingType: .html)
                        self.completionHandler?(false, error)
                        self.webClient.scriptMessageHandler?.removeScriptMessageListener()
                    } else {
                        if let error = error {
                            FirebaseAnalyticsUtil.logSentryError(error: error)
                        }
                        self.completionHandler?(false,ASLException(errorMessage: Strings.ErrorInInjectingScript, errorType: .authError))
                    }
                }
            } else {
                let errorMessage = ASLException(errorMessages: Strings.ErrorScriptNotFound + "onWrongCredentials for instacart bg" , errorTypes: .authChallenge, errorEventLog: .authentication, errorScrappingType: .html)
                self.completionHandler?(false, errorMessage)
            }
        }
    }
    
    func onSignIn() {
        print("$$$$ signIn called")
        guard let password = self.account?.userPassword else {
            self.completionHandler?(false, ASLException(errorMessage: Strings.ErrorPasswordIsNil, errorType: .authError))
            return
        }
        guard let email = self.account?.userID else {
            self.completionHandler?(false, ASLException(errorMessage: Strings.ErrorUserIdIsNil, errorType: .authError))
            return
        }
        self.getScript(orderSource: .Instacart, scriptKey: AppConstants.getInstcartinjectLoginJS) {
            script in
            if !script.isEmpty {
                let passwordJS = script.replacingOccurrences(of: "$email$", with: email)
                let signInJS = passwordJS.replacingOccurrences(of: "$password$", with: password)
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) { [weak self] in
                    self!.evaluateJS(javascript: signInJS) { respone, error in
                        if error != nil {
                            let error = ASLException(errorMessage: Strings.ErrorOccuredWhileInjectingJS + error.debugDescription, errorType: .authChallenge)
                            self?.completionHandler!(false,error)
                        } else {
                            self?.isAuthenticated = true
                            print("#### Valid SignIn JS")
                        }
                    }
                }
                self.captchaClosed()
                let userId = self.account?.userID
                var logEventAttributes:[String:String] = [EventConstant.OrderSource: OrderSource.Instacart.value,
                                                          EventConstant.OrderSourceID: userId!]
                logEventAttributes[EventConstant.Status] = EventStatus.Success
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetectSignIn, eventAttributes: logEventAttributes)
            } else {
                let errorMessage = ASLException(errorMessages: Strings.ErrorScriptNotFound + "onSignIn for instacart bg" , errorTypes: .authChallenge, errorEventLog: .authentication, errorScrappingType: .html)
                self.completionHandler?(false, errorMessage)
            }
        }
    }
    
    func captchaClosed() {
        print("$$$$ captchaClosed called")
      self.getScript(orderSource: .Instacart, scriptKey: AppConstants.getInstcartCaptchaClosed) { script in
            if !script.isEmpty {
                self.evaluateJS(javascript: script) { response, error in
                }
            } else {
                let errorMessage = ASLException(errorMessages: Strings.ErrorScriptNotFound + "captchaClosed for instacart bg", errorTypes: .authChallenge, errorEventLog: .authentication, errorScrappingType: .html)
                self.completionHandler?(false, errorMessage)
            }
        }
       
    }
    
    func onContinueBrowser() {
        self.getScript(orderSource: .Instacart, scriptKey: AppConstants.getInstacartProcide) { script in
            if !script.isEmpty {
                self.evaluateJS(javascript: script) { response, error in
                    if response != nil {
                        self.onLoginScript()
                    } else {
                        self.completionHandler?(false,ASLException(errorMessage: Strings.ErrorScriptNotFound + error.debugDescription, errorType: .authChallenge))
                    }
                }
            } else {
                let errorMessage = ASLException(errorMessages: Strings.ErrorScriptNotFound + "onContinueBrowser for instacart bg", errorTypes: .authChallenge, errorEventLog: .authentication, errorScrappingType: .html)
                self.completionHandler?(false, errorMessage)
            }
        }
    }
    
    func authenticationChallenge(data: String) {
        let userId = self.account?.userID
        var logEventAttributes:[String:String] = [EventConstant.OrderSource: OrderSource.Instacart.value,
                                                  EventConstant.OrderSourceID: userId!]
        if let scrapingMode = scrapingMode, scrapingMode == ScrapingMode.Foreground.rawValue {
            showWebClient()
        } else {
            let error = ASLException(errorMessages: data, errorTypes: .authChallenge, errorEventLog: .captcha, errorScrappingType: .html)
            self.completionHandler?(false, error)
        }
        let eventLog = EventLogs(panelistId: self.account?.panelistID ?? "", platformId: userId, section: SectionType.connection.rawValue, type:  FailureTypes.captcha.rawValue, status: EventState.Info.rawValue, message: AppConstants.msgCapchaEncountered, fromDate: nil, toDate: nil, scrapingType: nil, scrapingContext: ScrapingMode.Foreground.rawValue,url: webClient.url?.absoluteString)
        _ = AmazonService.logEvents(eventLogs: eventLog, orderSource: OrderSource.Instacart.value) { response, error in}
        logEventAttributes[EventConstant.ErrorReason] = EventType.JSDetectedDeviceAuth
        logEventAttributes[EventConstant.Status] = EventStatus.Success
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetectedDeviceAuth, eventAttributes: logEventAttributes)
    }
    
    private func evaluateJS(javascript: String, completionHandler: ((Any?, Error?) -> Void)? = nil) {
        DispatchQueue.main.async {
            self.webClient.evaluateJavaScript(javascript) { (response, error) in
                if error != nil {
                    //Error condition
                    completionHandler?(false, error)
                } else {
                    //Success condition
                    completionHandler?(true, error)
                }
            }
        }
    }
    
    private func getScript(orderSource: OrderSource, scriptKey: String, completionHandler: @escaping (String) -> Void) {
        BSScriptFileManager.shared.getAuthScript(orderSource: orderSource, scriptKey: scriptKey) { script in
            completionHandler(script)
        }
    }
}

extension BSInstacartAuthenticator: ScriptMessageListener {
    func onScriptMessageReceive(message: WKScriptMessage) {
        print("######## onScriptMessageReceive ", message)
        if message.name == "iOS" {
            let data = message.body as! String
            print("######## MessageReceive ", data)
            if data.contains("Verification screen callback") {
                self.authenticationChallenge(data: data)
            } else if data.contains("Password error callback") {
                self.onErrorPassword()
                self.webClient.scriptMessageHandler?.removeScriptMessageListener()
            } else if data.contains("Email error callback") {
                self.onErrorEmail()
                self.webClient.scriptMessageHandler?.removeScriptMessageListener()
            } else if data.contains("Flash message callback") {
                self.onFlashMessage()
                self.webClient.scriptMessageHandler?.removeScriptMessageListener()
            } else if data.contains("Email field Availablity callback") {
                print("$$$ data",data)
                //TODO check
                if let scrapingMode = scrapingMode, scrapingMode == ScrapingMode.Foreground.rawValue {
                    hideWebClient()
                    if !isAuthenticated {
                        self.onSignIn()
                    }
                } else {
                    //TODO In case of manual scrape we need to reset the flag when we show the webView
                    if !isAuthenticated {
                        self.onSignIn()
                    }
                }
            } else if data.contains("Captcha_open") {
                print("$$$ data",data)
                self.authenticationChallenge(data: data)
            }  else if data.contains("Invalid_user_or_passwrd") {
                print("$$$ data",data)
                self.onWrongCredentials()
            }
        }
    }
}
