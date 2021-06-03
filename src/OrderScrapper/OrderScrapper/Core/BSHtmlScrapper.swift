//  BSHtmlScrapper.swift
//  OrderScrapper

import Foundation
import WebKit

class BSHtmlScrapper {
    private let webClient: BSWebClient
    private let webNavigationDelegate: BSWebNavigationDelegate
    private let listener: BSHtmlScrappingStatusListener
    private var script: String?
    
    init(webClient: BSWebClient, delegate: BSWebNavigationDelegate, listener: BSHtmlScrappingStatusListener) {
        self.webClient = webClient
        self.webNavigationDelegate = delegate
        self.listener = listener
    }
    
    func extractOrders(script: String, url: String) {
        self.script = script
        self.webNavigationDelegate.setObserver(observer: self)
        self.webClient.scriptMessageHandler?.addScriptMessageListener(listener: self)
        self.webClient.loadListingUrl(url: url)
    }
}

extension BSHtmlScrapper: ScriptMessageListener {
    func onScriptMessageReceive(message: WKScriptMessage) {
        print("### onScriptMessageReceive")
        if message.name == "iOS" {
            print("### JSCallback Result \(message.body)")
            listener.onHtmlScrappingSucess(response: message.body as! String)
        }
    }
}

extension BSHtmlScrapper: BSWebNavigationObserver {
    func didFinishPageNavigation(url: URL?) {
        if let _ = url, let script = script {
            webClient.evaluateJavaScript(script) { response, error in
                print("#### evaluateJavaScript")
            }
        } else {
            listener.onHtmlScrappingFailure(error: ASLException(errorMessage: Strings.ErrorPageNotloaded, errorType: nil))
        }
    }
    
    func didStartPageNavigation(url: URL?) {
        if url == nil {
            listener.onHtmlScrappingFailure(error: ASLException(errorMessage: Strings.ErrorPageNotloaded, errorType: nil))
        }
    }
    
    func didFailPageNavigation(for url: URL?, withError error: Error) {
        listener.onHtmlScrappingFailure(error: ASLException(errorMessage: Strings.ErrorOrderExtractionFailed, errorType: nil))
    }

}
