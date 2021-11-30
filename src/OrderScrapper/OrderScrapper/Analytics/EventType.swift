//
//  EventType.swift
//  OrderScrapper


import Foundation

struct EventType {
    static let AccountConnect = "account_connect"
    static let JSInjectUserName = "js_inject_user_name"
    static let JSInjectPassword = "js_inject_password"
    static let JSDetectedCaptcha = "js_detected_captcha"
    static let JSDetectedDeviceAuth = "js_detected_device_auth"
    static let JSDetectedAuthApproval = "js_detected_auth_approval"
    static let JSDetectedTwoFactorAuth = "js_detected_two_factor_auth"
    static let JSDetected = "js_detected"
    static let APIDateRange = "api_date_range"
    static let APIPIIList = "api_deactive_pii_list"
    static let APIUploadReport = "api_upload_order_history"
    static let OrderCSVPParse = "order_csv_parse"
    static let OrderCSVDownload = "order_csv_download"
    static let JSDetectOtherURL = "js_detect_other_url"
    static let JSDetectReportGeneration = "js_detected_report_generation"
    static let JSDetectReportDownload = "js_detected_report_download"
    
    //Event types in background
    static let BgAccountConnect = "bg_account_connect"
    static let BgJSInjectUserName = "bg_js_inject_user_name"
    static let BgJSInjectPassword = "bg_js_inject_password"
    static let BgJSDetectedCaptcha = "bg_js_detected_captcha"
    static let BgJSDetectOtherURL = "bg_js_detect_other_url"
    static let BgScrappingStarted = "bg_scrapping_started"
    
    static let BgAPIScrapperConfig = "bg_api_scraper_config"
    static let BgAuthentication = "bg_authentication"
    static let BgNavigatedToOrderListing = "bg_navigated_to_order_listing"
    static let BgDownloadScrapperScriptFile = "bg_download_scrapper_script_file"
    static let BgRetrieveScrapperScript = "bg_retrieve_scrapper_script"
    
    static let BgInjectJSForOrderDetail = "bg_inject_js_against_order_details_page"
    static let BgScrappingOrderDetailResultSuccess = "bg_scrapping_order_details_result_success"
    static let BgScrappingOrderDetailResultFilure = "bg_scrapping_order_details_result_failure"
    static let BgInsertScrappedOrderDetailsInDB = "bg_insert_scrapped_order_details_into_db"
    static let BgRetrieveScrappedOrderDetailsFromDB = "bg_get_scrapped_order_details_db"
    static let BgAPIUploadOrderDetails = "bg_api_upload_order_details"
    static let BgInjectJSForOrderListing = "bg_inject_js_against_order_listing_page"
    static let BgScrappingOrderListResultSuccess = "bg_scrapping_order_list_result_success"
    static let BgScrappingOrderListResultFailure = "bg_scrapping_order_list_result_failure"
   
    static let ScrappingDetails = "scrapping_step_details"
    static let StepAuthentication = "step_authentication"
    static let StepGenerateReport = "step_generateReport"
    static let StepDownloadReport = "step_downloadReport"
    static let StepParseReport = "step_parseReport"
    static let StepUploadReport = "step_uploadReport"
    static let StepComplete = "step_complete"
    static let StepStarHtmlScrapping = "step_startHtmlScrapping"
    static let StepListScrappingSuccess = "step_list_scrapping_success"
    static let StepListScrappingFailure = "step_list_scrapping_failure"
    static let UrlLoadedReportScrapping = "url_loaded_during_report_scrapping"
    static let StepDetailsScarapingSuccess = "step_details_scrapping_success"
    static let StepDetailsScarapingFailure = "step_details_scrapping_failure"
    static let StepOtherURLLoaded = "step_other_url_loaded"
    static let ShowNotification = "show_notification"
    
    static let APIRegisterUser = "api_register_connection"
    static let APIGetAccounts = "api_get_accounts"
    static let APIFetchScript = "api_fetch_script"
    static let APIConfigDetails = "api_config_details"
    
    //Events for exception/error
    static let InCoolOffPeriod = "In Cool off period"
    static let UserAbortedProcess = "User Aborted process by clicking on back"
    static let ExceptionDownloadingCSVFile = "Exception while downloading csv file"
    static let ExceptionWhileUpdatingCSVFile = "Exception while updating downloaded csv file"
    static let HtmlScrapingFailed = "HTML scraping failed"
    static let GetAccountAPIFailed = "Get accounts API failed"
    static let PIIDetailsAPIFailed = "PII details API failed"
    static let UpdateStatusAPIFailed = "Update status API failed"
    static let ExceptionWhileDateRangeAPI = "Exception while making date range API"
    static let UploadReportAPIFailed = "Upload Report API failed"
    static let UploadOrdersAPIFailed = "Upload Orders API failed"
    static let GetScraperConfigAPIFailed = "Get scrapper config API failed"
    static let UpdateStatusAPIFailedWhileDisconnect = "Update status API failed while disconnecting"
    static let UserRegistrationAPIFailed = "User registration API failed"
    static let ExceptionWhileGettingConfiguration = "Exception while getting configuration"
    static let ExceptionWhileLoadingScrapingScript = "Exception while loading scraping script"
    static let FailureWhileDownloadingScript = "Exception while downloading script file"
    static let ExceptionWhileLocalDBInsertion = "Exception while inserting order details to local DB"
    static let EncounteredCaptcha = "User Encountered Captcha"
    static let DidFailPageNavigation = "did fail page navigation called from webview"
    static let DidFailProvisionalNavigation = "did fail provisional navigation called from webview"
    static let WebContentProcessDidTerminate = "WebContentProcessDidTerminate"
    static let UserAuthenticationFailed = "User Authentication failed"
    static let ExceptionWhileApplyingRegexCSV = "Exception while applying regex to downloaded csv file"
    static let ExceptionWhileGettingAuthenticator = "Authenticator is null"
    static let ExceptionWhileGettingOrderSource = "Order source is null"
    static let ScrappingDisable = "Scrapping disable"
    static let ConfigsMissing = "Configs missing"
    static let LibNotInit = "Library not initialised"
    static let OrderExtractionFailure = "Order extraction failure"
    static let APIFailed = "API failed"
    static let ErrorWhileEvaluatingJS = "Error while evaluating java script"
    static let TimeoutOccurred = "Timeout occurred"



    static let exception_while_details_parsing = "Exception while parsing details json response returned by script"
    static let exception_while_stopping_scraping = "Exception while stopping the scraping"
    static let exception_while_html_scraping = "Exception while html list scraping"
    static let reconnect_authentication_failed = "User Authentication failed while reconnecting"
    static let exception_while_parsing_dates = "Exception while parsing dates while report generation"
    static let error_loading_frame = "Error while loading frame"
    static let exception_while_updating_user_status_DB = "Exception while updating user status to local DB"
    static let exception_returned_from_script = "Exception from script while scraping"
    static let failure_while_saving_script_storage = "Exception while saving script file to internal storage"
   
    static let on_received_error_webview = "Webview returned callback to onReceivedError method"
    static let on_received_http_error_webview = "Webview returned callback to onReceivedHttpError method"
    static let on_received_ssl_error_webview = "Webview returned callback to onReceivedSslError method"
    static let exception_while_reading_intent = "Exception while getting account object from Intent"
    static let get_accounts_response_parsing = "Exception while get accounts API response parsing"


}

struct EventStatus {
    static let Connected = "connected"
    static let Success = "success"
    static let Failure = "failure"
}
