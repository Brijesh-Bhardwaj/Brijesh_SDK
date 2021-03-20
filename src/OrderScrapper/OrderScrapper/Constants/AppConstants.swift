//
//  AppConstants.swift
//  OrderScrapper


import Foundation

struct AppConstants {
    static let bundle: Bundle! = Bundle(identifier: "ai.blackstraw.orderscrapper.OrderScrapper")
    static let identifier: String  = "ai.blackstraw.orderscrapper.OrderScrapper"
    static let numberOfSteps: Float = 6
    static let entityName = "UserAccount"
    static let resource = "CoreDataModel"
    static let extensionName = "momd"
    //UserAccount Entity columns
    static let userAccountColumnOrderSource = "orderSource"
    static let userAccountColumnUserId = "userId"
    static let userAccountColumnAccountStatus = "accountStatus"
    static let userAccountColumnPassword = "password"
}
