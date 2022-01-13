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
                // TODO -: Check the hardcoded URL
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
                    self.onContinueBrowser()
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
        let js = JSUtils.getICOnClick()
        self.evaluateJS(javascript: js) { response, error in
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
   
    }
    
    func getIdentificationJS() {
        self.addScriptListener()
        let js = JSUtils.getInstacartIdentification()
        self.evaluateJS(javascript: js) { response, error in
            print("Idnetification JS",response)
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
        let js = JSUtils.getICErrorPasswordInjectJS()
        guard let userId = account?.userID else {
            return
        }
        self.evaluateJS(javascript: js) { response, error in
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
    }
    
    func onErrorEmail() {
        let js = JSUtils.getICErrorEmailInjectJS()
        guard let userId = account?.userID else {
            return
        }
        self.evaluateJS(javascript: js) { response, error in
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
        
    }
    
    func onRecaptcha() {
        // Handled on Sign in
    }
    
    func onFlashMessage() {
        let js = JSUtils.getICFlashMessage()
        self.evaluateJS(javascript: js) { response, error in
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
        let js = JSUtils.getICinjectLoginJS(email: email, password: password)
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) { [weak self] in
            self!.evaluateJS(javascript: js) { respone, error in
                if error != nil {
                    let error = ASLException(errorMessage: Strings.ErrorOccuredWhileInjectingJS + error.debugDescription, errorType: .authChallenge)
                    self?.completionHandler!(false,error)
                    //TODO :- Authentication error
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
        
    }
    
    func captchaClosed() {
        print("$$$$ captchaClosed called")
        let js = JSUtils.captchaClosed()
        self.evaluateJS(javascript: js) { response, error in
        }
    }
    
    func onContinueBrowser() {
        let js = JSUtils.getICProcide()
        self.evaluateJS(javascript: js) { response, error in
            if response != nil {
                self.onLoginScript()
            } else {
                self.completionHandler?(false,ASLException(errorMessage: Strings.ErrorScriptNotFound + error.debugDescription, errorType: .authChallenge))
            }
        }
    }
    
    func authenticationChallenge(data: String) {
        let userId = self.account?.userID
        var logEventAttributes:[String:String] = [EventConstant.OrderSource: OrderSource.Instacart.value,
                                                  EventConstant.OrderSourceID: userId!]
        let error = ASLException(errorMessages: data, errorTypes: .authChallenge, errorEventLog: .captcha, errorScrappingType: .html)
        self.completionHandler?(false, error)
        
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
                //TODO In case of manual scrape we need to reset the flag when we show the webView
                if !isAuthenticated {
                    self.onSignIn()
                }
                    
            } else if data.contains("Captcha_open") {
                print("$$$ data",data)
                self.authenticationChallenge(data: data)
            }
            
        }
    }
}
