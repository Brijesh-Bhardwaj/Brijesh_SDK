//
//  StatusEnum.swift
//  OrderScrapper
//

import Foundation

public enum AccountState: Int16 {
    case NeverConnected
    case Connected
    case ConnectedAndDisconnected
    case ConnectedButException
}
