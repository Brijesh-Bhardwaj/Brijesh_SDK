//  PlatformSourceConfig.swift
//  OrderScrapper


import Foundation

class PlatformSourceConfig: Codable {
    let platformSource: String
    let urls: Configurations
    let connections: Connection
}
