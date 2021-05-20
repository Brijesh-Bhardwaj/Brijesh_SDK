//  BSAmazonAuthenticator.swift
//  OrderScrapper

import Foundation
import WebKit

class BSAmazonAuthenticator: BSBaseAuthenticator {
    
    override func onPageFinish(url: String) throws {
        print("### didFinish", url)
        if (url.contains(Utils.getSubUrl(url: configurations!.login, delimeter: "?"))) {
            self.injectAuthErrorVerificationJS()
        } else if (url.contains(Utils.getSubUrl(url: configurations!.listing, delimeter: "?"))) {
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
                var logEventAttributes:[String:String] = [:]
                if error != nil {
                    self.listener?.onAuthenticationFailure(errorReason: ASLException(errorMessage: Strings.ErrorEmailJSInjectionFailed, errorType: nil))
                    
                    logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                          EventConstant.OrderSourceID: email,
                                          EventConstant.Status: EventStatus.Failure]
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgJSInjectUserName, eventAttributes: logEventAttributes)
                } else {
                    print("### injectEmailJS")
                    logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                          EventConstant.OrderSourceID: email,
                                          EventConstant.Status: EventStatus.Success]
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgJSInjectUserName, eventAttributes: logEventAttributes)
                }
            }
        }
        
        private func injectPasswordJS() {
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
                                          EventConstant.OrderSourceID: password,
                                          EventConstant.Status: EventStatus.Failure]
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgJSInjectPassword, eventAttributes: logEventAttributes)
                } else {
                    print("### injectPasswordJS")
                    logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                          EventConstant.OrderSourceID: password,
                                          EventConstant.Status: EventStatus.Success]
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgJSInjectPassword, eventAttributes: logEventAttributes)
                }
            }
        }
    }
