//  ScrapeConfigs.swift
//  OrderScrapper


import Foundation

class ScrapeConfigs: Codable {
    let configurations: [PlatformSourceConfig]
    let sentry: SentryConfigs
}
