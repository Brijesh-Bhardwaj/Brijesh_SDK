//  ExecutableScriptBuilder.swift
//  OrderScrapper

import Foundation

class ExecutableScriptBuilder {
    
    func getExecutableScript(param: ScriptParam) -> String {
        var inputData: String
        if param.scrappingPage == .details {
            inputData = getInputDataForDetailPage(scrappingPage: param.scrappingPage, detailUrl: param.url, orderId: param.orderId!)
        } else {
            inputData = getInputDataForListingPage(scrappingPage: param.scrappingPage, dateRange: param.dateRange!, urls: param.urls!)
        }
        let executableScript = "const inputData =" + inputData + ";" + param.script
        print("### executableScript", executableScript)
        return executableScript
    }
    
    func getInputDataForListingPage(scrappingPage: ScrappingPage, dateRange: DateRange, urls: Urls) -> String {
        let input = ListingPageScriptInput(type: scrappingPage.rawValue, urls: urls, startDate: dateRange.fromDate!, endDate: dateRange.toDate!, lastOrderId: dateRange.lastOrderId ?? "")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        let jsonData = try! encoder.encode(input)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        return jsonString
    }
    
    func getInputDataForDetailPage(scrappingPage: ScrappingPage, detailUrl: String, orderId: String) -> String {
        let input = DetailPageScriptInput(type: scrappingPage.rawValue, detailsUrl: detailUrl, orderId: orderId)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        let jsonData = try! encoder.encode(input)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        return jsonString
    }
}
