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
    
    static func getDate(dateStr: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        dateFormatter.dateFormat = "dd-MM-yyyy"
        let date = dateFormatter.date(from: dateStr)
        print("Date ", dateStr, date)
        return date
    }
    
    static func getDateStringFrom(date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy"
        
        return dateFormatter.string(from: date)
    }
}
