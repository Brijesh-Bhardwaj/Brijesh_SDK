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
}

struct EventStatus {
    static let Connected = "connected"
    static let Success = "success"
    static let Failure = "failure"
}
