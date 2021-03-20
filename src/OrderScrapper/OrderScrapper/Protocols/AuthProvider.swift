//
//  AuthProvider.swift
//  OrderScrapper
//
import Foundation

public protocol AuthProvider {
    func getAuthToken() -> String
    func getPanelistID() -> String
}
