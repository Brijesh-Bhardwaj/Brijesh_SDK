//  TimerHandler.swift
//  OrderScrapper

import Foundation

protocol TimerCallbacks {
    func onTimerTriggered(action: String)
}
class TimerHandler {
    private var timer: Timer?
    private var timerCallback: TimerCallbacks
    
    init(timerCallback: TimerCallbacks) {
        self.timerCallback = timerCallback
    }
    
    public func startTimer(action: String) {
        if let timer = timer {
            timer.invalidate()
            self.timer = nil
        }
        print("### TimerHandler: Timer Started ")
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(LibContext.shared.timeoutValue), repeats: false) { timer in
            WebCacheCleaner.clear(completionHandler: nil)
            self.timerCallback.onTimerTriggered(action: action)
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
