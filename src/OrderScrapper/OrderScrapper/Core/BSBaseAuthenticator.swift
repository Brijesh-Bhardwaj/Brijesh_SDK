//  BSBaseAuthenticator.swift
//  OrderScrapper


import Foundation
import WebKit

class BSBaseAuthenticator: NSObject, BSAuthenticator {
    var listener: BSAuthenticationStatusListener?
    var webClient: BSWebClient
    var account: Account?
    var configurations: Configurations?

    init(webClient: BSWebClient, listener: BSAuthenticationStatusListener) {
        self.webClient = webClient
        self.listener = listener
    }
    
    func authenticate(account: Account, configurations: Configurations) {
        self.account = account
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
