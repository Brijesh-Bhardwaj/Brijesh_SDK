//
//  BSWebDelegate.swift
//  OrderScrapper
//
//  Created by Avinash on 21/05/21.
//

import Foundation
import WebKit

internal protocol BSWebNavigationObserver {
    func didFinishPageNavigation(url: URL?)
    func didStartPageNavigation(url: URL?)
    func didFailPageNavigation(for url: URL?, withError error: Error)
}

internal class BSWebNavigationDelegate: NSObject, WKNavigationDelegate {
    private var observer: BSWebNavigationObserver?
    
    func setObserver(observer: BSWebNavigationObserver) {
        self.observer = nil
        self.observer = observer
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        preferences.preferredContentMode = .mobile
        decisionHandler(.allow, preferences)
    }
    
    internal func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let observer = self.observer {
            observer.didFinishPageNavigation(url: webView.url)
        }
    }
    
    internal func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if let observer = self.observer {
            observer.didStartPageNavigation(url: webView.url)
        }
    }
    
    internal func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.didFailNavigation(for: webView.url, withError: error)
    }
    
    internal func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.didFailNavigation(for: webView.url, withError: error)
    }
    
    private func didFailNavigation(for url: URL?, withError error: Error) {
        if let observer = self.observer {
            observer.didFailPageNavigation(for: url, withError: error)
        }
    }
    
    private func removeObserver() {
        self.observer = nil
    }
}
