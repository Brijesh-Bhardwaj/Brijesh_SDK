//  ScrapeConfigs.swift
//  OrderScrapper


import Foundation

class ScrapeConfigs: Decodable {
    let configurations: [PlatformSourceConfig]
    let sentry: SentryConfigs
}
