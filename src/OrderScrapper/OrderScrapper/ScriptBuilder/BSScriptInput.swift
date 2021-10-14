//  BSScriptInput.swift
//  OrderScrapper

import Foundation

struct BSScriptInput: Encodable {
    let type: String
    let url:String
    let startDate:String
    let endDate:String
    let lastOrderId: String
}
