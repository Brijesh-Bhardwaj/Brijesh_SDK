//  BSBaseAuthenticator.swift
//  OrderScrapper


import Foundation
import WebKit

class BSBaseAuthenticator: NSObject, BSAuthenticator {
    var listener: BSAuthenticationStatusListener?
    var webClient: BSWebClient
    var account: Account?
    var configurations: Configurations?
    var webClientDelegate: BSWebNavigationDelegate

    init(webClient: BSWebClient, delegate: BSWebNavigationDelegate, listener: BSAuthenticationStatusListener) {
        self.webClient = webClient
        self.listener = listener
        self.webClientDelegate = delegate
    }
    
    func authenticate(account: Account, configurations: Configurations) {
        self.account = account
        self.webClientDelegate.setObserver(observer: self)
        self.webClient.navigationDelegate = webClientDelegate
        self.webClient.loadUrl(url: configurations.login)
        self.configurations = configurations
    }
    
    func onPageFinish(url: String) throws {
        throw ASLException(errorMessage: Strings.ErrorChildClassShouldImplementMethod, errorType: nil)
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
        print(AppConstants.tag, Strings.ErrorDuringNavigation, error.localizedDescription)
    }
}
