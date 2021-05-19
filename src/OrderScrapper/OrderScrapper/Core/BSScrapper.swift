//  BSScrapper.swift
//  OrderScrapper

import Foundation
import WebKit

class BSScrapper: BSAuthenticationStatusListener {
    var windowManager: BSHeadlessWindowManager = BSHeadlessWindowManager()
    var mWebClient: BSWebClient
    var mAuthenticator: BSAuthenticator?
    private var baseUrl = "https://www.amazon.com/ap/signin/?_encoding=UTF8&openid.assoc_handle=usflex&openid.claimed_id=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0%2Fidentifier_select&openid.identity=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0%2Fidentifier_select&openid.mode=checkid_setup&openid.ns=http%3A%2F%2Fspecs.openid.net%2Fauth%2F2.0&openid.ns.pape=http%3A%2F%2Fspecs.openid.net%2Fextensions%2Fpape%2F1.0&openid.return_to=https%3A%2F%2Fwww.amazon.com%2Fgp%2Fyour-account%2Forder-history%2F"
    
    init(webClient: BSWebClient) {
        self.mWebClient = webClient
    }
    
    func startScrapping(account: Account) {
        windowManager.attachHeadlessView(view: mWebClient)
        do {
            try getAuthenticator().authenticate(url: baseUrl, account: account, listener: self)
        } catch {
        }
    }
    
    func stopScrapping() {
        windowManager.detachHeadlessView(view: mWebClient)
    }
    
    func isScrapping() {
    }
    
    func getAuthenticator() throws -> BSAuthenticator {
        throw ASLException(errorMessage: Strings.ErrorChildClassShouldImplementMethod, errorType: nil)
    }
    
    func onAuthenticationSuccess() {
        print("### onAuthenticationSuccess")
        
    }
    
    func onAuthenticationFailure(errorReason: ASLException) {
        print("### onAuthenticationFailure", errorReason.errorMessage)
        
    }
}
