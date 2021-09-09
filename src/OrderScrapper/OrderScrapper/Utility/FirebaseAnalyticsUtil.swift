//
//  FirebaseAnalyticsUtil.swift
//  OrderScrapper

import Foundation
//import FirebaseAnalytics
//import Firebase
//import FirebaseCore
import Sentry


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
        let event = Event()
        event.extra = eventAttributes
        event.message = SentryMessage(formatted: eventType)
        
        let keyExists = eventAttributes[EventConstant.Status] != nil
        if keyExists {
            let status = eventAttributes[EventConstant.Status]
            if status == EventStatus.Failure {
                event.level = SentryLevel.error
            }
            else {
                event.level = SentryLevel.info
            }
        }
        
        SentrySDK.capture(event: event)
    }
    
    static func logUserProperty(orderSourceId: String, orderSource: OrderSource) {
        let analyticsProvider = AmazonOrderScrapper.shared.analyticsProvider
        if let analyticsProvider = analyticsProvider {
            analyticsProvider.setUserProperty(userProperty: EventConstant.PanelistID, userPropertyValue: LibContext.shared.authProvider.getPanelistID())
            analyticsProvider.setUserProperty(userProperty: EventConstant.OrderSourceID, userPropertyValue: orderSourceId)
            analyticsProvider.setUserProperty(userProperty: EventConstant.AppID, userPropertyValue: AppConstants.identifier)
            analyticsProvider.setUserProperty(userProperty: EventConstant.OrderSource, userPropertyValue: orderSource.value)
        }
        let eventUser = User()
        eventUser.userId = LibContext.shared.authProvider.getPanelistID()
        eventUser.email = orderSourceId
        SentrySDK.setUser(eventUser)
    }
}
