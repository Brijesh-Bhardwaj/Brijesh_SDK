//  BSWebClient.swift
//  OrderScrapper

import Foundation
import WebKit

class BSWebClient: WKWebView {
    
    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
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
            self.load(URLRequest(url: url))
        }
    }
}
