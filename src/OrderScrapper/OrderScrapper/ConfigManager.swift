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
            let panelistId = LibContext.shared.authProvider.getPanelistID()
            logEventAttributes = [EventConstant.OrderSource: OrderSource.Amazon.value,
                                  EventConstant.PanelistID: panelistId]
            
            if let platformSourceConfigs = response?.configurations {
                var json: String
                do {
                    let jsonData = try JSONEncoder().encode(response)
                    json = String(data: jsonData, encoding: .utf8)!
                } catch {
                    json = AppConstants.ErrorInJsonEncoding
                }
                for scrapperConfig in platformSourceConfigs {
                    if scrapperConfig.platformSource == orderSource.value {
                        scrapperConfig.urls.captchaRetries = scrapperConfig.connections.captchaRetries
                        scrapperConfig.urls.cooloffPeriodCaptcha = scrapperConfig.connections.cooloffPeriodCaptcha
                        self.configs[OrderSource.Amazon] = scrapperConfig.urls
                        break
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
            self.loadConfigs(orderSource: orderSource) { [self] configurations, error in
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
        }
    }
}

