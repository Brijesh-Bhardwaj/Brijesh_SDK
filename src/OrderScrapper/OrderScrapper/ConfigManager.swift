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
    
    func loadConfigs(orderSources: [OrderSource], completion: @escaping (ScrapeConfigs?, Error?) -> Void) {
        var sourceArray : [String] = []
        for orderSource in orderSources {
            sourceArray.append(orderSource.value)
        }
        _ = AmazonService.getScrapperConfig(orderSource: sourceArray) { response, error in
            var logEventAttributes:[String:String] = [:]
            let panelistId = LibContext.shared.authProvider.getPanelistID()
            logEventAttributes = [EventConstant.PanelistID: panelistId]
            
            if let platformSourceConfigs = response?.configurations {
                var json: String
                do {
                    let jsonData = try JSONEncoder().encode(response)
                    json = String(data: jsonData, encoding: .utf8)!
                } catch {
                    json = AppConstants.ErrorInJsonEncoding
                }
                for orderSource in orderSources {
                    for scrapperConfig in platformSourceConfigs {
                        if scrapperConfig.platformSource == orderSource.value {
                            scrapperConfig.urls.captchaRetries = scrapperConfig.connections.captchaRetries
                            scrapperConfig.urls.loginRetries = scrapperConfig.connections.loginRetries
                            scrapperConfig.urls.cooloffPeriodCaptcha = scrapperConfig.connections.cooloffPeriodCaptcha
                            scrapperConfig.urls.orderDetailDelay = scrapperConfig.orderUpload.orderDetailDelay
                            scrapperConfig.urls.orderUploadRetryCount = scrapperConfig.orderUpload.orderUploadRetryCount
                            self.configs[orderSource] = scrapperConfig.urls
                            break
                        }
                    }
                }
                
                completion(response, nil)
                
                logEventAttributes[EventConstant.Data] = json
                logEventAttributes[EventConstant.Status] = EventStatus.Success
                FirebaseAnalyticsUtil.logEvent(eventType: EventType.APIConfigDetails, eventAttributes: logEventAttributes)
            } else {
                completion(nil, APIError(error: Strings.ErrorNoConfigurationsFound))
                
                if let error = error {
                    logEventAttributes[EventConstant.Status] = EventStatus.Failure
                    logEventAttributes[EventConstant.EventName] = EventType.GetScraperConfigAPIFailed
                    FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
                } else {
                    FirebaseAnalyticsUtil.logEvent(eventType: EventType.GetScraperConfigAPIFailed, eventAttributes: logEventAttributes)
                }
            }
        }
    }
    func getConfigurations(orderSource: OrderSource, completion: @escaping (Configurations?, Error?) -> Void) {
        let panelistId = LibContext.shared.authProvider.getPanelistID()
        var logEventAttributes:[String:String] = [EventConstant.OrderSource: orderSource.value,
                                                  EventConstant.PanelistID: panelistId]
        
        if !configs.isEmpty {
            let configs = getConfigDetails(orderSource: orderSource)
            if let configs = configs {
                completion(configs, nil)
            } else {
                let error = APIError(error: Strings.ErrorNoConfigurationsFound)
                logEventAttributes[EventConstant.EventName] = EventType.ExceptionWhileGettingConfiguration
                logEventAttributes[EventConstant.Status] = EventStatus.Failure
                FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
                
                completion(nil, error)
            }
        } else {
            self.loadConfigs(orderSources: [.Amazon,.Instacart,.Kroger,.Walmart]) { [self] configurations, error in
                let configs = getConfigDetails(orderSource: orderSource)
                if let configs = configs {
                    completion(configs, nil)
                } else {
                    let error = APIError(error: Strings.ErrorNoConfigurationsFound)
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
        case .Instacart:
            if let configs = configs[orderSource] {
                return configs
            } else {
                return nil
            }
        case .Kroger:
            if let configs = configs[orderSource] {
                return configs
            } else {
                return nil
            }
        case .Walmart:
            if let configs = configs[orderSource] {
                return configs
            } else {
                return nil
            }
        }
    }
}
