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
    private let scraperListener: ScraperProgressListener
    var jsResultSubscriber: AnyCancellable? = nil
    
    required init(_ viewModel: WebViewModel,_ scraperListener: ScraperProgressListener) {
        self.viewModel = viewModel
        self.scraperListener = scraperListener
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
                            self.updateAccountWithExceptionState(message: AppConstants.msgCapchaEncountered,failureTypes: FailureTypes.captcha.rawValue,eventState: EventState.Info.rawValue)
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
       self.getScript(orderSource: .Amazon, scriptKey: AppConstants.checkIfSignInErrorAmazon) { script in
            if !script.isEmpty {
                self.viewModel.jsPublisher.send((.error, script))
            } else {
                self.logEvent(message: Strings.ErrorScriptNotFound + "injectAuthErrorVerificationJS for amazon")
                FirebaseAnalyticsUtil.logSentryError(error: ASLException(errorMessage: Strings.ErrorScriptNotFound + "injectAuthErrorVerificationJS for amazon", errorType: .authError))
                self.viewModel.authError.send((isError: true, errorMsg: AppConstants.msgTimeout))
            }
        }
    }
    
    private func injectEmailJS() {
     self.getScript(orderSource: .Amazon, scriptKey: AppConstants.getEmailAmazon) { script in
            if !script.isEmpty {
                let email = self.viewModel.userAccount.userID
                let emailLoginJS = script.replacingOccurrences(of: "$email$", with: email)
                self.viewModel.jsPublisher.send((.email, emailLoginJS))
            } else {
                self.logEvent(message: Strings.ErrorScriptNotFound + "injectEmailJS for amazon")
                FirebaseAnalyticsUtil.logSentryError(error: ASLException(errorMessage:  Strings.ErrorScriptNotFound + "injectEmailJS for amazon", errorType: .authError))
                self.viewModel.authError.send((isError: true, errorMsg: AppConstants.msgTimeout))
            }
        }
    }
    
    private func injectPasswordJS() {
        self.getScript(orderSource: .Amazon, scriptKey: AppConstants.getPasswordAmazon) { script in
                if !script.isEmpty {
                    let password = self.viewModel.userAccount.userPassword
                    let passwordLoginJS = script.replacingOccurrences(of: "$password$", with: password)
                    self.viewModel.jsPublisher.send((.password, passwordLoginJS))
                } else {
                    self.logEvent(message: Strings.ErrorScriptNotFound + "injectPasswordJS for amazon")
                    FirebaseAnalyticsUtil.logSentryError(error: ASLException(errorMessage: Strings.ErrorScriptNotFound + "injectPasswordJS for amazon", errorType: .authError))
                    self.viewModel.authError.send((isError: true, errorMsg: AppConstants.msgTimeout))
                }
        }
    }
    
    private func injectFieldIdentificationJS() {
        self.getScript(orderSource: .Amazon, scriptKey: AppConstants.getSignInPromptTypeAmazon) { script in
                if !script.isEmpty {
                    self.viewModel.jsPublisher.send((.identification, script))
                } else {
                    self.logEvent(message: Strings.ErrorScriptNotFound + "injectFieldIdentificationJS for amazon")
                    FirebaseAnalyticsUtil.logSentryError(error: ASLException(errorMessage: Strings.ErrorScriptNotFound + "injectFieldIdentificationJS for amazon", errorType: .authError))
                    self.viewModel.authError.send((isError: true, errorMsg: AppConstants.msgTimeout))
                }
        }
    }
    
    private func injectCaptchaIdentificationJS() {
        self.getScript(orderSource: .Amazon, scriptKey: AppConstants.captchaAmazon) { script in
            if !script.isEmpty {
                self.viewModel.jsPublisher.send((.captcha, script))
            } else {
                self.logEvent(message: Strings.ErrorScriptNotFound + "injectCaptchaIdentificationJS for amazon")
                FirebaseAnalyticsUtil.logSentryError(error: ASLException(errorMessage: Strings.ErrorScriptNotFound + "injectCaptchaIdentificationJS for amazon", errorType: .authError))
                self.viewModel.authError.send((isError: true, errorMsg: AppConstants.msgTimeout))
            }
        }
    }
    
    private func logEvent(message: String) {
        let eventLogs = EventLogs(panelistId: self.viewModel.userAccount.panelistID, platformId:self.viewModel.userAccount.userID, section: SectionType.connection.rawValue, type: TimeoutTypes.timeoutAuth.rawValue, status: EventState.fail.rawValue, message: message, fromDate: nil, toDate: nil, scrapingType: ScrappingType.html.rawValue, scrapingContext: ScrapingMode.Foreground.rawValue,url:"")
        _ = AmazonService.logEvents(eventLogs: eventLogs, orderSource: self.viewModel.userAccount.source.value) {  response, error in
            
            if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
                self.sendServicesDownCallback()
            }
        }
    }
    
    private func updateAccountWithExceptionState(message: String,failureTypes:String,eventState:String) {
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
            
            logPushEvent( message: AppConstants.authFail)

        case .ConnectedButScrappingFailed:
            status = AccountState.ConnectedButException.rawValue
            orderStatus = OrderStatus.Failed.rawValue
            

        case .ConnectionInProgress:
            print("")
        }
        _ = AmazonService.updateStatus(platformId: userId, status: status
                                       , message: message, orderStatus: orderStatus, orderSource: OrderSource.Amazon.value) { response, error in

            if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
                self.sendServicesDownCallback()
            }
        }

        let eventLog = EventLogs(panelistId: panelistId, platformId: userId, section: SectionType.connection.rawValue, type:  failureTypes, status: eventState, message: message, fromDate: nil, toDate: nil, scrapingType: nil, scrapingContext: ScrapingMode.Foreground.rawValue,url:"")
        _ = AmazonService.logEvents(eventLogs: eventLog, orderSource: orderSource) { response, error in

            if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
                self.sendServicesDownCallback()
            }
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
                    logEventAttributes[EventConstant.Status] = EventStatus.Success
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.APIRegisterUser, eventAttributes: logEventAttributes)
                } else {
                    logEventAttributes[EventConstant.Status] = EventStatus.Failure
                    if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
                        self.sendServicesDownCallback()
                    } else if let error = error {
                        logEventAttributes[EventConstant.EventName] = EventType.UserRegistrationAPIFailed
                        FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
                    } else {
                        FirebaseAnalyticsUtil.logEvent(eventType: EventType.UserRegistrationAPIFailed, eventAttributes: logEventAttributes)
                    }
                }
            }

            let eventLog = EventLogs(panelistId: panelistId, platformId: userId, section: SectionType.connection.rawValue, type:  FailureTypes.authentication.rawValue, status: EventState.fail.rawValue, message: errorMessage, fromDate: nil, toDate: nil, scrapingType: nil, scrapingContext: ScrapingMode.Foreground.rawValue,url:"")
            _ = AmazonService.logEvents(eventLogs: eventLog, orderSource: orderSource) { response, error in

                if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
                    self.sendServicesDownCallback()
                }
            }
        } else {
            self.updateAccountWithExceptionState(message: AppConstants.msgAuthError,failureTypes:FailureTypes.authentication.rawValue,eventState: EventState.fail.rawValue)
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
    func sendServicesDownCallback() {
        let error = ASLException(error: nil, errorMessage: Strings.ErrorServicesDown, failureType: .servicesDown)
        self.scraperListener.onServicesDown(error: error)
    }
    
    private func getScript(orderSource: OrderSource, scriptKey: String, completionHandler: @escaping(String) -> Void) {
            BSScriptFileManager.shared.getAuthScript(orderSource: orderSource, scriptKey: scriptKey) { script in
                if !script.isEmpty {
                    completionHandler(script)
                } else {
                    BSScriptFileManager.shared.getNewAuthScript(orderSource: orderSource, scriptKey: scriptKey) { script in
                        print("!!!! Script found",script)
                        completionHandler(script)
                    }
                }
            }
    }
    
    private func logPushEvent(message:String){
        let eventLogs = EventLogs(panelistId:  self.viewModel.userAccount.panelistID, platformId:self.viewModel.userAccount.userID, section: SectionType.orderUpload.rawValue, type: FailureTypes.none.rawValue, status: EventState.Info.rawValue, message: message, fromDate: nil, toDate: nil, scrapingType: ScrappingType.html.rawValue, scrapingContext: ScrapingMode.Foreground.rawValue,url:nil)
        _ = AmazonService.logEvents(eventLogs: eventLogs, orderSource: self.viewModel.userAccount.source.value) { response, error in}
    }
}
