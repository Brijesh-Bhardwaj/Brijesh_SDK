//
//  Utils.swift
//  OrderScrapper


import Foundation
import SwiftUI
import Sentry

class Utils {
    //Returns string value for the key
    static func getString(key : String) -> String {
        return NSLocalizedString(key, tableName: nil, bundle: AppConstants.bundle, value: "", comment: "")
    }
    
    //Returns color for the key
    static func getColor(key : String) -> Color {
        return Color(key, bundle: AppConstants.bundle)
    }
    
    static func getImage(named imageName: String) -> UIImage? {
        return UIImage(named: imageName, in: AppConstants.bundle, with: nil)
    }
    
    static func getBaseURL() -> String {
        let infoDict = AppConstants.bundle.infoDictionary!
        return infoDict["BASE_API_ENDPOINT"] as! String
    }
    
    static func getSubUrl(url: String, delimeter: String) -> String {
        let subUrl = url.components(separatedBy: delimeter)
        return subUrl[0]
    }
    
    static func getKeyForNumberOfCaptchaRetry(orderSorce: OrderSource) -> String {
        switch orderSorce {
        case .Amazon:
            return Strings.AmazonOnNumberOfCaptchaRetry
        case .Instacart:
            return Strings.InstacartOnNumberOfCaptchaRetry
        case .Kroger:
            return Strings.KrogerOnNumberOfCaptchaRetry
        case .Walmart:
            return Strings.WalmartOnNumberOfCaptchaRetry
        }
    }
    
    static func getKeyForCoolOfTime(orderSorce: OrderSource) -> String {
        switch orderSorce {
        case .Amazon:
            return Strings.AmazonOnBackgroundScrappingTimeOfPeriod
        case .Instacart:
            return Strings.InstacartOnBackgroundScrappingTimeOfPeriod
        case .Kroger:
            return Strings.KrogerOnBackgroundScrappingTimeOfPeriod
        case .Walmart:
            return Strings.WalmartOnBackgroundScrappingTimeOfPeriod
        }
    }
    
    static func getKeyForJSVersion(orderSorce: OrderSource) -> String {
        switch orderSorce {
        case .Amazon:
            return Strings.JSVersionAmazon
        case .Instacart:
            return Strings.JSVersionInstacart
        case .Kroger:
            return Strings.JSVersionKroger
        case .Walmart:
            return Strings.JSVersionWalmart
        }
    }
    
    static func getKeyForOrderState(orderSource: OrderSource) -> String {
        switch orderSource {
        case .Instacart:
            return Strings.OrderStateInstacart
        case .Walmart:
            return Strings.OrderStateWalmart
        case .Amazon:
            return ""
        case .Kroger:
            return ""
        }
    }
    
    static func getKeyForAuthJSVersion(orderSorce: OrderSource) -> String {
        switch orderSorce {
        case .Amazon:
            return Strings.JSAuthVersionAmazon
        case .Instacart:
            return Strings.JSAuthVersionInstacart
        case .Kroger:
            return Strings.JSAuthVersionKroger
        case .Walmart:
            return Strings.JSAuthVersionWalmart
        }
    }
    
    static func isPreviousWeeksOrders(sessionTimer: String?, completionHandler: @escaping(Bool) -> Void) {
        var localTimeZoneIdentifier: String { return TimeZone.current.identifier }
        _ = AmazonService.getIncentiveFlag(timeZone: localTimeZoneIdentifier, sessionTimerStarted: sessionTimer) { response, error in
            if response != nil {
                LibContext.shared.lastWeekOrders = response?.lastWeekOrderCount
                    completionHandler(true)
                } else {
                    let  lastWeekOrder = LastWeekOrderCount()
                    lastWeekOrder.walmart = 0
                    lastWeekOrder.instacart = 0
                    lastWeekOrder.amazon = 0
                    LibContext.shared.lastWeekOrders = lastWeekOrder
                completionHandler(false)
                let aslException = ASLException(error: nil, errorMessage: error!.errorMessage, failureType: nil)
                FirebaseAnalyticsUtil.logSentryError(error: aslException)
            }
        }
    }
    
    
    static func getJsonString(object: Any) -> String {
        //        let jsonEncoder = JSONEncoder()
        //        let jsonData = try jsonEncoder.encode(object)
        //        let json = String(data: jsonData, encoding: String.Encoding.utf16)
        return ""
    }
}
