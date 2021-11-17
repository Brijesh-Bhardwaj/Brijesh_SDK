//  BSBaseAuthenticator.swift
//  OrderScrapper


import Foundation
import WebKit
import Sentry

class BSBaseAuthenticator: NSObject, BSAuthenticator {
    var webClient: BSWebClient
    var account: Account?
    var configurations: Configurations?
    var webClientDelegate: BSWebNavigationDelegate
    var completionHandler: ((Bool, ASLException?) -> Void)?
    
    init(webClient: BSWebClient, delegate: BSWebNavigationDelegate) {
        self.webClient = webClient
        self.webClientDelegate = delegate
    }
    
    func authenticate(account: Account,
                      configurations: Configurations,
                      completionHandler: @escaping ((Bool, ASLException?) -> Void)) {
        self.account = account
        self.completionHandler = completionHandler
        self.webClientDelegate.setObserver(observer: self)
        self.webClient.navigationDelegate = webClientDelegate
        self.webClient.loadUrl(url: configurations.login)
        self.configurations = configurations
    }
    
    func onPageFinish(url: String) throws {
        let error = ASLException(errorMessage: Strings.ErrorChildClassShouldImplementMethod, errorType: nil)
        FirebaseAnalyticsUtil.logSentryError(error: error)
        throw error
    }
}

extension BSBaseAuthenticator: BSWebNavigationObserver {
    func didFinishPageNavigation(url: URL?) {
        guard let url = url?.absoluteString else {
            return
        }
        try! self.onPageFinish(url: url)
    }
    
    func didStartPageNavigation(url: URL?) {
        // TODO: Log event
    }
    
    func didFailPageNavigation(for url: URL?, withError error: Error) {
        var logEventAttributes:[String:String] = [:]
        logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                              EventConstant.PanelistID: self.account!.panelistID,
                              EventConstant.OrderSourceID: self.account!.userID,
                              EventConstant.ScrappingMode: ScrapingMode.Foreground.rawValue,
                              EventConstant.EventName: EventType.DidFailPageNavigation,
                              EventConstant.Status: EventStatus.Failure]
        if let url = url {
            logEventAttributes[EventConstant.URL] = url.absoluteString
        }
        FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
        print(AppConstants.tag, Strings.ErrorDuringNavigation, error.localizedDescription)
    }
}
