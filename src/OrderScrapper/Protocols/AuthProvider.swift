//
//  AuthProvider.swift
//  OrderScrapper
//
//  Created by Prakhar on 03/03/21.
//

import Foundation
public protocol AuthProvider {
    func getAuthToken() -> String
}
