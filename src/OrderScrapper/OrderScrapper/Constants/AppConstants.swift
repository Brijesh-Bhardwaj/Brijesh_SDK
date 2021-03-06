//
//  AppConstants.swift
//  OrderScrapper


import Foundation

struct AppConstants {
    static let bundle: Bundle! = Bundle(identifier: "ai.blackstraw.orderscrapper")
    static let identifier: String  = "ai.blackstraw.orderscrapper"
    static let numberOfSteps: Float = 6
    static let steps: Float = 3
    static let progressValue: Float = 100
    static let timeoutCounter: Double = 15
    static let timeoutManualScrape: Double = 1800
    static let timeoutManualScrapeCSV: Double = 150
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
    static let orderDetailsColumnOrderSectionType = "orderSectionType"
    static let orderDetailsColumnsUplaodRetryCount = "uploadRetryCount"
    static let orderDetailsColumnFromDate = "startDate"
    static let orderDetailsColumnToDate = "endDate"
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
    static let ScrappingCompleted = "Scrapping completed"
    static let updateRetryCount = "Failed to update retry count for orderDetails"
    static let updateAccount = "Failed to update Account"
    //Sentry Variables
    static let dsnURL = "https://6ad6390802f44f3fa71739de94424310@o915046.ingest.sentry.io/5854887"
    static let tracesSampleRate: NSNumber = 1.0
    static let bsOrderFailed = NSExceptionName("BS Other URL loaded")
    static let generateReportUrl = "https://www.amazon.com/gp/b2b/reports/"
    static let msgUploadCSVSuccess = "CSV uploaded successfully"
    static let ICLoginSuccessURL = "https://www.instacart.com/store"
    static let InstacartOnBoardingURL = "https://www.instacart.com/onboarding"
    static let KRLoginSuccessURL = "https://www.kroger.com/"
    static let amazonAccountConnectedSuccess = "Amazon Account Connected Successfully"
    static let instacartAccountConnectedSuccess = "Instacart Account Connected Successfully"
    static let walmartAccountConnectedSuccess = "Walmart Account Connected Successfully"
    static let msgOrderListSuccess = "List scrapping success"
    static let errorEmailWrongKroger = "Please enter a valid email address"
    static let errorWrongCredentialsKroger = "The email or password entered is incorrect. Please try again or select Forgot Password."
    static let errorWrongEmailkroger = "There's a problem with the entered email address. Please check the spelling and try again."
    static let krogerRetryCount: Int = 3
    static let deviceId = "\(LibContext.shared.orderExtractorConfig.deviceId)"
    static let devicePlatform = "ios"
    static let orderUploadRetryCount = 2
    static let captchaRetryCount = 3
    static let ErrorInJsonEncoding = "Error in JSON encoding"
    static let AmazonErrorMessage = "Enter your email or mobile phone number"
    static let ErrorBgScrappingCoolOff = "bg process in cool off period"
    static let WrongLoginURL = "Wrong URL for login"
    static let Completed = "Completed"
    static let authScriptFileNotFound = "auth file not found"
    static let ScriptParseError = "Script parsing error"
    static let authScriptNotFound = "Error while executing request please try again later"
    static let uploadBatchSize = 5
    // NOTE: - Do not change this keys unless it is changed from backend Authentication script key constants
    static let getEmailAmazon = "validateEmailId"
    static let getPasswordAmazon = "signInWithPassword"
    static let captchaAmazon = "checkIfCaptchaScreen"
    static let getGenerateReportScript = "getGenerateReportScript"
    static let getDownloadReport = "getDownloadReportScript"
    static let getOldestPossibleYear = "getOldestPossibleYear"
    static let checkIfSignInErrorAmazon = "checkIfSignInError"
    static let getSignInPromptTypeAmazon = "getSignInPromptType"
    static let isReportReady = "isReportReady"
    // Walmart script keys
    static let getWalmartVerifyIdentityJS = "getWalmartVerifyIdentityJS"
    static let getWalmartCheckErrorJS = "getWalmartCheckErrorJS"
    static let getWalmartIdentificationJS = "getWalmartIdentificationJS"
    static let getWalmartSignInRequiredJS = "getWalmartSignInRequiredJS"
    //Instacart script keys
    static let getInstacartIdentification = "getInstacartIdentification"
    static let getInstcartinjectLoginJS = "getInstacartInjectLoginJS"
    static let getInstacartErrorPasswordInjectJS = "getInstacartErrorPasswordInjectJS"
    static let getInstacartWrongPasswordInjectJS = "getInstacartWrongPasswordInjectJS"
    static let getInstacartErrorEmailInjectJS = "getInstacartErrorEmailInjectJS"
    static let getInstacartFlashMessage = "getInstacartFlashMessage"
    static let getInstacartOnClick = "getInstacartOnClick"
    static let getInstacartProcide = "getInstacartProcide"
    static let getInstacartVerificationCodeJS = "getInstacartVerificationCodeJS"
    static let getInstcartCaptchaClosed = "getInstacartCaptchaClosed"
    static let getInstacartverificationCodeSuccess = "getInstacartVerificationCodeSuccess"
    static let scrappingTransition = "Background to "
    static let generalScrappingInitiated = "Background scraping has been initiated"
    static let doItLaterMessage = "User clicked the do it later"
    static let stopMessage = "User clicked the stop"
    static let retryMessage = "User clicked the retry"
    static let continueMessage = "User clicked the continue"
    static let transitionForConfiguredDay = " scrapping started for configured day"
    static let transitionForNonConfiguredDay = " scrapping started for non configured day"
    static let currentURLOnScrapping = "Current web page while scrapping"
    static let currentURLLoading = "Current url on connection"
    static let authFail = "Error occured while Authentication proccess"
    static let user_account_not_exist = "user account doesn't exists in the SDK"
    static let Failure_in_db_insertion = "Failed while inserting account to SDK db"


}
