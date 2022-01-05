//  Configurations.swift
//  OrderScrapper

import Foundation

class Configurations: Codable {
    let login: String
    let listing: String
    let details: String
    var captchaRetries: Int?
    var loginRetries: Int?
    var cooloffPeriodCaptcha: Double?
    var orderDetailDelay: Int?
    var orderUploadRetryCount: Int?
    var otherRetryCount: Int?
    var manualScrapeTimeout: Double?
    var manualScrapeReportTimeout: Double?
    var manualScrapeTimeoutMessage: String?
    init(login: String) {
        self.login = login
        self.details = ""
        self.listing = ""
    }
}

class Connection: Codable {
    var captchaRetries: Int
    var loginRetries: Int?
    var cooloffPeriodCaptcha: Double
    var otherRetryCount: Int
}

class OrderUpload: Codable {
    var orderDetailDelay: Int?
    var orderUploadRetryCount: Int?
    var manualScrapeTimeout: Double?
    var manualScrapeReportTimeout: Double?
}

class Messages: Codable {
    var manualScrapeTimeoutMessage: String?
}
