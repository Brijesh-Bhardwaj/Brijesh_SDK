//
//  FirebaseAnalyticsUtil.swift
//  OrderScrapper

import Foundation
//import FirebaseAnalytics
//import Firebase
//import FirebaseCore


class FirebaseAnalyticsUtil {
    
    static func configure() {
//        let filePath = Bundle(identifier: AppConstants.identifier)!.path(forResource: AppConstants.resourceName, ofType: AppConstants.resourceOfType)
//        let options = FirebaseOptions.init(contentsOfFile: filePath!)!
//        FirebaseApp.configure(options: options)
    }
    
    static func logEvent(eventType: String, eventAttributes: Dictionary<String, String>) {
        var commonEventAttributes = [EventConstant.PanelistID: LibContext.shared.authProvider.getPanelistID(),
                                     EventConstant.AppID: AppConstants.identifier]
        commonEventAttributes.merge(dict: eventAttributes)
        let analyticsProvider = AmazonOrderScrapper.shared.analyticsProvider
        if let analyticsProvider = analyticsProvider {
            analyticsProvider.logEvent(eventType: eventType, eventAttributes: eventAttributes)
        } else {
//            Analytics.logEvent(eventType, parameters: commonEventAttributes)
        }
    }
    
}
