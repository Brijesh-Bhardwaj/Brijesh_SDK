//
//  FileDownloader.swift
//  OrderScrapper
//

import Foundation
import Sentry

class FileDownloader {
    func downloadReportFile(fromURL url: URL,
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
                if let error = error {
                    SentrySDK.capture(error: error)
                }
            }
        }
        
        task.resume()
    }
}
