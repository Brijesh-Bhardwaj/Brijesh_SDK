//  TimerHandler.swift
//  OrderScrapper

import Foundation

protocol TimerCallbacks {
    func onTimerTriggered(action: String)
}
class TimerHandler {
    private var timer: Timer?
    private var timerCallback: TimerCallbacks?
    
    init(timerCallback: TimerCallbacks) {
        self.timerCallback = timerCallback
    }
    
    public func removeCallbackListener() {
        self.timerCallback = nil
    }
    
    public func startTimer(action: String) {
        if let timer = timer {
            timer.invalidate()
            self.timer = nil
        }
        print("### TimerHandler: Timer Started ")
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(LibContext.shared.timeoutValue), repeats: false) { timer in
//            WebCacheCleaner.clear(completionHandler: nil)
            FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_timeout_for_\(action)")
            self.timerCallback?.onTimerTriggered(action: action)
            print("### TimerHandler: Timer triggered")
        }
    }
    
    public func startTimer(action: String, timerInterval: TimeInterval) {
        if let timer = timer {
            timer.invalidate()
            self.timer = nil
        }
        print("### TimerHandler: Start Timer Started ")
        timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: false) { timer in
            print("### TimerHandler: Start Timer triggered")
            WebCacheCleaner.clear(completionHandler: nil)
            self.timerCallback?.onTimerTriggered(action: action)
            print("### TimerHandler: Timer triggered")
        }
        
    }
    
    public func stopTimer() {
        if let timer = timer {
            timer.invalidate()
            self.timer = nil
            print("### TimerHandler: Stopped Timer ")
        }
    }
}
