//
//  FileDownloader.swift
//  OrderScrapper
//

import Foundation

class FileDownloader {
    
    //TODO same method should be used for downloading
    func downloadFile(fromURL url: URL,
                     cookies: [HTTPCookie]?,
                            completion: @escaping (Bool, URL?) -> Void) {
        let session = URLSession.shared
        if let cookies = cookies {
            session.configuration.httpCookieStorage?.setCookies(cookies, for: url, mainDocumentURL: nil)
        }
        let task = session.downloadTask(with: url) { localURL, urlResponse, error in
            if let localURL = localURL {
                completion(true, localURL)
            }
            else {
                completion(false, nil)
                print(AppConstants.tag, "downloadReportFile", error.debugDescription)
            }
        }
        
        task.resume()
    }
    
    func downloadFile(urlRequest: URLRequest, destinationFilePath: URL,
                            completion: @escaping (URL?, Error?) -> Void) {
        let session = URLSession.shared
        let task = session.downloadTask(with: urlRequest) {  localURL, urlResponse, error in
            if let localURL = localURL {
                let destinationPath = FileHelper.moveFileToPath(fromURL: localURL, destinationURL: destinationFilePath)
                completion(destinationPath, nil)
            } else {
                completion(nil, APIError(error: "Script file downloading failed"))
                print(AppConstants.tag, "downloadScriptFile", error.debugDescription)
            }
        }
        
        task.resume()
    }
}
