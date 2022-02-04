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
    
    func stop() -> String {
            endTime = CFAbsoluteTimeGetCurrent()
            if let endTime = endTime {
                var milliseconds = Int((endTime - startTime) * 1000)
                var seconds = Int(milliseconds / 1000)
                milliseconds %= 1000
                let minutes = seconds / 60
                seconds %= 60
                let message = "\(minutes):\(seconds):\(milliseconds)"
                return message
             }
        return ""
    }
    
    func stopTimer() -> Int64 {
        endTime = CFAbsoluteTimeGetCurrent()
        if let endTime = endTime {
            let milliseconds = Int64((endTime - startTime) * 1000)
            return milliseconds
        }
        return 0
    }
}


