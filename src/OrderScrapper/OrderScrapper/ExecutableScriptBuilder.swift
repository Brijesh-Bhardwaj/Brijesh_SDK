//  ExecutableScriptBuilder.swift
//  OrderScrapper

import Foundation

class ExecutableScriptBuilder {
    
    func getExecutableScript(param: ScriptParam) -> String {
        var inputData: String
        if param.scrappingPage == .details {
            inputData = getInputDataForDetailPage(scrappingPage: param.scrappingPage, detailUrl: param.url, orderId: param.orderId!, orderDate: param.orderDate!)
        } else {
            inputData = getInputDataForListingPage(scrappingPage: param.scrappingPage, dateRange: param.dateRange!, urls: param.urls!)
        }
        let executableScript = "const inputData =" + inputData + ";" + param.script
        return executableScript
    }
    
    func getInputDataForListingPage(scrappingPage: ScrappingPage, dateRange: DateRange, urls: Urls) -> String {
        var jsonString = ""
        do {
            let input = ListingPageScriptInput(type: scrappingPage.rawValue, urls: urls, startDate: dateRange.fromDate!, endDate: dateRange.toDate!, lastOrderId: dateRange.lastOrderId ?? "")
            let encoder = JSONEncoder()
            encoder.outputFormatting = .withoutEscapingSlashes
            let jsonData = try encoder.encode(input)
            jsonString = String(data: jsonData, encoding: .utf8)!
        } catch {
            FirebaseAnalyticsUtil.logSentryMessage(message: "error getting getInputDataForListingPage")
        }
       
        return jsonString
    }
    
    func getInputDataForDetailPage(scrappingPage: ScrappingPage, detailUrl: String, orderId: String, orderDate: String) -> String {
        var jsonString = ""
        do {
            let input = DetailPageScriptInput(type: scrappingPage.rawValue, detailsUrl: detailUrl, orderId: orderId, orderDate: orderDate)
            let encoder = JSONEncoder()
            encoder.outputFormatting = .withoutEscapingSlashes
            let jsonData = try encoder.encode(input)
            jsonString = String(data: jsonData, encoding: .utf8)!
        } catch {
            FirebaseAnalyticsUtil.logSentryMessage(message: "error getting getInputDataForDetailPage")
        }
        return jsonString
    }
}
