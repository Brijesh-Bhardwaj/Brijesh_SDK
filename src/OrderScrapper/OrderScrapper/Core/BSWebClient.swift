//  BSWebClient.swift
//  OrderScrapper

import Foundation
import WebKit

class BSWebClient: WKWebView {
    var scriptMessageHandler: BSScriptMessageHandler?
    
    init(frame: CGRect, configuration: WKWebViewConfiguration, scriptMessageHandler: BSScriptMessageHandler) {
        super.init(frame: frame, configuration: configuration)
        
        self.scriptMessageHandler = scriptMessageHandler
        
        self.evaluateJavaScript("navigator.userAgent") { (agent, error) in
            var userAgent = "iPhone;"
            if let agent = agent as? String {
                userAgent = agent.replacingOccurrences(of: "iPad", with: "iPhone")
            } else {
                print(AppConstants.tag, "evaluateJavaScript", error.debugDescription)
            }
            self.customUserAgent = userAgent
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func loadUrl(url: String) {
        if let url = URL(string: url) {
            let urlRequest = URLRequest(url: url)
            self.load(urlRequest)
        }
    }
    
    func loadListingUrl(url: String) {
        let encodedStr = url.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!
        if let url = URL(string: encodedStr) {
            let urlRequest = URLRequest(url:url)
            self.load(urlRequest)
        }
    }
}
