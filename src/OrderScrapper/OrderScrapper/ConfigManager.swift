//  ConfigManager.swift
//  OrderScrapper

import Foundation
import Sentry

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
        _ = AmazonService.getScrapperConfig(orderSource: [orderSource.value]) { response, error in
            var logEventAttributes:[String:String] = [:]
            if let platformSourceConfigs = response {
                for scrapperConfig in platformSourceConfigs {
                    if scrapperConfig.platformSource == orderSource.value {
                        self.configs[OrderSource.Amazon] = scrapperConfig.urls
                        completion(self.configs[orderSource], nil)
                        break
                    }
                }
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
                    let error = APIError(error: Strings.ErrorNoConfigurationsFound)
                    SentrySDK.capture(error: error)
                    completion(nil, error)
                }
            }
        } else {
            self.loadConfigs(orderSource: orderSource) { configurations, error in
                completion(configurations, error)
            }
        }
    }
}
