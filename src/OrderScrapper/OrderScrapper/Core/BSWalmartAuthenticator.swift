//
//  BSWalmartAuthenticator.swift
//  OrderScrapper

import Foundation
import WebKit
class BSWalmartAuthenticator: BSBaseAuthenticator {
    
    private let LoginURLDelimiter = "/"
    private let WalmartHomePage = "https://www.walmart.com/"
    private let WalmartOrderPage = "https://www.walmart.com/orders"
    var count = 0
    var timer: Timer? = nil
    
    override func onPageFinish(url: String) throws {
        print("#### walmart",url)
       if url.contains(configurations!.login) {
            self.injectWalmartAuthentication()
        } else if url.contains(WalmartOrderPage) {
            if let completionHandler = self.completionHandler {
                completionHandler(true, nil)
            }
        } else if url.contains(WalmartHomePage) {
            DispatchQueue.main.async {
                self.webClient.load(URLRequest(url: URL(string: self.WalmartOrderPage)!))
            }
        }
    }
    
    override func onStartPageNavigation(url: String) {
    }
    
    override func onFailPageNavigation(for url: String, withError error: Error) {
        self.completionHandler?(false,ASLException(errorMessage: error.localizedDescription, errorType: nil))
    }
    
    override func onNetworkDisconnected() {
        self.webClient.scriptMessageHandler?.removeScriptMessageListener()
    }
    
    // MARK:- Public Methods
    func checkError(data: String) {
        print("@@@@ check error called")
        guard let userId = account?.userID else {
            return
        }
        let js = JSUtils.getWACheckErrorJS()
        self.evaluateJS(javascript: js) { response, error in
            if response != nil {
                self.webClient.scriptMessageHandler?.removeScriptMessageListener()
                let authError = ASLException(errorMessages: data, errorTypes: .authError, errorEventLog: .authentication, errorScrappingType: .html)
                self.completionHandler?(false, authError)
                var logEventAttributes:[String:String] = [:]
                logEventAttributes = [EventConstant.OrderSource: OrderSource.Walmart.value,
                                      EventConstant.OrderSourceID: userId,
                                      EventConstant.ErrorReason: error.debugDescription,
                                      EventConstant.Status: EventStatus.Failure]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgAuthentication, eventAttributes: logEventAttributes)
            }
        }
    }
    
    func injectWalmartAuthentication() {
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
            print("!!!! getIdentificationJS",response)
        }
    }
    
    func addScriptListener() {
        self.webClient.scriptMessageHandler?.addScriptMessageListener(listener: self)
        let userId = self.account?.userID
        var logEventAttributes:[String:String] = [EventConstant.OrderSource: OrderSource.Walmart.value,
                                                  EventConstant.OrderSourceID: userId!]
        logEventAttributes[EventConstant.Status] = EventStatus.Success
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSListnerAdded, eventAttributes: logEventAttributes)
        
    }
    
    func authChallenge() {
        self.webClient.scriptMessageHandler?.removeScriptMessageListener()
        let error = ASLException(errorMessages: Strings.ErrorCaptchaPageLoaded, errorTypes: .authChallenge, errorEventLog: .captcha, errorScrappingType: .html)
        self.completionHandler?(false, error)
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
}

extension BSWalmartAuthenticator: ScriptMessageListener {
    func onScriptMessageReceive(message: WKScriptMessage) {
            print("######## onScriptMessageReceive ", message)
            if message.name == "iOS" {
                let data = message.body as! String
                print("######## MessageReceive ", data)
                if data.contains("Validation error is shown") {
                    print("!!!! Validation error is shown")
                    self.checkError(data: data)
                    var logEventAttributes:[String:String] = [EventConstant.OrderSource: OrderSource.Walmart.value,
                                                              EventConstant.OrderSourceID: account!.userID]
                    logEventAttributes[EventConstant.Status] = EventStatus.Failure
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetectSignIn, eventAttributes: logEventAttributes)
                } else if data.contains("verify_identity") {
                    self.authChallenge()
                    var logEventAttributes:[String:String] = [EventConstant.OrderSource: OrderSource.Walmart.value,
                                                              EventConstant.OrderSourceID: account!.userID]
                    logEventAttributes[EventConstant.Status] = EventStatus.Failure
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetectedCaptcha, eventAttributes: logEventAttributes)
                }else if data.contains("sign_in") {
                    print("!!!!sign_in")
                    var logEventAttributes:[String:String] = [EventConstant.OrderSource: OrderSource.Walmart.value,
                                                              EventConstant.OrderSourceID: account!.userID]
                    logEventAttributes[EventConstant.Status] = EventStatus.Success
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetectSignIn, eventAttributes: logEventAttributes)
                } else if data.contains("Captcha is open") {
                    print("!!!! Captcha is open")
                    self.authChallenge()
                    var logEventAttributes:[String:String] = [EventConstant.OrderSource: OrderSource.Walmart.value,
                                                              EventConstant.OrderSourceID: account!.userID]
                    logEventAttributes[EventConstant.Status] = EventStatus.Failure
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetectedCaptcha, eventAttributes: logEventAttributes)
                }
            }
        }
}
