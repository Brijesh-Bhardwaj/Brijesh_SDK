//
//  WebView.swift
//  OrderScrapper
//

import Foundation
import UIKit
import SwiftUI
import Combine
import WebKit

// MARK: - WebViewHandlerDelegate
// For printing values received from web app
protocol WebViewHandlerDelegate {
    func receivedJsonValueFromWebView(value: [String: Any?])
    func receivedStringValueFromWebView(value: String)
}

// MARK: - WebView
struct WebView: UIViewRepresentable, WebViewHandlerDelegate {
    func receivedJsonValueFromWebView(value: [String : Any?]) {
        print("JSON value received from web is: \(value)")
    }
    
    func receivedStringValueFromWebView(value: String) {
        print("String value received from web is: \(value)")
    }
    
    var url: WebUrlType
    
    // Viewmodel object
    @ObservedObject var viewModel: ViewModel
    
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
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        
        if let url = URL(string: "https://www.amazon.com/ap/signin?_encoding=UTF8&openid.assoc_handle=usflex&openid.claimed_id=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0%2Fidentifier_select&openid.identity=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0%2Fidentifier_select&openid.mode=checkid_setup&openid.ns=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0&openid.ns.pape=http%3A%2F%2Fspecs.openid.net%2Fextensions%2Fpape%2F1.0&openid.pape.max_auth_age=900&openid.return_to=https%3A%2F%2Fwww.amazon.com%2Fgp%2Fb2b%2Freports%2F136-9723095-1427523%3Fie%3DUTF8%26%252AVersion%252A%3D1%26%252Aentries%252A%3D0") {
            webView.load(URLRequest(url: url))
        }
    }
    
    class Coordinator : NSObject, WKNavigationDelegate {
        var parent: WebView
        var delegate: WebViewHandlerDelegate?
        var valueSubscriber: AnyCancellable? = nil
        var webViewNavigationSubscriber: AnyCancellable? = nil
        
        let authenticator: AmazonAuthenticator
        let navigationHelper: NavigationHelper = AmazonNavigationHelper()
        
        init(_ uiWebView: WebView) {
            self.parent = uiWebView
            self.delegate = parent
            self.authenticator = AmazonAuthenticator(self.parent.viewModel)
        }
        
        deinit {
            valueSubscriber?.cancel()
            webViewNavigationSubscriber?.cancel()
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            /* An observer that observes 'viewModel.jsPublisher' to get javascript value and
             pass that value to web app by calling JavaScript function */
            valueSubscriber = parent.viewModel.jsPublisher.receive(on: RunLoop.main).sink(receiveValue: {
                (authState, javascript) in
                webView.evaluateJavaScript(javascript) {
                    (response, error) in
                    self.parent.viewModel.jsResultPublisher.send((authState, (response, error)))
                }
            })
            
            var js = ""
            
            let navigationAction = navigationHelper.navigationActionForURL(url: webView.url)
            switch navigationAction {
            case .authenticate:
                self.authenticator.authenticate()
            case .approveAuth, .twoFactorAuth:
                self.parent.viewModel.showWebView.send(true)
            case .generateReport:
                js = self.injectGenerateReportJS()
            case .downloadReport:
                js = injectDownloadReportJS()
            case .none: return
            }
            
            if !js.isEmpty {
                webView.evaluateJavaScript(js) { (_, error) in
                    if let error = error {
                        print(error)
                    }
                }
            }
 
            // Page loaded so no need to show loader anymore
            self.parent.viewModel.showLoader.send(false)
        }
        
        func injectGenerateReportJS() -> String {
            let startDay = "1";
            let startMonth = "5";
            let startyear = "2008";
            let endDay = "17";
            let endMonth = "2";
            let endYear = "2021";
            let reportType = "SHIPMENTS";
            
            return "javascript:" +
                "document.getElementById('report-type').value = '" + reportType + "';" +
                "document.getElementById('report-month-start').value = '" + startMonth + "';" +
                "document.getElementById('report-day-start').value = '" + startDay + "';" +
                "document.getElementById('report-year-start').value = '" + startyear + "';" +
                "document.getElementById('report-month-end').value = '" + endMonth + "';" +
                "document.getElementById('report-day-end').value = '" + endDay + "';" +
                "document.getElementById('report-year-end').value = '" + endYear + "';" +
                "document.getElementById('report-confirm').click()"
        }
        
        func injectDownloadReportJS() -> String {
            return "javascript:" +
                "document.getElementById(window['download-cell-'+new URLSearchParams(window.location.search).get(\"reportId\")].id).click()"
        }
        
        /* Here I implemented most of the WKWebView's delegate functions so that you can know them and
         can use them in different necessary purposes */
        
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            // Hides loader
            parent.viewModel.showLoader.send(false)
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            // Hides loader
            parent.viewModel.showLoader.send(false)
        }
        
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            // Shows loader
            parent.viewModel.showLoader.send(true)
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            // Shows loader
            parent.viewModel.showLoader.send(true)
            self.webViewNavigationSubscriber = self.parent.viewModel.webViewNavigationPublisher.receive(on: RunLoop.main).sink(receiveValue: { navigation in
                switch navigation {
                case .backward:
                    if webView.canGoBack {
                        webView.goBack()
                    }
                case .forward:
                    if webView.canGoForward {
                        webView.goForward()
                    }
                case .reload:
                    webView.reload()
                }
            })
        }
        
        // This function is essential for intercepting every navigation in the webview
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Suppose you don't want your user to go a restricted site
            // Here you can get many information about new url from 'navigationAction.request.description'
            if let host = navigationAction.request.url?.host {
                if host == "restricted.com" {
                    // This cancels the navigation
                    decisionHandler(.cancel)
                    return
                }
            }
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
            if let body = message.body as? [String: Any?] {
                delegate?.receivedJsonValueFromWebView(value: body)
            } else if let body = message.body as? String {
                delegate?.receivedStringValueFromWebView(value: body)
            }
        }
    }
}
