//  ConfigManager.swift
//  OrderScrapper

import Foundation

class ConfigManager {
    private static var instance: ConfigManager!
    private var configs = Dictionary<OrderSource, Configurations>()
    private init() {
    }
    
    static var shared: ConfigManager = {  
        if instance == nil {
            instance = ConfigManager()
        }
        return instance
    }()
    
    func loadConfigs(orderSource: OrderSource, completion: @escaping (Configurations?, Error?) -> Void) {
        //get Scrapper config details
        _ = AmazonService.getScrapperConfig() { response, error in
            var logEventAttributes:[String:String] = [:]
            if let response = response {
                self.configs[OrderSource.Amazon] = response.amazon.urls
                completion(self.configs[orderSource], nil)
                
                logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                      EventConstant.Status: EventStatus.Success]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgAPIScrapperConfig, eventAttributes: logEventAttributes)
            } else {
                completion(nil, APIError(error: Strings.ErrorNoConfigurationsFound))
                
                logEventAttributes = [EventConstant.OrderSource: String(OrderSource.Amazon.rawValue),
                                      EventConstant.ErrorReason: Strings.ErrorInScrapperConfigAPI,
                                      EventConstant.Status: EventStatus.Failure]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgAPIScrapperConfig, eventAttributes: logEventAttributes)
            }
        }
    }
    
    func getConfigurations(orderSource: OrderSource, completion: @escaping (Configurations?, Error?) -> Void) {
        if !configs.isEmpty {
            switch orderSource {
            case .Amazon:
                if let configs = configs[orderSource] {
                    completion(configs, nil)
                } else {
                    completion(nil, APIError(error: Strings.ErrorNoConfigurationsFound))
                }
            }
        } else {
            self.loadConfigs(orderSource: orderSource) { configurations, error in
                completion(configurations, error)
            }
        }
    }
}
