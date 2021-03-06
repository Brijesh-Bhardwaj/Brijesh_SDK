//  ScriptParam.swift
//  OrderScrapper

import Foundation

struct ScriptParam {
    let script: String
    let dateRange: DateRange?
    let url: String
    let scrappingPage: ScrappingPage
    let urls: Urls?
    let orderId: String?
    let orderDate: String?
}
