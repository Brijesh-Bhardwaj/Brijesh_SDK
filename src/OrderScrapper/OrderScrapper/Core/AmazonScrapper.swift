//  AmazonScrapper.swift
//  OrderScrapper

import Foundation

class AmazonScrapper: BSScrapper {
   
    override func getAuthenticator() throws -> BSAuthenticator {
        if mAuthenticator == nil {
            mAuthenticator = BSAmazonAuthenticator(webClient: mWebClient, listener: self)
        }
        return mAuthenticator!
    }
 
    override func getOrderSource() throws -> OrderSource {
        return .Amazon
    }
    
    override func onAuthenticationSuccess() {
        print("### onAuthenticationSuccess")
        
        var logEventAttributes:[String:String] = [:]
        logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                              EventConstant.Status: EventStatus.Success]
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgAuthentication, eventAttributes: logEventAttributes)
        
        var logEventorderListingAttributes:[String:String] = [:]
        logEventorderListingAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                              EventConstant.Status: EventStatus.Success]
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgNavigatedToOrderListing, eventAttributes: logEventorderListingAttributes)
    }
    
    override func onAuthenticationFailure(errorReason: ASLException) {
        print("### onAuthenticationFailure", errorReason.errorMessage)
        
        var logEventAttributes:[String:String] = [:]
        logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                              EventConstant.Status: errorReason.errorMessage,
                              EventConstant.Status: EventStatus.Failure]
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgAuthentication, eventAttributes: logEventAttributes)
        
        var logEventOrderListingAttributes:[String:String] = [:]
        logEventOrderListingAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                          EventConstant.ErrorReason: Strings.ErrorOrderListingNavigationFailed,
                              EventConstant.Status: EventStatus.Failure]
        FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgNavigatedToOrderListing, eventAttributes: logEventOrderListingAttributes)
    }
}
