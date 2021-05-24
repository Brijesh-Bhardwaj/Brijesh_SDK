//  BSScrapper.swift
//  OrderScrapper

import Foundation
import WebKit

class BSScrapper: BSAuthenticationStatusListener {
    var windowManager: BSHeadlessWindowManager = BSHeadlessWindowManager()
    var mWebClient: BSWebClient
    var mAuthenticator: BSAuthenticator?
    
    init(webClient: BSWebClient) {
        self.mWebClient = webClient
    }
    
    func startScrapping(account: Account) {
        windowManager.attachHeadlessView(view: mWebClient)
        do {
            var orderSource: OrderSource
            try orderSource = getOrderSource()
            ConfigManager.shared.getConfigurations(orderSource: orderSource)  { configurations, error in
                if let configurations = configurations {
                    do {
                        try self.getAuthenticator().authenticate(account: account, configurations: configurations)
                    } catch {
                        self.onAuthenticationFailure(errorReason: ASLException(
                                                        errorMessage: Strings.ErrorChildClassShouldImplementMethod, errorType: nil))
                    }
                } else {
                    self.onAuthenticationFailure(errorReason: ASLException(
                                                    errorMessage: Strings.ErrorNoConfigurationsFound, errorType: nil))
                }
            }
        } catch {
            self.onAuthenticationFailure(errorReason: ASLException(
                                            errorMessage: Strings.ErrorChildClassShouldImplementMethod, errorType: nil))
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
    
    func getOrderSource() throws -> OrderSource {
        throw ASLException(errorMessage: Strings.ErrorChildClassShouldImplementMethod, errorType: nil)
    }
    
    func onAuthenticationSuccess() {
        print("### onAuthenticationSuccess")
        do {
            var orderSource: OrderSource
            try orderSource = getOrderSource()
            var logEventAttributes:[String:String] = [:]
            logEventAttributes = [EventConstant.OrderSource: String(orderSource.rawValue),
                                  EventConstant.Status: EventStatus.Success]
            FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgAuthentication, eventAttributes: logEventAttributes)
            
            var logEventorderListingAttributes:[String:String] = [:]
            logEventorderListingAttributes = [EventConstant.OrderSource: String(orderSource.rawValue),
                                              EventConstant.Status: EventStatus.Success]
            FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgNavigatedToOrderListing, eventAttributes: logEventorderListingAttributes)
            
            //Load Order Listing page
            ConfigManager.shared.getConfigurations(orderSource: orderSource)  { configurations, error in
                if let configurations = configurations {
                    let orderListingUrl = configurations.listing
                    self.mWebClient.loadUrl(url: orderListingUrl)
                }
            }
        } catch {
            self.onAuthenticationFailure(errorReason: ASLException(
                                            errorMessage: Strings.ErrorChildClassShouldImplementMethod, errorType: nil))
        }
    }
    
    func onAuthenticationFailure(errorReason: ASLException) {
        print("### onAuthenticationFailure", errorReason.errorMessage)
        do {
            var orderSource: OrderSource
            try orderSource = getOrderSource()
        var logEventAttributes:[String:String] = [:]
        logEventAttributes = [EventConstant.OrderSource: String(orderSource.rawValue),
                              EventConstant.ErrorReason: errorReason.errorMessage,
                              EventConstant.Status: EventStatus.Failure]
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgAuthentication, eventAttributes: logEventAttributes)
        
        var logEventOrderListingAttributes:[String:String] = [:]
        logEventOrderListingAttributes = [EventConstant.OrderSource: String(orderSource.rawValue),
                                          EventConstant.ErrorReason: Strings.ErrorOrderListingNavigationFailed,
                                          EventConstant.Status: EventStatus.Failure]
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgNavigatedToOrderListing, eventAttributes: logEventOrderListingAttributes)
        } catch {
            self.onAuthenticationFailure(errorReason: ASLException(
                                            errorMessage: Strings.ErrorChildClassShouldImplementMethod, errorType: nil))
        }
    }
}
