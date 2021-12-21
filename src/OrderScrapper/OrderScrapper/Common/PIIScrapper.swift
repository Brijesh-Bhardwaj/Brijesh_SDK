//
//  PIIScrapper.swift
//  OrderScrapper
//

import Foundation
import CSV

class PIIScrapper {
    let dispatchQueue = DispatchQueue.global(qos: .background)
    let fileURL: URL
    let fileName: String
    let orderSource: OrderSource
    
    init(fileURL url: URL, fileName name: String, orderSource: OrderSource) {
        self.fileURL = url
        self.fileName = name
        self.orderSource = orderSource
    }
    
    func scrapPII(attributes: [PIIAttribute], completionHandler: @escaping (URL?, Error?) -> Void) {
        dispatchQueue.async {
            guard let stream = InputStream(url: self.fileURL) else {
                completionHandler(nil, nil)
                return
            }
            
            let downloadURL = FileHelper.getReportDownloadPath(fileName: self.fileName, orderSource: self.orderSource)
            guard let outputStream = OutputStream(url: downloadURL, append: false) else {
                completionHandler(nil, nil)
                return
            }
            
            do {
                let writer = try CSVWriter(stream: outputStream)
                let reader = try CSVReader(stream: stream, hasHeaderRow: true)
                
                defer {
                    writer.stream.close()
                }
                
                var piiAttributes: [String] = []
                for attribute in attributes {
                    if attribute.regex == nil {
                        piiAttributes.append(attribute.attributes)
                    }
                }
                
                let headers = reader.headerRow!
                let requiredHeaders = headers.filter {
                    !piiAttributes.contains($0)
                }
                
                try writer.write(row: requiredHeaders)
                
                while reader.next() != nil {
                    writer.beginNewRow()
                    
                    for attribute in requiredHeaders {
                        if let attributeValue = reader[attribute] {
                            let searchedValue = attributes.first {
                                $0.attributes == attribute
                            }
                            if let searchedValue = searchedValue, let regex = searchedValue.regex {
                                do {
                                    let regex = try NSRegularExpression(pattern: regex, options: [])
                                    let result = regex.firstMatch(in: attributeValue, options: [],  range: NSRange(attributeValue.startIndex..., in: attributeValue))
                                    try result.map {
                                           let pValue = String(attributeValue[Range($0.range, in: attributeValue)!])
                                        try writer.write(field: pValue)
                                        }
                                    
                                } catch let error {
                                    print("invalid regex",error)
                                    let panelistId = LibContext.shared.authProvider.getPanelistID()
                                    let logEventAttributes = [EventConstant.OrderSource: self.orderSource.value,
                                                             EventConstant.PanelistID: panelistId,
                                                             EventConstant.Status: EventStatus.Failure,
                                                             EventConstant.EventName: EventType.ExceptionWhileApplyingRegexCSV]
                                    FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
                                }
                            } else {
                                try writer.write(field: attributeValue)
                            }
                            
                        }
                    }
                }
                completionHandler(downloadURL, nil)
            }catch {
                completionHandler(nil, nil)
            }
            
        }
    }
}

