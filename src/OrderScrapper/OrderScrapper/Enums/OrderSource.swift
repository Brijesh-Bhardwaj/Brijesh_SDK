import Foundation
//  ServiceProviderEnum.swift
//  OrderScrapper
/*
 Represents the various e-commerce receipts extraction sites
 supported the SDK
 **/
public enum OrderSource: Int16 {
    case Amazon
    case Instacart
    case Kroger
    case Walmart
    
    var value: String {
        return String(describing: self)
    }
}
