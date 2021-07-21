//  ScrapeResponse.swift
//  OrderScrapper

import Foundation

class ScrapeResponse: Decodable {
    var data: [OrderDetails]?
}
