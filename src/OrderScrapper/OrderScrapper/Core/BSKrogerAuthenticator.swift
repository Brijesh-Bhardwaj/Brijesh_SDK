//
//  BSKrogerAuthenticator.swift
//  OrderScrapper

import Foundation
import WebKit

class BSKrogerAuthenticator: BSBaseAuthenticator {
    private let LoginURLDelimiter = "/"
    var retryCount = -1
    
    override func onPageFinish(url: String) throws {
        print("####",url)
        if let configurations = configurations {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) { [weak self] in
                guard let self = self else {return}
                
                let loginSubURL = Utils.getSubUrl(url: configurations.login, delimeter: self.LoginURLDelimiter)
                let subURL = AppConstants.KRLoginSuccessURL
                if url == subURL{
                    if let completionHandler = self.completionHandler {
                        completionHandler(true, nil)
                    } else {
                        self.completionHandler?(true, nil)
                    }
                } else if (url.contains(loginSubURL) || loginSubURL.contains(url)) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) { [weak self] in
                        self?.injectIdentificationJS()
                    }
                } else {
                    self.authenticationDelegate = nil
                    if let completionHandler = self.completionHandler {
                        completionHandler(true, nil)
                    } else {
                        self.completionHandler?(true, nil)
                    }
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
    
    func injectIdentificationJS() {
        ConfigManager.shared.getConfigurations(orderSource: OrderSource.Kroger) { (configurations, error) in
            if let configuration = configurations {
                if self.retryCount == -1{
                    self.retryCount = configuration.loginRetries ?? AppConstants.krogerRetryCount
                }
            }
        }
        self.addScriptListener()
        self.CheckValidationError()
    }
    func addScriptListener() {
        self.webClient.scriptMessageHandler?.addScriptMessageListener(listener: self)
        let userId = self.account?.userID
        var logEventAttributes:[String:String] = [EventConstant.OrderSource: OrderSource.Kroger.value,
                                                  EventConstant.OrderSourceID: userId!]
        logEventAttributes[EventConstant.Status] = EventStatus.Failure
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSInjectUserName, eventAttributes: logEventAttributes)
        
    }
    func CheckValidationError() {
        let js = JSUtils.getKRIdentifyErrorJSAction()
        self.evaluateJS(javascript: js) { response, error in
            print("#### Check Username password error",response as Any, error as Any)
        }
    }
    func checkError(data: String) {
        guard let userId = account?.userID else {
            return
        }
        var logEventAttributes:[String:String] = [:]
        if data.contains("pop up or ad blockers") {
            let error = ASLException(errorMessages:data, errorTypes: .authChallenge, errorEventLog: .authentication, errorScrappingType: .html)
            self.completionHandler?(false, error)
        } else {
            let error = ASLException(errorMessages:data, errorTypes: .authError, errorEventLog: .authentication, errorScrappingType: .html)
            self.completionHandler?(false, error)
        }
        
        logEventAttributes = [EventConstant.OrderSource: OrderSource.Kroger.value,
                              EventConstant.OrderSourceID: userId,
                              EventConstant.ErrorReason: data,
                              EventConstant.Status: EventStatus.Failure]
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgAuthentication, eventAttributes: logEventAttributes)
    }
    
    func checkError2() {
        let js = JSUtils.getKRCheckError2JS()
        guard let userId = account?.userID else {
            return
        }
        DispatchQueue.main.async {
            self.webClient.evaluateJavaScript(js) { [weak self] (response, error) in
                var logEventAttributes:[String:String] = [:]
                if let response = response as? String {
                    self?.completionHandler?(false, ASLException(errorMessage: response,errorType: .authError))
                    
                    logEventAttributes = [EventConstant.OrderSource: OrderSource.Kroger.value,
                                          EventConstant.OrderSourceID: userId,
                                          EventConstant.ErrorReason: error.debugDescription,
                                          EventConstant.Status: EventStatus.Failure]
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgAuthentication, eventAttributes: logEventAttributes)
                }
            }
        }
    }
    
    func doSignIn() {
        guard let password = self.account?.userPassword else {
            self.completionHandler?(false, ASLException(errorMessage: Strings.ErrorPasswordIsNil, errorType: .authError))
            return
        }
        guard let email = self.account?.userID else {
            self.completionHandler?(false, ASLException(errorMessage: Strings.ErrorUserIdIsNil, errorType: .authError))
            return
        }
        
        let js = JSUtils.getKRSignInJS(email: email, password: password)
        self.evaluateJS(javascript: js) { respone, error in
            if error != nil {
                let error = ASLException(errorMessages: Strings.ErrorScriptNotFound, errorTypes: .authError, errorEventLog: .authentication, errorScrappingType: .html)
                self.completionHandler?(false, error)
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
                    completionHandler?(false, error)
                } else {
                    //Success condition
                    completionHandler?(true, error)
                }
            }
        }
    }
}

extension BSKrogerAuthenticator : ScriptMessageListener {
    func onScriptMessageReceive(message: WKScriptMessage) {
        print("######## onScriptMessageReceive ", message)
        if message.name == "iOS" {
            let data = message.body as! String
            print("######## MessageReceive ", data)
            if data.contains("sign_in"){
                self.doSignIn()
            }else{
                if data.contains("pop up or ad blockers") {
                    if retryCount > 0{
                        print("### Retry ",retryCount as Int)
                        retryCount -= 1
                        DispatchQueue.main.async {
                            self.webClient.reload()
                        }
                    } else {
                        self.checkError(data: data)
                        self.webClient.scriptMessageHandler?.removeScriptMessageListener()
                    }
                } else { 
                    self.checkError(data: data)
                    self.webClient.scriptMessageHandler?.removeScriptMessageListener()
                }
            }
        }
    }
}
