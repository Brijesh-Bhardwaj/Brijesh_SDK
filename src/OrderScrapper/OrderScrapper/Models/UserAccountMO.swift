//
//  UserAccount.swift
//  OrderScrapper

import Foundation
import CoreData

@objc(UserAccount)
public class UserAccountMO: NSManagedObject, Account {
    @NSManaged var userId: String
    @NSManaged var password: String
    @NSManaged var accountStatus: Int16
    @NSManaged var orderSource: Int16
    
    public var userID: String {
        get {
            return userId
        }
        set {
            userId = newValue
        }
    }
    
    public var userPassword: String {
        get {
            return RNCryptoUtil.decryptData(userId: userID, value: password)
        }
        set {
            password = RNCryptoUtil.encryptData(userId: userID, value: newValue)
        }
    }
    
    public var accountState: AccountState {
        get {
            return AccountState(rawValue: accountStatus)!
        }
        set {
            accountStatus = newValue.rawValue
        }
    }
    
    public func connect(orderExtractionListener: OrderExtractionListener) {
        if self.accountState == .Connected {
            //Already connected
            return
        }
        
        let orderSource = getOrderSource()
        switch orderSource {
        case .Amazon:
            AmazonOrderScrapper.shared.connectAccount(account: self, orderExtractionListener: orderExtractionListener)
        }
    }
    
    public func disconnect(accountDisconnectedListener: AccountDisconnectedListener) {
        if self.accountState == .ConnectedAndDisconnected {
            //Already disconnected
            return
        }
        
        let orderSource = getOrderSource()
        switch orderSource {
        case .Amazon:
            AmazonOrderScrapper.shared.disconnectAccount(account: self,
                                                         accountDisconnectedListener: accountDisconnectedListener)
        }
    }
    
    public func fetchOrders(orderExtractionListener: OrderExtractionListener) {
        let orderSource = getOrderSource()
        switch orderSource {
        case .Amazon:
            AmazonOrderScrapper.shared.startOrderExtraction(account: self,
                                                            orderExtractionListener: orderExtractionListener)
        }
    }
    
    // MARK: - Private Methods
    private func getOrderSource() -> OrderSource {
        return OrderSource(rawValue: self.orderSource)!
    }
}
