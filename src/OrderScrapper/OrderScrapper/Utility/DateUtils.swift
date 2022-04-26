//
//  DateUtils.swift
//  OrderScrapper
//

import Foundation

class DateUtils {
    static let APIDateFormat = "dd-MM-yyyy"
    
    private init() {
        
    }
    
    static func parseDateComponents(fromDate: String, dateFormat: String) -> DateComponents {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = dateFormat
        
        let date = dateFormatter.date(from:fromDate)!
        debugPrint("Parsed Date: ", date)
        
        let calendar = Calendar.current
        return calendar.dateComponents([.day,.month,.year], from: date)
    }
    
    static func getFormattedDate(dateStr: String) -> String{
        let dateFormatterGet = DateFormatter()
        dateFormatterGet.dateFormat = "dd-MM-yyyy"
        let date = dateFormatterGet.date(from: dateStr)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy"
        let formattedDate = dateFormatter.string(from: date!)
        return formattedDate
    }
    
    static func getDate(dateStr: String?) -> Date? {
        guard let dateStr = dateStr else { return nil }
        
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        dateFormatter.dateFormat = "M/d/yyyy"
        
        if let date = dateFormatter.date(from: dateStr) {
            return date
        }
        return nil
    }
    
    static func getDateStringFrom(date: Date?) -> String? {
        guard let date = date else { return nil }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M/d/yyyy"
        
        return dateFormatter.string(from: date)
    }
    
    static func getSessionTimer(getSessionTimeForOnline: FetchRequestSource) -> String? {
        let date = NSDate()
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        if getSessionTimeForOnline == .online {
            return dateFormatter.string(from: date as Date)
        } else {
            return nil
        }
        
    }
}
