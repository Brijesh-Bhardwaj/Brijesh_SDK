//
//  Event.swift
//  OrderScrapper


import Foundation

struct EventConstant {
    static let Authentication = "authentication"
    static let PanelistID = "panelist_id"
    static let OrderSource = "order_source"
    static let OrderSourceID = "order_source_id"
    static let AppID = "app_id"
    static let Status = "status"
    static let Reason = "reason"
    static let StackTrace = "stack_trace"
    static let ErrorReason = "error_reason"
    static let FileName = "file_name"
    static let URL = "url"
    static let Message = "message"
    
    static let ScrappingType = "scrapping_type" //html/report
    static let ScrappingMode = "scrapping_mode" // foreground/background
    static let ScrappingStep = "scrapping_step" //
    static let Platform = "platform"
    static let Data = "data"
    static let EventName = "event_name"
    static let JSInjectType = "js_inject_type"
    
    static let ScrappingTime = "scrapping_time" // time logging for specific task
}
