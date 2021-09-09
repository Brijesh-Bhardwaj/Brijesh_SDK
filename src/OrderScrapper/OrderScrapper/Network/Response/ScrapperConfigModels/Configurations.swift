//  Configurations.swift
//  OrderScrapper

import Foundation

class Configurations: Decodable {
    let login: String
    let listing: String
    let details: String
    var captchaRetries: Int?
    var cooloffPeriodCaptcha: Double?
}

class Connection: Decodable {
    var captchaRetries: Int
    var cooloffPeriodCaptcha: Double
}
