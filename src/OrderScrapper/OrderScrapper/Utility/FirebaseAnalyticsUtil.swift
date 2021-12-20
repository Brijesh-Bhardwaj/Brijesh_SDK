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
        event.platform = "iOS"
        
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

    static func logSentryError(error: Error) {
        SentrySDK.capture(error: error)
    }
    
    static func logSentryError(eventAttributes: Dictionary<String, String>, error: Error) {
        //eventAttributes[EventConstant.Platform] = AppConstants.iOS
        SentrySDK.configureScope { scope in
            scope.setContext(value: eventAttributes, key: "data")
            FirebaseAnalyticsUtil.logSentryError(error: error)
        }
    }
    
    static func logSentryException(exception: NSException) {
        SentrySDK.capture(exception: exception)
    }
    
    static func logSentryException(eventAttributes: Dictionary<String, String>, exception: NSException) {
        SentrySDK.configureScope{scope in
            scope.setContext(value: eventAttributes, key: "data")
            logSentryException(exception: exception)
        }
    }
    
    static func logSentryMessage(message: String) {
        let panelistId = LibContext.shared.authProvider.getPanelistID()
        var logEventAttributes:[String:String] = [:]
        logEventAttributes = [EventConstant.PanelistID: panelistId,
                              EventConstant.Status: EventStatus.Success]
        //SentrySDK.capture(message: message)
        self.logEvent(eventType: message, eventAttributes: logEventAttributes)
    }
 
    static func initSentrySDK(scrapeConfigs: ScrapeConfigs) {
        let sentryConfigs = scrapeConfigs.sentry
        if sentryConfigs != nil {
            if sentryConfigs.enabled {
                SentrySDK.start { options in
                    options.dsn = sentryConfigs.iosDSN
                    options.debug = true // Enabled debug when first installing is always helpful
                    options.attachStacktrace = true
                    options.tracesSampleRate = AppConstants.tracesSampleRate
                    options.enableAutoSessionTracking = true
                    options.dist = "OrderScrapperLogs"
                }
            }
        }
    }
}
