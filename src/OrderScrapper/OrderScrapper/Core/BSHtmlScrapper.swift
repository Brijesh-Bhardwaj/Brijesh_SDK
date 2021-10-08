//  BSHtmlScrapper.swift
//  OrderScrapper

import Foundation
import WebKit
import Sentry

class BSHtmlScrapperParams {
    let webClient: BSWebClient
    let webNavigationDelegate: BSWebNavigationDelegate
    let listener: BSHtmlScrappingStatusListener
    let authenticator: BSAuthenticator
    let configuration: Configurations
    let account: Account
    let scrappingType: String?
    
    init(webClient: BSWebClient,
         webNavigationDelegate: BSWebNavigationDelegate,
         listener: BSHtmlScrappingStatusListener,
         authenticator: BSAuthenticator,
         configuration: Configurations,
         account: Account,
         scrappingType: String?) {
        self.webClient = webClient
        self.webNavigationDelegate = webNavigationDelegate
        self.listener = listener
        self.authenticator = authenticator
        self.configuration = configuration
        self.account = account
        self.scrappingType = scrappingType
    }
}

class BSHtmlScrapper {
    private let LoginURLDelimiter = "/?"
    private let URLQueryDelimiter = "?"
    private let params: BSHtmlScrapperParams
    private var script: String?
    private var url: String!
    private var loginDetected = false
    private var dateRange: DateRange?
    var timer = BSTimer()
    
    init(params: BSHtmlScrapperParams) {
        self.params = params
        self.params.webNavigationDelegate.setObserver(observer: self)
        self.params.webClient.scriptMessageHandler?.addScriptMessageListener(listener: self)
    }
    
    func extractOrders(script: String, url: String) {
        self.script = script
        self.url = url
        self.loginDetected = false
        self.params.webClient.loadListingUrl(url: url)
    }
    
    private func getSubURL(from url: String, delimeter: String) -> String {
        if url.contains(delimeter) {
            return Utils.getSubUrl(url: url, delimeter: delimeter)
        }
        return url
    }
    
    private func didFinishWith(error: ASLException) {
        do {
            try CoreDataManager.shared.updateUserAccount(userId: self.params.account.userID, accountStatus: AccountState.ConnectedButException.rawValue, panelistId: self.params.account.panelistID)
        } catch {
            print("updateAccountWithExceptionState")
        }
        _ = AmazonService.updateStatus(amazonId: self.params.account.userID, status: AccountState.ConnectedButException.rawValue, message: AppConstants.msgAuthError, orderStatus: OrderStatus.Failed.rawValue) { response, error in
            
            //TODO
        }
        FirebaseAnalyticsUtil.logSentryError(error: error)
        let exception = NSException(name: AppConstants.bsOrderFailed, reason: error.errorMessage)
        FirebaseAnalyticsUtil.logSentryException(exception: exception)
        self.params.listener.onHtmlScrappingFailure(error: error)
    }
}

extension BSHtmlScrapper: ScriptMessageListener {
    func onScriptMessageReceive(message: WKScriptMessage) {
        print("### onScriptMessageReceive")
        if message.name == "iOS" {
            let data = message.body as! String
            self.params.listener.onHtmlScrappingSucess(response: data)
        }
    }
}

