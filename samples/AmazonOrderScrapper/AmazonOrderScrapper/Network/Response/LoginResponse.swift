//
//  LoginResponse.swift
//  AmazonOrderScrapper


import Foundation

class LoginResponse: Decodable {
    var success: Bool = false
    var panelistId: String?
    var token: String?
    var scanType: String?
    var langId: String?
    var email: String?
    var disclaimerURL: String?
    var privacyURL: String?
    var countryCode: String?
}
