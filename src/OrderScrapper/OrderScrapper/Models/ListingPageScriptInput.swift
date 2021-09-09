//  BSScriptInput.swift
//  OrderScrapper

import Foundation

struct ListingPageScriptInput: Encodable {
    let type: String
    let urls:Urls
    let startDate:String
    let endDate:String
    let lastOrderId: String
}

struct DetailPageScriptInput: Encodable{
    let type: String
    let detailsUrl: String
    let orderId: String
}

struct Urls: Encodable {
    let login: String
    let listing: String
    let details: String
}
