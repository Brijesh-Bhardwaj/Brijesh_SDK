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
    
    func loadConfigs(orderSource: OrderSource, completion: @escaping (ScrapeConfigs?, Error?) -> Void) {
        //get Scrapper config details
        _ = AmazonService.getScrapperConfig(orderSource: [orderSource.value]) { response, error in
            var logEventAttributes:[String:String] = [:]
            if let platformSourceConfigs = response?.configurations {
                for scrapperConfig in platformSourceConfigs {
                    if scrapperConfig.platformSource == orderSource.value {
                        scrapperConfig.urls.captchaRetries = scrapperConfig.connections.captchaRetries
                        scrapperConfig.urls.cooloffPeriodCaptcha = scrapperConfig.connections.cooloffPeriodCaptcha
                        self.configs[OrderSource.Amazon] = scrapperConfig.urls
                        break
                    }
                }
                
                completion(response, nil)
                
                logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                      EventConstant.Status: EventStatus.Success]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgAPIScrapperConfig, eventAttributes: logEventAttributes)
            } else {
                completion(nil, APIError(error: Strings.ErrorNoConfigurationsFound))
                
                logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                      EventConstant.ErrorReason: Strings.ErrorInScrapperConfigAPI,
                                      EventConstant.Status: EventStatus.Failure]
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.BgAPIScrapperConfig, eventAttributes: logEventAttributes)
            }
        }
    }
    
    func getConfigurations(orderSource: OrderSource, completion: @escaping (Configurations?, Error?) -> Void) {
        if !configs.isEmpty {
            let configs = getConfigDetails(orderSource: orderSource)
            if let configs = configs {
                completion(configs, nil)
            } else {
                let error = APIError(error: Strings.ErrorNoConfigurationsFound)
                SentrySDK.capture(error: error)
                completion(nil, error)
            }
        } else {
            self.loadConfigs(orderSource: orderSource) { [self] configurations, error in
                let configs = getConfigDetails(orderSource: orderSource)
                if let configs = configs {
                    completion(configs, nil)
                } else {
                    let error = APIError(error: Strings.ErrorNoConfigurationsFound)
                    SentrySDK.capture(error: error)
                    completion(nil, error)
                }
            }
        }
    }
    
    func getConfigDetails(orderSource: OrderSource) -> Configurations? {
        switch orderSource {
        case .Amazon:
            if let configs = configs[orderSource] {
                return configs
            } else {
                return nil
            }
        }
    }
}

