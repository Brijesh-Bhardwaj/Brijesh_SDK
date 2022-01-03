//  FailureTypes.swift
//  OrderScrapper

import Foundation

public enum FailureTypes: String {
    case captcha
    case unknownURL
    case timeout
    case other
    case pageNotLoded
    case authentication
    case csvDownload
    case notify
    case none
    case jsFailed
    case servicesDown
}
