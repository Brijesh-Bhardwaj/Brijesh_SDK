//  BSOrderExtractionListener.swift
//  OrderScrapper
//


import Foundation

public protocol BSOrderExtractionListener {
    
    func bsOrderExtractionSuccess(successType: OrderFetchSuccessType, account: Account)
    
    func bsOrderExtractionFailure(error: ASLException, account: Account)
}
