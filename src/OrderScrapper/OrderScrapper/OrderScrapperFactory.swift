//
//  OrderScrapperFactory.swift
//  OrderScrapper
//
import Foundation

public class OrderScrapperFactory {
    public static func createScrapper(orderSource : OrderSource,
                                      authProvider : AuthProvider,
                                      viewPresenter : ViewPresenter) -> OrderScrapper {
        var orderScrapperLib: OrderScrapper
        
        switch orderSource {
        case .Amazon:
            orderScrapperLib = AmazonOrderScrapper(authProvider: authProvider, viewPresenter: viewPresenter)
        }
        
        return orderScrapperLib
    }
}
