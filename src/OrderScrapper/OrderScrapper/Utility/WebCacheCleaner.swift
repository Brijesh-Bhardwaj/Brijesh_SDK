//
//  WebCacheCleaner.swift
//  OrderScrapper
//

import Foundation
import WebKit

final class WebCacheCleaner {
    
    class func clear(completionHandler: ((Bool) -> Void)?) {
        URLCache.shared.removeAllCachedResponses()
        URLCache.shared.diskCapacity = 0
        URLCache.shared.memoryCapacity = 0

        HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)
        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
           WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: records, completionHandler: {
               if let completionHandler = completionHandler {
                   print("#### Data Clear")
                   completionHandler(true)
               }
           })
         }
//        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
//            var recordsCount = records.count
//            if recordsCount == 0 {
//                if let completionHandler = completionHandler {
//                    completionHandler(true)
//                }
//            } else {
//                records.forEach { record in
//                    WKWebsiteDataStore.default().removeData(ofTypes: record.dataTypes, for: [record], completionHandler: {
//                        recordsCount = recordsCount - 1
//                        if recordsCount == 0 {
//                            if let completionHandler = completionHandler {
//                                completionHandler(true)
//                            }
//                        }
//                    })
//                }
//            }
//        }
    }
}
