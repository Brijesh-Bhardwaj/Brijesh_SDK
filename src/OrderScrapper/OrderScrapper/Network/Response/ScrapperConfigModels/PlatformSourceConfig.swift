//  PlatformSourceConfig.swift
//  OrderScrapper


import Foundation

class PlatformSourceConfig: Decodable {
    let platformSource: String
    let urls: Configurations
    let connections: Connection
}