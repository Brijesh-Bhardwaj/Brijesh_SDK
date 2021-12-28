//
//  APIClient.swift
//  OrderScrapper
//

import Foundation

protocol APIClient {
    func executeAPI(completionHandler: @escaping (Any?, ASLException?) -> Void) -> Void
    
    func cancelAPI() -> Void
}

