//
//  ReportConfig.swift
//  OrderScrapper
//

import Foundation

struct ReportConfig {
    var fullStartDate: String!
    var fullEndDate: String!
    var startDate: String
    var startMonth: String
    var startYear: String
    var endDate: String
    var endMonth: String
    var endYear: String
    var reportType: String
    
    init() {
        startDate = ""
        startMonth = ""
        startYear = ""
        endDate = ""
        endMonth = ""
        endYear = ""
        reportType = "SHIPMENTS"
    }
}
