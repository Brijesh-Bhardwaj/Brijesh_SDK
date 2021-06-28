//  BSAmazonAuthenticator.swift
//  OrderScrapper

import Foundation
import WebKit

class BSAmazonAuthenticator: BSBaseAuthenticator {
    private let LoginURLDelimiter = "/?"
    private let URLDelimiter = "?"
    
    override func onPageFinish(url: String) throws {
        print("### didFinish", url)
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) { [weak self] in
            guard let self = self else {return}
            
            let loginSubURL = self.getSubURL(from: self.configurations!.login, delimeter: self.LoginURLDelimiter)
            if (url.contains(loginSubURL) || loginSubURL.contains(url)) {
                self.injectAuthErrorVerificationJS()
            } else {
                if let completionHandler = self.completionHandler {
                    completionHandler(true, nil)
                }
            }
        }
    }
    
    private func getSubURL(from url: String, delimeter: String) -> String {
        if url.contains(delimeter) {
            return Utils.getSubUrl(url: url, delimeter: delimeter)
        }
        return url
    }
    
    private func injectAuthErrorVerificationJS() {
        let js = JSUtils.getAuthErrorVerificationJS()
        
        self.webClient.evaluateJavaScript(js) { (response, error) in
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) { [weak self] in
                guard let self = self else {return}
                
                if let response = response as? String {
                    if (response.isEmpty) {
                        self.injectCaptchaIdentificationJS()
                    } else {
                        self.completionHandler?(false, ASLException(errorMessage: Strings.ErrorOccuredWhileInjectingJS, errorType: .authError))
                    }
                } else {
                    self.completionHandler?(false, ASLException(errorMessage: Strings.ErrorOccuredWhileInjectingJS, errorType: .authError))
                }
            }
        }
    }
    
    private func injectCaptchaIdentificationJS() {
        let js = JSUtils.getCaptchaIdentificationJS()
        
        self.webClient.evaluateJavaScript(js) { (response, error) in
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) { [weak self] in
                guard let self = self else {return}
                
                if let response = response as? String {
                    if response.contains("captcha") {
                        self.completionHandler?(false, ASLException(errorMessage: Strings.ErrorCaptchaPageLoaded, errorType: .authError))
                        
                        guard let userId = self.account?.userID else {return}
                        var logEventAttributes:[String:String] = [:]
                        logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                              EventConstant.OrderSourceID: userId,
                                              EventConstant.Status: EventStatus.Success]
                        FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgJSDetectedCaptcha, eventAttributes: logEventAttributes)
                    } else {
                        self.injectFieldIdentificationJS()
                    }
                } else {
                    self.injectFieldIdentificationJS()
                }
            }
        }
    }
    
    private func injectFieldIdentificationJS() {
        let js = JSUtils.getFieldIdentificationJS()
        
        self.webClient.evaluateJavaScript(js) { (response, error) in
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) { [weak self] in
                guard let self = self else { return }
                
                if let response = response as? String {
                    if response.contains("other") {
                        self.completionHandler?(false, ASLException(errorMessage: Strings.ErrorOtherUrlLoaded, errorType: .authError))
                    } else if response.contains("emailId") {
                        self.injectEmailJS()
                    } else {
                        self.injectPasswordJS()
                    }
                }
            }
        }
    }
    
    private func injectEmailJS() {
        guard let email = self.account?.userID else {
            self.completionHandler?(false, ASLException(errorMessage: Strings.ErrorUserIdIsNil, errorType: .authError))
            return
        }
        let js = JSUtils.getEmailInjectJS(email: email)
        
        self.webClient.evaluateJavaScript(js) { (response, error) in
            var logEventAttributes:[String:String] = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                                      EventConstant.OrderSourceID: email]
            if error != nil {
                self.completionHandler?(false, ASLException(errorMessage: Strings.ErrorEmailJSInjectionFailed, errorType: .authError))
                
                logEventAttributes[EventConstant.ErrorReason] = error.debugDescription
                logEventAttributes[EventConstant.Status] = EventStatus.Failure
            } else {
                print("### injectEmailJS")
                logEventAttributes[EventConstant.Status] = EventStatus.Success
            }
            FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgJSInjectUserName, eventAttributes: logEventAttributes)
        }
    }
    
    private func injectPasswordJS() {
        guard let email = self.account?.userID else {
            self.completionHandler?(false, ASLException(errorMessage: Strings.ErrorUserIdIsNil, errorType: .authError))
            return
        }
        guard let password = self.account?.userPassword else {
            self.completionHandler?(false, ASLException(errorMessage: Strings.ErrorPasswordIsNil,errorType: .authError))
            return
        }
        let js = JSUtils.getPasswordInjectJS(password: password)
        
        self.webClient.evaluateJavaScript(js) { (response, error) in
            var logEventAttributes:[String:String] = [:]
            if error != nil {
                self.completionHandler?(false, ASLException(errorMessage: Strings.ErrorPasswordJSInjectionFailed,errorType: .authError))
                
                logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                      EventConstant.OrderSourceID: email,
                                      EventConstant.ErrorReason: error.debugDescription,
                                      EventConstant.Status: EventStatus.Failure]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgJSInjectPassword, eventAttributes: logEventAttributes)
            } else {
                print("### injectPasswordJS")
                logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                      EventConstant.OrderSourceID: email,
                                      EventConstant.Status: EventStatus.Success]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgJSInjectPassword, eventAttributes: logEventAttributes)
            }
        }
    }
}