extension BSHtmlScrapper: BSWebNavigationObserver {
    func didFinishPageNavigation(url: URL?) {
        if let url = url?.absoluteString, let script = script {
            let loginSubURL = getSubURL(from: self.params.configuration.login, delimeter: LoginURLDelimiter)
            let subURL = getSubURL(from: self.url, delimeter: URLQueryDelimiter)
            if ((url.contains(loginSubURL) || loginSubURL.contains(url)) && !loginDetected) {
                self.loginDetected = true
                self.params.authenticator.authenticate(account: self.params.account,
                                                       configurations: self.params.configuration) { [weak self] authenticated, error in
                    guard let self = self else { return }
                    
                    if authenticated {
                        self.params.webNavigationDelegate.setObserver(observer: self)
                        self.params.webClient.scriptMessageHandler?.addScriptMessageListener(listener: self)
                        self.params.webClient.loadListingUrl(url: self.url)
                        
                        var logEventAttributes:[String:String] = [:]
                        logEventAttributes = [EventConstant.Status: EventStatus.Success]
                        FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgAuthentication, eventAttributes: logEventAttributes)
                    } else {
                        if error?.errorMessage == "Captcha page loaded" || error?.errorMessage == "Other url loaded" {
//                            let errorMessage = ASLException(errorMessage: Strings.ErrorOtherUrlLoaded, errorType: .authError)
                            let errorMessage = ASLException(errorMessages: Strings.ErrorOtherUrlLoaded, errorTypes: .authError, errorEventLog: .unknownURL, errorScrappingType: ScrappingType.html)
                            self.onAuthenticationFailure(error: errorMessage)
                        } else {
                            let errorMessage = ASLException(errorMessages: Strings.ErrorPasswordJSInjectionFailed, errorTypes: .authError, errorEventLog: .other, errorScrappingType: ScrappingType.html)
                            self.didFinishWith(error: errorMessage)
                            var logEventAttributes:[String:String] = [:]
                            logEventAttributes = [EventConstant.ErrorReason: error!.errorMessage,
                                                  EventConstant.Status: EventStatus.Failure]
                            FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgAuthentication, eventAttributes: logEventAttributes)
                        }
                        
                    }
                }
            } else if(url.contains(subURL) || subURL.contains(url)) {
                print("### Injecting script for URL: ", url)
                self.params.webClient.evaluateJavaScript(script) { response, error in
                    print("#### evaluateJavaScript")
                    //SentrySDK.capture(message: url)
                }
            } else {
//                let error = ASLException(errorMessage: Strings.ErrorOtherUrlLoaded, errorType: .authError)
                let error = ASLException(errorMessages: Strings.ErrorOtherUrlLoaded, errorTypes: nil, errorEventLog: .unknownURL, errorScrappingType: ScrappingType.html)
                let exception = NSException(name: AppConstants.bsOrderFailed, reason: url)
                FirebaseAnalyticsUtil.logSentryException(exception: exception)
                FirebaseAnalyticsUtil.logSentryError(error: error)
                self.onAuthenticationFailure(error: error)
                
                var logOtherUrlEventAttributes:[String:String] = [:]
                let userId = params.account.userID
                logOtherUrlEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                              EventConstant.OrderSourceID: userId,
                                              EventConstant.Status: EventStatus.Success,
                                              EventConstant.URL: url]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgJSDetectOtherURL, eventAttributes: logOtherUrlEventAttributes)
            }
        } else {
//            let error = ASLException(errorMessage: Strings.ErrorPageNotloaded, errorType: nil)
            let error = ASLException(errorMessages: Strings.ErrorPageNotloaded, errorTypes: nil, errorEventLog: .pageNotLoded, errorScrappingType: ScrappingType.html)
            FirebaseAnalyticsUtil.logSentryError(error: error)
            self.params.listener.onHtmlScrappingFailure(error: error)
        }
    }
    
    func didStartPageNavigation(url: URL?) {
        if url == nil {
            let error = ASLException(errorMessages: Strings.ErrorPageNotloaded, errorTypes: nil, errorEventLog: .pageNotLoded, errorScrappingType: ScrappingType.html)
            FirebaseAnalyticsUtil.logSentryError(error: error)
            self.params.listener.onHtmlScrappingFailure(error: error)
        }
    }
    
    func didFailPageNavigation(for url: URL?, withError error: Error) {
        let error = ASLException(errorMessages: Strings.ErrorOrderExtractionFailed, errorTypes: nil, errorEventLog: .pageNotLoded, errorScrappingType: ScrappingType.html)
        FirebaseAnalyticsUtil.logSentryError(error: error)
        self.params.listener.onHtmlScrappingFailure(error: error)
    }
    
    func onAuthenticationFailure(error: ASLException) {
        let failureCount = UserDefaults.standard.integer(forKey: Strings.OnNumberOfCaptchaRetry)
        UserDefaults.standard.setValue(failureCount + 1, forKey: Strings.OnNumberOfCaptchaRetry)
        let currentDate = Date().timeIntervalSince1970
        UserDefaults.standard.setValue(currentDate, forKey: Strings.OnBackgroundScrappingTimeOfPeriod)
        
        self.shouldShowAlert { boolValue in
            if boolValue {
                let error = ASLException(errorMessages: Strings.ErrorOnAuthenticationChallenge, errorTypes: error.errorType, errorEventLog: .notify, errorScrappingType: error.errorScrappingType)
                self.params.listener.onHtmlScrappingFailure(error: error)
            } else {
                self.params.listener.onHtmlScrappingFailure(error: error)
            }
        }
    }
    
    func shouldShowAlert(completion: @escaping (Bool) -> Void) {
        
        //TODO:- Add orderSource 
        ConfigManager.shared.getConfigurations(orderSource: .Amazon) { (configurations, error) in
            if let configuration = configurations {
                let showNotification = self.dateRange?.showNotification ?? false
                let captchaRetries = configuration.captchaRetries
                let failureCount = UserDefaults.standard.integer(forKey: Strings.OnNumberOfCaptchaRetry)
                completion(showNotification || failureCount > captchaRetries!)
            } else {
                completion(false)
            }
        }
    }
}
