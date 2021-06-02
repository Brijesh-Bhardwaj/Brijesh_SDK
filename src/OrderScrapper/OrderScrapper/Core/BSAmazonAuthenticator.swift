//  BSAmazonAuthenticator.swift
//  OrderScrapper

import Foundation
import WebKit

class BSAmazonAuthenticator: BSBaseAuthenticator {
    private let LoginURLDelimiter = "/?"
    private let URLDelimiter = "?"
    
    override func onPageFinish(url: String) throws {
        print("### didFinish", url)
        let loginSubURL = getSubURL(from: configurations!.login, delimeter: LoginURLDelimiter)
        if (url.contains(loginSubURL) || loginSubURL.contains(url)) {
            self.injectAuthErrorVerificationJS()
        } else if (url.contains(getSubURL(from: configurations!.listing, delimeter: URLDelimiter))) {
            self.listener?.onAuthenticationSuccess()
        } else {
            self.listener?.onAuthenticationFailure(errorReason: ASLException(errorMessage: Strings.ErrorOtherUrlLoaded,errorType: nil))
            
            var logOtherUrlEventAttributes:[String:String] = [:]
            guard let userId = self.account?.userID else {return}
            logOtherUrlEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                          EventConstant.OrderSourceID: userId,
                                          EventConstant.Status: EventStatus.Success,
                                          EventConstant.URL: url]
            FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgJSDetectOtherURL, eventAttributes: logOtherUrlEventAttributes)
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
            if let response = response as? String {
                if (response.isEmpty) {
                    self.injectCaptchaIdentificationJS()
                } else {
                    self.listener?.onAuthenticationFailure(errorReason: ASLException(errorMessage: Strings.ErrorOccuredWhileInjectingJS, errorType: nil))
                }
            } else {
                self.listener?.onAuthenticationFailure(errorReason: ASLException(errorMessage: Strings.ErrorOccuredWhileInjectingJS, errorType: nil))
            }
        }
    }
    
    private func injectCaptchaIdentificationJS() {
        let js = JSUtils.getCaptchaIdentificationJS()
        
        self.webClient.evaluateJavaScript(js) { (response, error) in
            if let response = response as? String {
                if response.contains("captcha") {
                    self.listener?.onAuthenticationFailure(errorReason: ASLException(errorMessage: Strings.ErrorCaptchaPageLoaded, errorType: nil))
                    
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
    
    private func injectFieldIdentificationJS() {
        let js = JSUtils.getFieldIdentificationJS()
        
        self.webClient.evaluateJavaScript(js) { (response, error) in
            if let response = response as? String {
                if response.contains("other") {
                    self.listener?.onAuthenticationFailure(errorReason: ASLException(errorMessage: Strings.ErrorOtherUrlLoaded,errorType: nil))
                } else if response.contains("emailId") {
                    self.injectEmailJS()
                } else {
                    self.injectPasswordJS()
                }
            }
        }
    }
    
    private func injectEmailJS() {
        guard let email = self.account?.userID else {
            self.listener?.onAuthenticationFailure(errorReason: ASLException(errorMessage: Strings.ErrorUserIdIsNil, errorType: nil))
            return
        }
        let js = JSUtils.getEmailInjectJS(email: email)
        
        self.webClient.evaluateJavaScript(js) { (response, error) in
            var logEventAttributes:[String:String] = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                                      EventConstant.OrderSourceID: email]
            if error != nil {
                self.listener?.onAuthenticationFailure(errorReason: ASLException(errorMessage: Strings.ErrorEmailJSInjectionFailed, errorType: nil))

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
            self.listener?.onAuthenticationFailure(errorReason: ASLException(errorMessage: Strings.ErrorUserIdIsNil, errorType: nil))
            return
        }
        guard let password = self.account?.userPassword else {
            self.listener?.onAuthenticationFailure(errorReason: ASLException(errorMessage: Strings.ErrorPasswordIsNil,errorType: nil))
            return
        }
        let js = JSUtils.getPasswordInjectJS(password: password)
        
        self.webClient.evaluateJavaScript(js) { (response, error) in
            var logEventAttributes:[String:String] = [:]
            if error != nil {
                self.listener?.onAuthenticationFailure(errorReason: ASLException(errorMessage: Strings.ErrorPasswordJSInjectionFailed,errorType: nil))
                
                logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                      EventConstant.OrderSourceID: email,
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
