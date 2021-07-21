//
//  Utils.swift
//  OrderScrapper


import Foundation
import SwiftUI

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
}
