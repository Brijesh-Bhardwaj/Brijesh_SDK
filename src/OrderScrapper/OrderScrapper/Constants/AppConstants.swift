//
//  AppConstants.swift
//  OrderScrapper


import Foundation

struct AppConstants {
    static let bundle: Bundle! = Bundle(identifier: "ai.blackstraw.orderscrapper")
    static let identifier: String  = "ai.blackstraw.orderscrapper"
    static let numberOfSteps: Float = 6
    static let entityName = "UserAccount"
    static let resource = "CoreDataModel"
    static let extensionName = "momd"
    //UserAccount Entity columns
    static let userAccountColumnOrderSource = "orderSource"
    static let userAccountColumnUserId = "userId"
    static let userAccountColumnAccountStatus = "accountStatus"
    static let userAccountColumnPassword = "password"
    static let userAcccountColumnPanelistId = "panelistId"
    //Firebase Analytics
    static let resourceName = "GoogleService-Info"
    static let resourceOfType = "plist"
    static let analyticsName = "OrderScrapper"
    static let firstDayOfJan = "1"
    static let monthJan = "1"
    static let amazonReportType = "ITEMS"
    //Update status API messages
    static let msgDisconnected = "Account Disconnected"
    static let msgConnected = "Account connected"
    static let msgCapchaEncountered = "Encountered captcha"
    static let msgAuthError = "Authentication failed"
    static let msgDBEmpty = "App install again or device change"
    static let msgCSVUploadFailed = "CSV upload failed"
    static let msgAccountConnected = "Account connected"
    static let msgPIIAPIFailed = "PII details api failed"
    static let msgDateRangeAPIFailed = "Date-range api failed"
    static let msgDownloadCSVFailed = "Exception while downloading csv file"
    static let msgCSVParsingFailed = "Exception while updating csv file"
    //Error messages
    static let msgResetPassword = "Something went wrong. Please check your credentials once in a browser and retry"
    static let msgUnknownURL = "We encountered an issue while connecting your account. Please try again later."
    static let tag = "OrderScrapper"
}
