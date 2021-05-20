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
        self.webClient.navigationDelegate = self
        self.account = account
        self.webClient.loadUrl(url: configurations.login)
        self.configurations = configurations
    }
    
    func onPageFinish(url: String) throws {
        throw ASLException(errorMessage: Strings.ErrorChildClassShouldImplementMethod, errorType: nil)
    }
}

extension BSBaseAuthenticator: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let url = webView.url?.absoluteString
        guard let urlString = url else { return }
        
        do {
            try  self.onPageFinish(url: urlString)
        } catch {
        }
    }
    
    // This function is essential for intercepting every navigation in the webview
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 preferences: WKWebpagePreferences,
                 decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        preferences.preferredContentMode = .mobile
        decisionHandler(.allow, preferences)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print(AppConstants.tag, Strings.ErrorDuringNavigation, error.localizedDescription)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print(AppConstants.tag,Strings.ErrorDuringEarlyNavigation, error.localizedDescription)
    }
    
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        print(AppConstants.tag, Strings.ErrorWebContentProcessDidTerminate)
    }
}
