//
//  AppConstants.swift
//  OrderScrapper


import Foundation

struct AppConstants {
    static let bundle: Bundle! = Bundle(identifier: "ai.blackstraw.orderscrapper")
    static let identifier: String  = "ai.blackstraw.orderscrapper"
    static let numberOfSteps: Float = 6
    static let timeoutCounter: Double = 15
    static let entityName = "UserAccount"
    static let orderDetailEntity = "OrderDetails"
    static let resource = "CoreDataModel"
    static let extensionName = "momd"
    static let iOS = "iOS"
    //UserAccount Entity columns
    static let userAccountColumnOrderSource = "orderSource"
    static let userAccountColumnUserId = "userId"
    static let userAccountColumnAccountStatus = "accountStatus"
    static let userAccountColumnPassword = "password"
    static let userAcccountColumnPanelistId = "panelistId"
    //OrderDetails Entity columns
    static let orderDetailsColumnOrderID = "orderID"
    static let orderDetailsColumnOrderDate = "orderDate"
    static let orderDetailsColumnOrderSource = "orderSource"
    static let orderDetailsColumnOrderUserID = "userID"
    static let orderDetailsColumnPanelistID = "panelistID"
    static let orderDetailsColumnOrderDeatilsURL = "orderDeatilsURL"
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
    static let msgTimeout = "Something went wrong. Try again after sometime."
    static let fetchAccounts = "Failed to fetch Account."
    static let fetchOrderDetails = "Failed to fetch orderDetails"
    static let userAccountConnected = "This account is already associated with an existing user. Please try with another account."
    static let bgScrappingCompleted = "Background scrapping completed"
    //Sentry Variables
    static let dsnURL = "https://6ad6390802f44f3fa71739de94424310@o915046.ingest.sentry.io/5854887"
    static let tracesSampleRate: NSNumber = 1.0
    static let bsOrderFailed = NSExceptionName("BS Other URL loaded")
    
    static let generateReportUrl = "https://www.amazon.com/gp/b2b/reports/"
    static let msgUploadCSVSuccess = "CSV uploaded successfully"
    static let msgOrderListSuccess = "List scrapping success"
    static let ErrorInJsonEncoding = "Error in JSON encoding"
    static let AmazonErrorMessage = "Enter your email or mobile phone number"

}
