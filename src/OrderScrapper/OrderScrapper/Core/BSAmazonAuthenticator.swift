//  BSAmazonAuthenticator.swift
//  OrderScrapper

import Foundation
import WebKit
import Sentry

class BSAmazonAuthenticator: BSBaseAuthenticator {
    private let LoginURLDelimiter = "/?"
    private let URLDelimiter = "?"
    var otherRetryCount = 0
    
    override func onPageFinish(url: String) throws {
        print("### didFinish", url)
        if let configurations = configurations {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) { [weak self] in
                guard let self = self else {return}
                
                let loginSubURL = self.getSubURL(from: configurations.login, delimeter: self.LoginURLDelimiter)
                if (url.contains(loginSubURL) || loginSubURL.contains(url)) {
                    self.injectAuthErrorVerificationJS()
                } else {
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
    
    private func getSubURL(from url: String, delimeter: String) -> String {
        if url.contains(delimeter) {
            return Utils.getSubUrl(url: url, delimeter: delimeter)
        }
        return url
    }
    
    private func injectAuthErrorVerificationJS() {
        self.getScript(orderSource: .Amazon, scriptKey: AppConstants.checkIfSignInErrorAmazon) { script in
            if !script.isEmpty {
                DispatchQueue.main.async {
                    self.webClient.evaluateJavaScript(script) { (response, error) in
                        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) { [weak self] in
                            guard let self = self else {return}
                            
                            if let response = response as? String {
                                if (response.isEmpty) {
                                    self.injectCaptchaIdentificationJS()
                                } else {
                                    if response.contains(AppConstants.AmazonErrorMessage) {
                                        if self.otherRetryCount >= 2 {
                                            self.injectEmailJS()
                                            self.otherRetryCount = self.otherRetryCount + 1
                                        } else {
                                            let error = ASLException(errorMessage: AppConstants.AmazonErrorMessage, errorType: .authChallenge)
                                            self.completionHandler?(false,error)
                                        }
                                    } else {
                                        let error = ASLException(errorMessage: Strings.ErrorOccuredWhileInjectingJS , errorType: .authError)
                                        var logEventAttributes:[String:String] = [:]
                                        guard let userId = self.account?.userID else {return}
                                        guard let panelistId = self.account?.panelistID else {return}
                                        logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                                              EventConstant.OrderSourceID: userId,
                                                              EventConstant.PanelistID: panelistId,
                                                              EventConstant.ScrappingType: ScrappingType.html.rawValue,
                                                              EventConstant.Status: EventStatus.Failure]
                                        FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
                                        
                                        self.completionHandler?(false,error)
                                    }
                                }
                            } else {
                                let error = ASLException(errorMessage: Strings.ErrorOccuredWhileInjectingJS, errorType: .authError)
                                var logEventAttributes:[String:String] = [:]
                                guard let userId = self.account?.userID else {return}
                                guard let panelistId = self.account?.panelistID else {return}
                                logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                                      EventConstant.OrderSourceID: userId,
                                                      EventConstant.PanelistID: panelistId,
                                                      EventConstant.ScrappingType: ScrappingType.html.rawValue,
                                                      EventConstant.Status: EventStatus.Failure]
                                FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
                                
                                self.completionHandler?(false,error)
                            }
                        }
                    }
                }
            } else {
                // Completion handler if script not found
                let error = ASLException(errorMessages:Strings.ErrorScriptNotFound, errorTypes: .authChallenge, errorEventLog: .captcha, errorScrappingType: .html)
                self.completionHandler?(false, error)
            }
        }
    }
    private func injectCaptchaIdentificationJS() {
         self.getScript(orderSource: .Amazon, scriptKey: AppConstants.captchaAmazon) { script in
            if !script.isEmpty {
                DispatchQueue.main.async {
                    self.webClient.evaluateJavaScript(script) { (response, error) in
                        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) { [weak self] in
                            guard let self = self else {return}
                            
                            if let response = response as? String {
                                if response.contains("captcha") {
                                    let error = ASLException(errorMessages:Strings.ErrorCaptchaPageLoaded, errorTypes: .authChallenge, errorEventLog: .captcha, errorScrappingType: .html)
                                    FirebaseAnalyticsUtil.logSentryError(error: error)
                                    self.completionHandler?(false, error)
                                    
                                    guard let userId = self.account?.userID else {return}
                                    guard let panelistId = self.account?.panelistID else {return}
                                    var logEventAttributes:[String:String] = [:]
                                    logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                                          EventConstant.OrderSourceID: userId,
                                                          EventConstant.PanelistID: panelistId,
                                                          EventConstant.ScrappingType: ScrappingType.html.rawValue,
                                                          EventConstant.Status: EventStatus.Success]
                                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.EncounteredCaptcha, eventAttributes: logEventAttributes)
                                } else {
                                    self.injectFieldIdentificationJS()
                                }
                            } else {
                                self.injectFieldIdentificationJS()
                            }
                        }
                    }
                }
                
            } else {
                // Completion handler if script not found
                let error = ASLException(errorMessages:Strings.ErrorScriptNotFound + "injectCaptchaIdentificationJS for amazon bg", errorTypes: .authChallenge, errorEventLog: .captcha, errorScrappingType: .html)
                self.completionHandler?(false, error)
            }
        }
           
    }
    
    private func injectFieldIdentificationJS() {
         self.getScript(orderSource: .Amazon, scriptKey: AppConstants.getSignInPromptTypeAmazon) { script in
            if !script.isEmpty {
                DispatchQueue.main.async {
                    self.webClient.evaluateJavaScript(script) { (response, error) in
                        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) { [weak self] in
                            guard let self = self else { return }
                            if let response = response as? String {
                                if response.contains("other") {
                                    let error = ASLException(errorMessages:Strings.ErrorOtherUrlLoaded, errorTypes: .authChallenge, errorEventLog: .unknownURL, errorScrappingType: .html)
                                    let exception = NSException(name: AppConstants.bsOrderFailed, reason: Strings.ErrorOtherUrlLoaded)
                                    FirebaseAnalyticsUtil.logSentryException(exception: exception)
                                    FirebaseAnalyticsUtil.logSentryError(error: error)
                                    self.completionHandler?(false, error)
                                } else if response.contains("emailId") {
                                    self.injectEmailJS()
                                } else {
                                    self.injectPasswordJS()
                                }
                            }
                        }
                    }
                }
            } else {
                // Completion handler if script not found
                let error = ASLException(errorMessages:Strings.ErrorScriptNotFound + "injectFieldIdentificationJS for amazon bg", errorTypes: .authChallenge, errorEventLog: .captcha, errorScrappingType: .html)
                self.completionHandler?(false, error)
            }
        }
         
    }
    
    private func injectEmailJS() {
        guard let email = self.account?.userID else {
            self.completionHandler?(false, ASLException(errorMessage: Strings.ErrorUserIdIsNil, errorType: .authError))
            return
        }
        self.getScript(orderSource: .Amazon, scriptKey: AppConstants.getEmailAmazon) { script in
            if !script.isEmpty {
                let emailJS = script.replacingOccurrences(of: "$email$", with: email)
                DispatchQueue.main.async {
                    self.webClient.evaluateJavaScript(emailJS) { (response, error) in
                        var logEventAttributes:[String:String] = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                                                  EventConstant.OrderSourceID: email]
                        if error != nil {
                            let authError = ASLException(errorMessages:Strings.ErrorEmailJSInjectionFailed, errorTypes: .authError, errorEventLog: .authentication, errorScrappingType: .html)
                            self.completionHandler?(false, authError)
                            
                            logEventAttributes[EventConstant.ErrorReason] = error.debugDescription
                            logEventAttributes[EventConstant.Status] = EventStatus.Failure
                        } else {
                            print("### injectEmailJS")
                            logEventAttributes[EventConstant.Status] = EventStatus.Success
                        }
                        FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgJSInjectUserName, eventAttributes: logEventAttributes)
                    }
                }
            } else {
                // Completion handler if script not found
                let error = ASLException(errorMessages:Strings.ErrorScriptNotFound + "injectEmailJS for amazon bg", errorTypes: .authChallenge, errorEventLog: .captcha, errorScrappingType: .html)
                self.completionHandler?(false, error)
            }
        }
    }
    
    private func injectPasswordJS() {
        guard let email = self.account?.userID else {
            let error = ASLException(errorMessage: Strings.ErrorUserIdIsNil, errorType: .authError)
            FirebaseAnalyticsUtil.logSentryError(error: error)
            self.completionHandler?(false, error)
            return
        }
        guard let password = self.account?.userPassword else {
            let error = ASLException(errorMessage: Strings.ErrorPasswordIsNil,errorType: .authError)
            FirebaseAnalyticsUtil.logSentryError(error: error)
            self.completionHandler?(false,error)
            return
        }
        self.getScript(orderSource: .Amazon, scriptKey: AppConstants.getPasswordAmazon) { script in
            if !script.isEmpty {
                let passwordJS = script.replacingOccurrences(of: "$password$", with: password)
                DispatchQueue.main.async {
                    self.webClient.evaluateJavaScript(passwordJS) { (response, error) in
                        var logEventAttributes:[String:String] = [:]
                        if error != nil {
                            let authError = ASLException(errorMessages:Strings.ErrorPasswordJSInjectionFailed, errorTypes: .authError, errorEventLog: .authentication, errorScrappingType: .html)
                            self.completionHandler?(false, authError)
                            
                            logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                                  EventConstant.OrderSourceID: email,
                                                  EventConstant.ErrorReason: error.debugDescription,
                                                  EventConstant.Status: EventStatus.Failure]
                            FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgJSInjectPassword, eventAttributes: logEventAttributes)
                        } else {
                            print("### injectPasswordJS")
                            logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                                  EventConstant.OrderSourceID: email,
                                                  EventConstant.Status: EventStatus.Success]
                            FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgJSInjectPassword, eventAttributes: logEventAttributes)
                        }
                    }
                }
            } else {
                // Completion handler if script not found
                let error = ASLException(errorMessages:Strings.ErrorScriptNotFound + "injectPasswordJS for amazon bg", errorTypes: .authChallenge, errorEventLog: .captcha, errorScrappingType: .html)
                self.completionHandler?(false, error)
            }
        }
    }
    
    private func getScript(orderSource: OrderSource, scriptKey: String, completionHandler: @escaping (String) -> Void) {
        BSScriptFileManager.shared.getAuthScript(orderSource: orderSource, scriptKey: scriptKey) { script in
          completionHandler(script)
        }
    }
}
