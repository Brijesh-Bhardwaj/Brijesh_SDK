import Foundation
import CoreData

//  UserAccount.swift
//  OrderScrapper
/*
 It is a class used to change account state as connected and disconnected and
 update it into the core data. Also used to fetch
 connected account from the core data. It implements Account protocol
 **/

@objc(UserAccount)
public class UserAccountMO: NSManagedObject, Account {
    @NSManaged var userId: String
    @NSManaged var password: String
    @NSManaged var accountStatus: String
    @NSManaged var orderSource: Int16
    @NSManaged var firstAcc: Bool
    @NSManaged var panelistId: String
    
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
    
    public var isFirstConnectedAccount: Bool {
        get {
            return firstAcc
        }
        set {
            firstAcc = newValue
        }
    }
    
    public var panelistID: String {
        get {
            return panelistId
        }
        set {
            panelistId = newValue
        }
    }
    /// Use this method to change  account state as connected. If already connected it returns from the methods.
    /// - Parameter orderExtractionListener: It is a listener which gives onOrderExtractionSuccess and onOrderExtractionFailure callback
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
    /// Use this method to change account state as ConnectedAndDisconnected  and if already connected it returns from the methods.
    /// - Parameter accountDisconnectedListener: It is a listener which gives onAccountDisconnected and onAccountDisconnectionFailed callback
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
    /// Use this method to fetch already connected account
    /// - Parameter orderExtractionListener: It is a listener which gives onOrderExtractionSuccess and onOrderExtractionFailure callback
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
