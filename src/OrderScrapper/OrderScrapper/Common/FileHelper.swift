//
//  FilePathHelper.swift
//  OrderScrapper
//

import Foundation

struct Directories {
    static let Reports = "Reports"
    static let Amazon = "Amazon"
}

class FileHelper {
    // MARK: - Public Methods
    static func getReportDownloadPath(fileName: String, orderSource: OrderSource) -> URL {
        let downloadDirectoryURL = getReportDownloadDirectory(orderSource: orderSource)
        return downloadDirectoryURL.appendingPathComponent(fileName)
    }
    
    static func moveFileToPath(fromURL url: URL, destinationURL: URL) -> URL {
        try? FileManager.default.removeItem(at: destinationURL)
        try? FileManager.default.moveItem(at: url, to: destinationURL)
        return destinationURL
    }
    
    static func getReportFileNameFromResponse(_ response:URLResponse) -> String {
        if let httpResponse = response as? HTTPURLResponse {
            let headers = httpResponse.allHeaderFields
            if let disposition = headers["Content-Disposition"] as? String {
                let components = disposition.components(separatedBy: ";")
                if components.count > 1 {
                    let innerComponents = components[1].components(separatedBy: "=")
                    if innerComponents.count > 1 {
                        if innerComponents[0].contains("filename") {
                            return innerComponents[1]
                        }
                    }
                }
            }
        }
        return "default.csv"
    }
    
    // MARK: - Private Methods
    private static func getReportDownloadDirectory(orderSource: OrderSource) -> URL {
        let documentsURL = getDocumentsDirectory()
        var downloadDirectoryURL: URL
        switch orderSource {
        case .Amazon:
            downloadDirectoryURL = documentsURL
                .appendingPathComponent(Directories.Reports)
                .appendingPathComponent(Directories.Amazon)
        }
        try? FileManager.default.createDirectory(at: downloadDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        return downloadDirectoryURL
    }
    
    private static func getDocumentsDirectory() -> URL {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        return URL(fileURLWithPath: documentsPath)
    }
}
