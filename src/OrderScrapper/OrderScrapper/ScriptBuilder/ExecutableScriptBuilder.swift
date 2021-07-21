//  ExecutableScriptBuilder.swift
//  OrderScrapper

import Foundation

class ExecutableScriptBuilder {
    
    func getExecutableScript(param: ScriptParam) -> String {
        let executableScript = "const inputData =" +
            self.getScriptInputData(url: param.url, scrappingPage: param.scrappingPage, dateRange: param.dateRange) + ";" + param.script
        print("### executableScript", executableScript)
        return executableScript
    }
    
    func getScriptInputData(url: String, scrappingPage: ScrappingPage, dateRange: DateRange) -> String {
        let input = BSScriptInput(type: scrappingPage.rawValue, url: url, startDate: dateRange.fromDate!, endDate: dateRange.toDate!, lastOrderId: dateRange.lastOrderId ?? "")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        let jsonData = try! encoder.encode(input)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        return jsonString
    }
}
