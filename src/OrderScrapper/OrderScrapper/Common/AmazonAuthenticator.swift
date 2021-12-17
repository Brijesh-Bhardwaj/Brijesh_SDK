//
//  AmazonAuthenticator.swift
//  OrderScrapper
//

import Foundation
import WebKit
import SwiftUI
import Combine
import Sentry

enum JSInjectValue {
    case email, password, captcha, error, identification, generateReport, downloadReport, dateRange
    var value: String {
        return String(describing: self)
    }
}

internal class AmazonAuthenticator: Authenticator {
    @ObservedObject var viewModel: WebViewModel
    
    private var isPasswordInjected: Bool = false
    private var isAuthenticated: Bool = false
    
    var jsResultSubscriber: AnyCancellable? = nil
    
    required init(_ viewModel: WebViewModel) {
        self.viewModel = viewModel
    }
    
    deinit {
        self.jsResultSubscriber?.cancel()
    }
    
    func authenticate() {
        self.jsResultSubscriber = viewModel.jsResultPublisher.receive(on: RunLoop.main)
            .sink(receiveValue: { [weak self] (injectValue, result) in
                guard let self = self else { return }
                let (response, error) = result
                switch injectValue {
                case .email:
                    if error != nil {
                        self.notifyAuthError(errorMessage: AppConstants.msgUnknownURL)
                    }
                case .password:
                    if error != nil {
                        self.notifyAuthError(errorMessage: AppConstants.msgUnknownURL)
                    } else {
                        self.isPasswordInjected = true
                    }
                case .generateReport, .downloadReport, .dateRange: break
                case .error:
                    if let response = response {
                        let strResult = response as! String
                        if (strResult.isEmpty) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) { [weak self] in
                                guard let self = self else {return}
                                self.injectCaptchaIdentificationJS()
                            }
                        } else {
                            self.notifyAuthError(errorMessage: strResult)
                        }
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) { [weak self] in
                            guard let self = self else {return}
                            self.injectCaptchaIdentificationJS()
                        }
                    }
                case .identification:
                    if let response = response as? String {
                        if response.contains("other") {
                            self.viewModel.showWebView.send(true)
                            FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_identification_other")

                        } else if response.contains("emailId") {
                            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) { [weak self] in
                                guard let self = self else {return}
                                self.injectEmailJS()
                                FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_identification_email")
                            }
                        } else {
                            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) { [weak self] in
                                guard let self = self else {return}
                                self.injectPasswordJS()
                            }
                        }
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) { [weak self] in
                            guard let self = self else {return}
                            self.injectPasswordJS()
                        }
                    }
                case .captcha:
                    if let response = response as? String {
                        if response.contains("captcha") {
                            self.updateAccountWithExceptionState(message: AppConstants.msgCapchaEncountered)
                            self.viewModel.showWebView.send(true)
                            
                            var logEventAttributes:[String:String] = [:]
                            logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                                  EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                                  EventConstant.PanelistID: self.viewModel.userAccount.panelistID,
                                                  EventConstant.ScrappingType: ScrappingType.report.rawValue,
                                                  EventConstant.ScrappingMode: ScrapingMode.Foreground.rawValue,
                                                  EventConstant.Status: EventStatus.Success]
                            FirebaseAnalyticsUtil.logEvent(eventType: EventType.EncounteredCaptcha, eventAttributes: logEventAttributes)
                        } else {
                            if self.isPasswordInjected {
                                self.isPasswordInjected = false
                                self.isAuthenticated = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) { [weak self] in
                                guard let self = self else {return}
                                self.injectFieldIdentificationJS()
                            }
                        }
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) { [weak self] in
                            guard let self = self else {return}
                            self.injectFieldIdentificationJS()
                        }
                    }
                }
            })
        
        self.injectAuthErrorVerificationJS()
    }
    
    private func injectAuthErrorVerificationJS() {
        let js = "(function() { var element = document.getElementById('auth-error-message-box');" +
            "if (element != null && element.innerHTML !== null) " +
            "{return element.getElementsByClassName('a-list-item')[0].innerText;} else {" +
            " return ''}})()"
        
        self.viewModel.jsPublisher.send((.error, js))
    }
    
    private func injectEmailJS() {
        let email = self.viewModel.userAccount.userID
        let js = "javascript:" +
            "document.getElementById('ap_email_login').value = '" + email + "';" + "document.querySelector('#accordion-row-login #continue #continue').click()"
        
        self.viewModel.jsPublisher.send((.email, js))
    }
    
    private func injectPasswordJS() {
        let password = self.viewModel.userAccount.userPassword
        let js = "javascript:" +
            "document.getElementById('ap_password').value = '" + password + "';" +
            "document.getElementById('signInSubmit').click()"
        
        self.viewModel.jsPublisher.send((.password, js))
    }
    
    private func injectFieldIdentificationJS() {
        let js = "(function() { var element = document.getElementById('ap_email_login');" +
            "if (element != null && element.innerHTML !== null) " +
            " { return 'emailId' } else { " +
            " var element = document.getElementById('ap_password');" +
            " if (element != null && element.innerHTML !== null) " +
            " { return 'pwd'} else { return 'other' }}})()"
        
        self.viewModel.jsPublisher.send((.identification, js))
    }
    
    private func injectCaptchaIdentificationJS() {
        let js = "(function() { var element = document.getElementById('auth-captcha-guess');" +
            "if (element != null && element.innerHTML !== null) " +
            "{return 'captcha'} else {" +
            " return null}})()"
        
        self.viewModel.jsPublisher.send((.captcha, js))
        
    }
    
    private func updateAccountWithExceptionState(message: String) {
        let userId = self.viewModel.userAccount.userID
        let panelistId = LibContext.shared.authProvider.getPanelistID()
        let accountState = self.viewModel.userAccount.accountState
        let orderSource = self.viewModel.userAccount.source.value
        var status: String = ""
        var orderStatus = ""
        
        switch accountState {
        case .NeverConnected:
            status = AccountState.NeverConnected.rawValue
            orderStatus = OrderStatus.None.rawValue
        case .ConnectedButException, .ConnectedAndDisconnected, .Connected:
            status = AccountState.ConnectedButException.rawValue
            orderStatus = OrderStatus.None.rawValue
            do {
                try CoreDataManager.shared.updateUserAccount(userId: self.viewModel.userAccount.userID, accountStatus: AccountState.ConnectedButException.rawValue, panelistId: panelistId, orderSource: self.viewModel.userAccount.source.rawValue)
            } catch let error {
                print(AppConstants.tag, "updateAccountWithExceptionState", error.localizedDescription)
                
                let logEventAttributes:[String:String] = [EventConstant.PanelistID: panelistId,
                                                          EventConstant.OrderSourceID: userId,
                                                          EventConstant.ScrappingType: ScrappingType.report.rawValue,
                                                          EventConstant.ScrappingMode: ScrapingMode.Foreground.rawValue]
                FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
            }
        case .ConnectedButScrappingFailed:
            status = AccountState.ConnectedButException.rawValue
            orderStatus = OrderStatus.Failed.rawValue
        case .ConnectionInProgress:
            print("")
        }
        _ = AmazonService.updateStatus(platformId: userId, status: status
                                       , message: message, orderStatus: orderStatus, orderSource: OrderSource.Amazon.value) { response, error in
            //Todo
        }
        let eventLog = EventLogs(panelistId: panelistId, platformId: userId, section: SectionType.connection.rawValue, type:  FailureTypes.captcha.rawValue, status: EventState.fail.rawValue, message: message, fromDate: nil, toDate: nil, scrapingType: nil, scrapingContext: ScrapingMode.Foreground.rawValue)
        _ = AmazonService.logEvents(eventLogs: eventLog, orderSource: orderSource) { response, error in
                //TODO
        }
    }
    
    private func notifyAuthError(errorMessage: String) {
        let panelistId = LibContext.shared.authProvider.getPanelistID()
        let accountState = self.viewModel.userAccount.accountState.rawValue
        let orderSource = self.viewModel.userAccount.source.value
        if accountState == AccountState.NeverConnected.rawValue {
            let userId = self.viewModel.userAccount.userID
            _ = AmazonService.registerConnection(platformId: userId,
                                                 status: AccountState.NeverConnected.rawValue,
                                                 message: errorMessage, orderStatus: OrderStatus.None.rawValue, orderSource: OrderSource.Amazon.value) { response, error in
                var logEventAttributes:[String:String] = [:]
                logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                      EventConstant.OrderSourceID: self.viewModel.userAccount.userID,
                                      EventConstant.PanelistID: self.viewModel.userAccount.panelistID,
                                      EventConstant.ScrappingMode: ScrapingMode.Foreground.rawValue]
                if let response = response  {
                    //TODO Add response in attributes
                    logEventAttributes[EventConstant.Status] = EventStatus.Success
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.APIRegisterUser, eventAttributes: logEventAttributes)
                } else {
                    logEventAttributes[EventConstant.Status] = EventStatus.Failure
                    if let error = error {
                        logEventAttributes[EventConstant.EventName] = EventType.UserRegistrationAPIFailed
                        FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
                    } else {
                        FirebaseAnalyticsUtil.logEvent(eventType: EventType.UserRegistrationAPIFailed, eventAttributes: logEventAttributes)
                    }
                }
            }
            let eventLog = EventLogs(panelistId: panelistId, platformId: userId, section: SectionType.connection.rawValue, type:  FailureTypes.authentication.rawValue, status: EventState.fail.rawValue, message: errorMessage, fromDate: nil, toDate: nil, scrapingType: nil, scrapingContext: ScrapingMode.Foreground.rawValue)
            _ = AmazonService.logEvents(eventLogs: eventLog, orderSource: orderSource) { response, error in
                //TODO
            }
        } else {
            self.updateAccountWithExceptionState(message: AppConstants.msgAuthError)
        }
        self.viewModel.authError.send((true, errorMessage))
        WebCacheCleaner.clear(completionHandler: nil)
    }
    
    func resetAuthenticatedFlag() {
        isAuthenticated = false
    }
    
    func isUserAuthenticated() -> Bool {
        return isAuthenticated
    }
}
