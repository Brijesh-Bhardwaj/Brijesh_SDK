//
//  APIClient.swift
//  OrderScrapper
//

import Foundation

protocol APIClient {
    func executeAPI(completionHandler: @escaping (Any?, Error?) -> Void) -> Void
    
    func cancelAPI() -> Void
}

