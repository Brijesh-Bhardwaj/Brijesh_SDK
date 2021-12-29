//  Configurations.swift
//  OrderScrapper

import Foundation

class Configurations: Codable {
    let login: String
    let listing: String
    let details: String
    var captchaRetries: Int?
    var cooloffPeriodCaptcha: Double?
    var otherRetryCount: Int?
}

class Connection: Codable {
    var captchaRetries: Int
    var cooloffPeriodCaptcha: Double
    var otherRetryCount: Int
}
