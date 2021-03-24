//
//  OrderExtractionListener.swift
//  OrderScrapper
//

import Foundation

public protocol OrderExtractionListener {
    func onOrderExtractionSuccess()
    
    func onOrderExtractionFailure(error: ASLException)
}
