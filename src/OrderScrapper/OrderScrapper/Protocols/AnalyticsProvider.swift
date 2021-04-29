import Foundation
//  AnalyticsProvider.swift
//  OrderScrapper
/*
 A callback protocol to notify the application to log the events
 generated from the SDK and values of the user properties. The
 application must implement this protocol if the app already has
 firebase or any other analytics implemented.
 **/
public protocol AnalyticsProvider {
    
    ///Notifies the app to log the events generated from the SDK
    /// - Parameter evenType: the type of event
    /// - Parameter eventAttributes: attributes of the event
    func logEvent(eventType: String, eventAttributes: Dictionary<String, String>)
           
    /**
     * Notifies the app to log the values of the user properties
     * - Parameter userProperty: property of the user
     * - Parameter userPropertyValue  value of the user property
     */
    func setUserProperty(userProperty: String, userPropertyValue: String)
}
