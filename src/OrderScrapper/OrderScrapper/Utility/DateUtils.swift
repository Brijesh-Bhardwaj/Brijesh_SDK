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
}
