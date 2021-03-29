//
//  WebView.swift
//  OrderScrapper
//

import Foundation
import UIKit
import SwiftUI
import Combine
import WebKit

// MARK: - WebView
struct WebView: UIViewRepresentable {
    let baseURL = "https://www.amazon.com/ap/signin?_encoding=UTF8&openid.assoc_handle=usflex&openid.claimed_id=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0%2Fidentifier_select&openid.identity=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0%2Fidentifier_select&openid.mode=checkid_setup&openid.ns=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0&openid.ns.pape=http%3A%2F%2Fspecs.openid.net%2Fextensions%2Fpape%2F1.0&openid.pape.max_auth_age=900&openid.return_to=https%3A%2F%2Fwww.amazon.com%2Fgp%2Fb2b%2Freports%2F136-9723095-1427523%3Fie%3DUTF8%26%252AVersion%252A%3D1%26%252Aentries%252A%3D0"
    
    // Viewmodel object
    @ObservedObject var viewModel: WebViewModel
    
    // Make a coordinator to co-ordinate with WKWebView's default delegate functions
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        // Enable javascript in WKWebView
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        
        let configuration = WKWebViewConfiguration()
        // Here "iOSNative" is our delegate name that we pushed to the website that is being loaded
        configuration.userContentController.add(self.makeCoordinator(), name: "iOSNative")
        configuration.preferences = preferences
        
        let webView = WKWebView(frame: CGRect.zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        if let url = URL(string: baseURL) {
            webView.load(URLRequest(url: url))
        }
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        
    }
    
    class Coordinator : NSObject, WKNavigationDelegate {
        var parent: WebView
        var jsSubscriber: AnyCancellable? = nil
        var navigationSubscriber: AnyCancellable? = nil
        
        let navigationHelper: NavigationHelper
        
        init(_ uiWebView: WebView) {
            self.parent = uiWebView
            self.navigationHelper = AmazonNavigationHelper(self.parent.viewModel)
        }
        
        deinit {
            jsSubscriber?.cancel()
            navigationSubscriber?.cancel()
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            /* An observer that observes 'viewModel.jsPublisher' to get javascript value and
             pass that value to web app by calling JavaScript function */
            jsSubscriber = parent.viewModel.jsPublisher.receive(on: RunLoop.main).sink(receiveValue: {
                (authState, javascript) in
                webView.evaluateJavaScript(javascript) {
                    (response, error) in
                    self.parent.viewModel.jsResultPublisher.send((authState, (response, error)))
                    
                    //Log events for JS injection
                    var logEventAttributes:[String:String] = [:]
                    var status: String
                    if error == nil {
                        status = EventStatus.Success
                    } else {
                        status = EventStatus.Failure
                    }
                    switch authState {
                    case .email:
                        logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                              EventConstant.OrderSourceID: self.parent.viewModel.userAccount.userID,
                                              EventConstant.Status: status]
                        FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSInjectUserName, eventAttributes: logEventAttributes)
                    case .password:
                        logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                              EventConstant.OrderSourceID: self.parent.viewModel.userAccount.userID,
                                              EventConstant.Status: status]
                        FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSInjectPassword, eventAttributes: logEventAttributes)
                    case .captcha:
                        logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                              EventConstant.OrderSourceID: self.parent.viewModel.userAccount.userID,
                                              EventConstant.Status: status]
                        FirebaseAnalyticsUtil.logEvent(eventType: EventType.JSDetectedCaptcha, eventAttributes: logEventAttributes)
                    case .dateRange, .downloadReport, .generateReport, .identification, .error:break
                    }
                }
            })
            
            navigationHelper.navigateWith(url: webView.url)
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            // Shows loader
            parent.viewModel.showWebView.send(false)
            
            navigationSubscriber = self.parent.viewModel.navigationPublisher.receive(on: RunLoop.main).sink(receiveValue: {
                navigation in
                switch navigation {
                case .reload:
                    if let url = URL(string: self.parent.baseURL) {
                        webView.load(URLRequest(url: url))
                    }
                }
            })
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if (self.navigationHelper.shouldIntercept(navigationResponse: navigationResponse.response)) {
                webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                    self.navigationHelper.intercept(navigationResponse: navigationResponse.response, cookies: cookies)
                }
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
        
        // This function is essential for intercepting every navigation in the webview
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // This allows the navigation
            decisionHandler(.allow)
        }
    }
    
}



// MARK: - Extensions
extension WebView.Coordinator: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // Make sure that your passed delegate is called
        if message.name == "iOSNative" {
            
        }
    }
}
