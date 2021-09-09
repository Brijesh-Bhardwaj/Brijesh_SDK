//
//  Strings.swift
//  OrderScrapper

import Foundation

struct Strings {
    static let HeadingConnectAmazonAccount = "heading_connect_amazon_account"
    static let HeadingPleaseSignInWithCredentials = "heading_please_sign_in_with_credentials"
    static let ErrorEnterValidUsernamePassword = "error_enter_valid_username_password"
    static let LabelEmailOrMobileNumber = "label_email_or_mobile_number"
    static let LabelPassword = "label_password"
    static let BtnSubmit = "btn_submit"
    static let NoConnection = "no_connection"
    static let NoConnection_msg = "no_connection_msg"
    static let BtnTryAgain = "btn_try_again"
    static let ErrorEncounteredUnexpectedError = "error_encountered_unexpected_error"
    static let HeadingConnectingAmazonAccount = "heading_connecting_amazon_account"
    static let SubheadingStayOnThisScreenUntilCompletion = "subheading_stay_on_this_screen_until_completion"
    static let HeadingFetchingYourReceipts = "heading_fetching_your_receipts"
    static let MsgReportDownloadedSuccessfully = "msg_report_downloaded_successfully"
    static let BtnOk = "btn_ok"
    static let ValidationPleaseEnterValidEmail = "validation_please_enter_valid_email"
    static let ValidationPleaseEnterValidPassword = "validation_please_enter_valid_password"
    static let Step1 = "step1"
    static let Step2 = "step2"
    static let Step3 = "step3"
    static let Step4 = "step4"
    static let Step5 = "step5"
    static let Step6 = "step6"
    static let SuccessMsgReceiptsFechedSuccessfully = "success_msg_receipts_fetched_successfully"
    static let HeadingFetchingReceipts = "heading_fetching_receipts"
    static let AlertBoldMessage = "dont_be_alarmed"
    static let AlertUserMessage = "user_alert_message"
    
    // Mark:- Non-Localized strings
    static let ScrappingPageListing = "Scraping time for listing"
    static let ScrappingPageDetails = "Scraping time for details"
    static let ErrorLibAlreadyInitialized = "OrdersExtractor is already initialized."
    static let ErrorLibNotInitialized = "OrdersExtractor is not initialized."
    static let ErrorAuthProviderNotImplemented = "authToken or panelistId is missing in AuthProvider."
    static let ExtractionDisabled = "Receipts scrapped already."
    static let ErrorUserAbortedProcess = "User aborted the process."
    
    static let ErrorChildClassShouldImplementMethod = "Child class should implement this method"
    static let ErrorOtherUrlLoaded = "Other url loaded"
    static let ErrorOccuredWhileInjectingJS = "Error occured"
    static let ErrorCaptchaPageLoaded = "Captcha page loaded"
    static let ErrorUserIdIsNil = "userId is nil"
    static let ErrorPasswordIsNil = "password is nil"
    static let ErrorEmailJSInjectionFailed = "email JS injection failed"
    static let ErrorPasswordJSInjectionFailed = "password JS injection failed"
    static let ErrorDuringNavigation = "An error occurred during navigation"
    static let ErrorDuringEarlyNavigation = "An error occurred during the early navigation process"
    static let ErrorWebContentProcessDidTerminate = "webViewWebContentProcessDidTerminate()"
    static let ErrorNoConfigurationsFound = "Configurations not found for the given order source"
    static let ErrorInScrapperConfigAPI = "scrapper_config_api_failed"
    static let ErrorOrderListingNavigationFailed = "order_listing_navigation_failed"
    static let ErrorOrderExtractionFailed = "Order extraction failed"
    static let ErrorConfigsMissing = "Configs missing"
    static let UIFontBold = "HelveticaNeue-Bold"
    static let UIFontLight = "HelveticaNeue-Light"
    static let ErrorPageNotloaded = "Error while loading web page"
    static let ErrorFetchSkipped = "Fetch skipped"
    static let ErrorScriptNotFound = "Could not read the script from the file"
    static let ErrorScriptFileNotFound = "Script file not found"
    static let ErrorOnAuthenticationChallenge = "Authentication challenge received"
    static let OnBackgroundScrappingTimeOfPeriod = "Cool oof Time period"
    static let OnNumberOfCaptchaRetry = "Captcha retry count"
    static let BGScrappingCoolOffTime = 300.0
    
    //Sentry error message
    static let ErrorAPIReponseDateRange = "Error while getting date range"
    static let ErrorAPIReposneUplodFile = "Error while uploading file"
    static let ErrorAPIReposnePIIList = "Error while getting PIIList"
    static let ErrorAPIReposneGetAccount = "Error while fetching accounts"
    static let ErrorAPIReposneRegisterConnection = "Error while registering connection"
    static let ErrorAPIResponseUpdateStatus = "Error while updating account status "
}
