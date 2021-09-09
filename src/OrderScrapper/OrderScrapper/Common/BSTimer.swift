//  BSTimer.swift
//  OrderScrapper

import Foundation
import Sentry

class BSTimer {
    var startTime:CFAbsoluteTime = 0.0
    var endTime:CFAbsoluteTime?
    
    func start() {
        startTime = CFAbsoluteTimeGetCurrent()
    }
    
    func stop() -> String{
        endTime = CFAbsoluteTimeGetCurrent()
        if let endTime = endTime {
            let value = endTime - startTime
            var seconds = Int(value / 1000)
            let minutes = seconds / 60
            seconds %= 60
            let milliSeconds = Int(value) % 1000
            let message = " \(minutes):\(seconds):\(milliSeconds)"
            return message
         }
        return ""
    }
}


