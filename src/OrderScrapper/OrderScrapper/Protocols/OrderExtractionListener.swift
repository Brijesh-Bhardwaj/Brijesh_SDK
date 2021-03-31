//
//  OrderExtractionListener.swift
//  OrderScrapper
//

import Foundation

public protocol OrderExtractionListener {
    func onOrderExtractionSuccess(successType: OrderFetchSuccessType)
    
    func onOrderExtractionFailure(error: ASLException)
}
