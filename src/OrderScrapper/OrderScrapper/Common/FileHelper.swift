//
//  FilePathHelper.swift
//  OrderScrapper
//

import Foundation

struct Directories {
    static let Reports = "Reports"
    static let Amazon = "Amazon"
    static let Scripts = "Scripts"
    static let Instcart = "Instacart"
    static let Walmart = "Walmart"
}
struct File {
    static let ScrapperScript = "ScrapperScript.txt"
    static let AuthenticationScript = "AuthScript.txt"
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
        case .Instacart:
            downloadDirectoryURL = documentsURL
        case .Kroger:
            downloadDirectoryURL = documentsURL
        case .Walmart:
            downloadDirectoryURL = documentsURL
        }
        try? FileManager.default.createDirectory(at: downloadDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        return downloadDirectoryURL
    }
    
    private static func getDocumentsDirectory() -> URL {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        return URL(fileURLWithPath: documentsPath)
    }
    
    /*
     * To delete all files contain in the given directory path
     */
    static func clearDirectory(orderSource: OrderSource) {
        let downloadDirectoryURL: URL = getReportDownloadDirectory(orderSource: orderSource)
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: downloadDirectoryURL,
                                                                       includingPropertiesForKeys: nil,
                                                                       options: .includesDirectoriesPostOrder)
            for fileURL in fileURLs {
                do {
                    try FileManager.default.removeItem(at: fileURL)
                } catch {print(AppConstants.tag, "clearDirectory", error.localizedDescription)}
            }
        } catch  { print(AppConstants.tag, "clearDirectory", error.localizedDescription) }
    }
    
    // MARK: - Public Methods
    static func getScriptDownloadPath(fileName: String, orderSource: OrderSource) -> URL {
        let downloadDirectoryURL = getScriptDownloadDirectory(orderSource: orderSource)
        return downloadDirectoryURL.appendingPathComponent(fileName)
    }
    
    // MARK: - Private Methods
    private static func getScriptDownloadDirectory(orderSource: OrderSource) -> URL {
        let documentsURL = getDocumentsDirectory()
        var downloadDirectoryURL: URL
        switch orderSource {
        case .Amazon:
            downloadDirectoryURL = documentsURL
                .appendingPathComponent(Directories.Scripts)
                .appendingPathComponent(Directories.Amazon)
        case .Instacart:
            downloadDirectoryURL = documentsURL
                .appendingPathComponent(Directories.Scripts)
                .appendingPathComponent(Directories.Instcart)
        case .Kroger:
            downloadDirectoryURL = documentsURL
        case .Walmart:
            downloadDirectoryURL = documentsURL
                .appendingPathComponent(Directories.Scripts)
                .appendingPathComponent(Directories.Walmart)
        }
        try? FileManager.default.createDirectory(at: downloadDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        return downloadDirectoryURL
    }
    
    static func getDataFromFile(fileUrl: URL) -> String? {
        var fileContent: String?
        do {
            fileContent = try String(contentsOf: fileUrl, encoding: .utf8)
            return fileContent
        }
        catch {
            print("getDataFromFile(): Error in reading file content")
        }
        return fileContent
    }
    
    //Get script file URL for the given order source
    static func getScriptFilePath(orderSource: OrderSource, isAuthScript: String) -> URL {
        var fileName = ""
        if isAuthScript == ScriptType.auth.rawValue {
            fileName = String(orderSource.value) + File.AuthenticationScript
        } else {
            fileName = String(orderSource.value) + File.ScrapperScript
        }
        let filePath = FileHelper.getScriptDownloadPath(fileName: fileName, orderSource: orderSource)
        return filePath
    }
    
    //Check script file exist or not for given order source
    static func isScriptFileExist(orderSource: OrderSource, isAuthScript: String) -> Bool {
        let filePath = FileHelper.getScriptFilePath(orderSource: orderSource, isAuthScript: isAuthScript)
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: filePath.path)
    }
}
