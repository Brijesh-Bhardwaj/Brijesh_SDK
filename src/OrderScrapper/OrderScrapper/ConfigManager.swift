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
            if let response = response {
                self.configs[OrderSource.Amazon] = response.amazon.urls
                completion(self.configs[orderSource], nil)
            } else {
                completion(nil, APIError(error: Strings.ErrorNoConfigurationsFound))
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
