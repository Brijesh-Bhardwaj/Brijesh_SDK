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
    static let ICAlertUserMessage = "If you don\'t use an email ID/password combination to log into your Instacart account, you will need to visit instacart.com and set one up in order to connect your Instacart account to CoinOut. "
    static let KRAlertUserMessage = "If you have not associated email-id or set password for your kroger account, kindly visit the kroger accounts page and set/reset it"
    static let KRLoginHyperLinkLable = "Which Kroger subsidiary accounts can I link to my CoinOut account?"
    static let HeadingConnectInstacartAccount = "heading_connect_instacart_account"
    static let HeadingPleaseSignInWithInstacartCredentials = "heading_please_sign_in_with_instacart_credentials"
    static let HeadingConnectingInstacartAccount = "heading_connecting_instacart_account"
    static let LabelInstacartEmailId = "label_instacart_email"
    static let ValidationInstacartPleaseEnterValidEmail = "validation_instacart_please_enter_valid_email"
    
    static let HeadingConnectKrogerAccount = "heading_connect_kroger_account"
    static let HeadingPleaseSignInWithKrogerCredentials = "heading_please_sign_in_with_kroger_credentials"
    static let HeadingConnectingKrogerAccount = "heading_connecting_kroger_account"
    static let LabelKrogerEmailId = "label_kroger_email"
    static let ValidationKrogerPleaseEnterValidEmail = "validation_kroger_please_enter_valid_email"
    static let KrogerAccountConnectedSuccessMsg = "kroger_account_connected_success_msg"
    
    static let HeadingConnectWalmartAccount = "heading_connect_walmart_account"
    static let HeadingPleaseSignInWithWalmartCredentials = "heading_please_sign_in_with_walmart_credentials"
    static let HeadingConnectingWalmartAccount = "heading_connecting_walmart_account"
    static let LabelWalmartEmailId = "label_walmart_email"
    static let ValidationWalmartPleaseEnterValidEmail = "validation_walmart_please_enter_valid_email"
    static let WalmartAccountConnectedSuccessMsg = "walmart_account_connected_success_msg"
    
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
    static let ErrorLabelStringNotPassed = "Label string not passed"
    static let ErrorViewControllerNotPassed = "View controller not passed"
    static let ErrorScriptNotFound = "Could not read the script from the file"
    static let ErrorScriptFileNotFound = "Script file not found"
    static let ErrorOnAuthenticationChallenge = "Authentication challenge received"
    static let AmazonOnBackgroundScrappingTimeOfPeriod = "Amazon cool of time period"
    static let AmazonOnNumberOfCaptchaRetry = "Amazon captcha retry count"
    static let InstacartOnBackgroundScrappingTimeOfPeriod = "Instacart cool of time period"
    static let InstacartOnNumberOfCaptchaRetry = "Instacart captcha retry count"
    static let KrogerOnBackgroundScrappingTimeOfPeriod = "Kroger cool of time period"
    static let KrogerOnNumberOfCaptchaRetry = "Kroger captcha retry count"
    static let WalmartOnNumberOfCaptchaRetry = "Walmart captcha retry count"
    static let WalmartOnBackgroundScrappingTimeOfPeriod = "Walmart cool of time period"
    static let BGScrappingCoolOffTime = 300.0
    static let ErrorICEnterValidEmailPassword = "Invalid email or password."
    static let authenticationFailed = "Authorization failed.Please try again"
    static let ErrorOnSubsidiaryListAPI = "<html><body><h1>Error occurred while loading the content.Please try again</h1></body></html>"
    static let JSVersionAmazon = "js_version_amazon"
    static let JSVersionInstacart = "js_version_instacart"
    static let JSVersionKroger = "js_version_kroger"
    static let JSVersionWalmart = "js_version_walmart"
    static let ErrorOnWebViewLoading = "An unexpected error occurred.Please try again"
    static let ErrorInFlashMessage = "error in authentication"
    static let InstacartURL = "http://www.instacart.com"
    static let ErrorInInjectingScript = "An error in injecting script"
    static let ErrorServicesDown = "Service Not Available"
    static let OnAuthenticationChallenegeRetryCount = "Amazon error retry count"

    //Sentry error message
    static let ErrorAPIReponseDateRange = "Error while getting date range"
    static let ErrorAPIReposneUplodFile = "Error while uploading file"
    static let ErrorAPIReposnePIIList = "Error while getting PIIList"
    static let ErrorAPIReposneGetAccount = "Error while fetching accounts"
    static let ErrorAPIReposneRegisterConnection = "Error while registering connection"
    static let ErrorAPIResponseUpdateStatus = "Error while updating account status "
    static let ErrorJSICAuthenticationResposne = "Error password"
    
    //Manual scraping messages
    static let HeaderFetchOrders = "Fetch %@ Orders"
    static let HeaderFetchingOrders = "Fetching %@ Orders"
    static let FetchSuccessMessage = "%@ orders fetched successfully"
    static let FetchFailureMessage = "%@ orders fetch failed"
}
