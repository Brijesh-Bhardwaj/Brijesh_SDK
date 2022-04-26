//
//  IncnetiveFlagReponse.swift
//  OrderScrapper
//
//  Created by Amey Ranade on 18/02/22.
//

import Foundation


class IncnetiveFlagReponse: Codable {
    let isFlagEnabled: Bool
    let currentDay: String
    let lastWeekOrderCount: LastWeekOrderCount
}
