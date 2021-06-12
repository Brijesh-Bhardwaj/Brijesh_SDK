//  BSHtmlScrapper.swift
//  OrderScrapper

import Foundation
import WebKit

class BSHtmlScrapperParams {
    let webClient: BSWebClient
    let webNavigationDelegate: BSWebNavigationDelegate
    let listener: BSHtmlScrappingStatusListener
    let authenticator: BSAuthenticator
    let configuration: Configurations
    let account: Account
    
    init(webClient: BSWebClient,
         webNavigationDelegate: BSWebNavigationDelegate,
         listener: BSHtmlScrappingStatusListener,
         authenticator: BSAuthenticator,
         configuration: Configurations,
         account: Account) {
        self.webClient = webClient
        self.webNavigationDelegate = webNavigationDelegate
        self.listener = listener
        self.authenticator = authenticator
        self.configuration = configuration
        self.account = account
    }
}

class BSHtmlScrapper {
    private let LoginURLDelimiter = "/?"
    private let params: BSHtmlScrapperParams
    private var script: String?
    private var url: String!
    
    init(params: BSHtmlScrapperParams) {
        self.params = params
        self.params.webNavigationDelegate.setObserver(observer: self)
        self.params.webClient.scriptMessageHandler?.addScriptMessageListener(listener: self)
    }
    
    func extractOrders(script: String, url: String) {
        self.script = script
        self.url = url
        self.params.webClient.loadListingUrl(url: url)
    }
    
    private func getSubURL(from url: String, delimeter: String) -> String {
        if url.contains(delimeter) {
            return Utils.getSubUrl(url: url, delimeter: delimeter)
        }
        return url
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
            if (url.contains(loginSubURL) || loginSubURL.contains(url)) {
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
                        do {
                            try CoreDataManager.shared.updateUserAccount(userId: self.params.account.userID, accountStatus: AccountState.ConnectedButException.rawValue, panelistId: self.params.account.panelistID)
                        } catch {
                            print("updateAccountWithExceptionState")
                        }
                        
                        self.params.listener.onHtmlScrappingFailure(error: error!)
                        
                        var logEventAttributes:[String:String] = [:]
                        logEventAttributes = [EventConstant.ErrorReason: error!.errorMessage,
                                              EventConstant.Status: EventStatus.Failure]
                        FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgAuthentication, eventAttributes: logEventAttributes)
                    }
                }
            } else {
                print("### Injecting script for URL: ", url)
                self.params.webClient.evaluateJavaScript(script) { response, error in
                    print("#### evaluateJavaScript")
                }
            }
        } else {
            self.params.listener.onHtmlScrappingFailure(error: ASLException(errorMessage: Strings.ErrorPageNotloaded, errorType: nil))
        }
    }
    
    func didStartPageNavigation(url: URL?) {
        if url == nil {
            self.params.listener.onHtmlScrappingFailure(error: ASLException(errorMessage: Strings.ErrorPageNotloaded, errorType: nil))
        }
    }
    
    func didFailPageNavigation(for url: URL?, withError error: Error) {
        self.params.listener.onHtmlScrappingFailure(error: ASLException(errorMessage: Strings.ErrorOrderExtractionFailed, errorType: nil))
    }
}
