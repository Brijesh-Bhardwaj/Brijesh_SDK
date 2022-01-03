//  AccountInfo.swift
//  OrderScrapper


import Foundation

public class AccountInfo {
    public init() {}
    
    public init(accounts: [Account]?, hasNeverConnected: Bool) {
        self.account = accounts
        self.hasNeverConnected = hasNeverConnected
    }
    
    public var account: [Account]? = []
    public var hasNeverConnected: Bool = false
}


