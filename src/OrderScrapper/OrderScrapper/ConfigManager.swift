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
                            scrapperConfig.urls.manualScrapeTimeout = scrapperConfig.orderUpload.manualScrapeTimeout
                            scrapperConfig.urls.manualScrapeReportTimeout = scrapperConfig.orderUpload.manualScrapeReportTimeout
                            scrapperConfig.urls.manualScrapeTimeoutMessage = scrapperConfig.messages.manualScrapeTimeoutMessage
                            LibContext.shared.manualScrapeTimeOutMessage = scrapperConfig.urls.manualScrapeTimeoutMessage ?? Strings.TimeOutFailureMessage
                            scrapperConfig.urls.manualScrapeSuccess = scrapperConfig.messages.manualScrapeSuccess
                            LibContext.shared.manualScrapeSuccess = scrapperConfig.urls.manualScrapeSuccess ?? Strings.ManualSuccessMessage
                            scrapperConfig.urls.onlineScrapingSuccessNote = scrapperConfig.messages.onlineScrapingSuccessNote
                            LibContext.shared.onlineScrapingSuccessNote = scrapperConfig.urls.onlineScrapingSuccessNote ?? Strings.OnlineIncentiveMessage
                            scrapperConfig.urls.onlineScrapingSuccessMessage = scrapperConfig.messages.onlineScrapingSuccessMessage
                            LibContext.shared.onlineScrapingSuccessMessage = scrapperConfig.urls.onlineScrapingSuccessMessage ?? Strings.OnlineSuccessMessage
                            scrapperConfig.urls.onlineScrapingTimeoutMessage = scrapperConfig.messages.onlineScrapingTimeoutMessage
                            LibContext.shared.onlineScrapingTimeoutMessage = scrapperConfig.urls.onlineScrapingTimeoutMessage ?? Strings.OnlineScrapingTimeoutMessage
                            scrapperConfig.urls.noOrdersInWeekMessage = scrapperConfig.messages.noOrdersInWeekMessage
                            LibContext.shared.noOrdersInWeekMessage = scrapperConfig.urls.noOrdersInWeekMessage ?? Strings.OnlineZeroOrders
                            scrapperConfig.urls.manualScrapeNote = scrapperConfig.messages.manualScrapeNote
                            LibContext.shared.manualScrapeNote = scrapperConfig.urls.manualScrapeNote ?? Strings.ManualScrapeNote
                            scrapperConfig.urls.onlineZeroOrdersNote = scrapperConfig.messages.onlineZeroOrdersNote
                            LibContext.shared.onlineZeroOrdersNote = scrapperConfig.urls.onlineZeroOrdersNote ?? Strings.ZeroOrdersNote
                            scrapperConfig.urls.uploadBatchSize = scrapperConfig.orderUpload.uploadBatchSize
                            scrapperConfig.urls.onlineScrapingFailedMessage = scrapperConfig.messages.onlineScrapingFailedMessage
                            LibContext.shared.onlineScrapingFailedMessage = scrapperConfig.urls.onlineScrapingFailedMessage ?? Strings.OnlineFetchFailureMessage
                            scrapperConfig.urls.manualNoNewOrdersNote = scrapperConfig.messages.manualNoNewOrdersNote
                            LibContext.shared.noNewManualOrdersNote = scrapperConfig.urls.manualNoNewOrdersNote ?? Strings.noNewOrdersNote
                            scrapperConfig.urls.manualNoNewOrdersMessage = scrapperConfig.messages.manualNoNewOrdersMessage
                            LibContext.shared.noNewManualOrders = scrapperConfig.urls.manualNoNewOrdersMessage ?? Strings.noNewOrders
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
                if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
                    let error = ASLException(error: nil, errorMessage: Strings.ErrorServicesDown, failureType: .servicesDown)
                    LibContext.shared.servicesStatusListener.onServicesFailure(exception: error)
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
