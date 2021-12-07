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
            if let accountState = AccountState(rawValue: accountStatus) {
                return accountState
            } else {
                //Return default state as ConnectedButException if accountState not available or nil
                return AccountState.ConnectedButException
            }
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
    
    public var source: OrderSource {
        get {
            return OrderSource(rawValue: self.orderSource)!
        }
    }
    
    /// Use this method to change  account state as connected. If already connected it returns from the methods.
    /// - Parameter orderExtractionListener: It is a listener which gives onOrderExtractionSuccess and onOrderExtractionFailure callback
    public func connect(orderExtractionListener: OrderExtractionListener) {
        if self.accountState == .Connected {
            //Already connected
            return
        }
        
        AmazonOrderScrapper.shared.connectAccount(account: self, orderExtractionListener: orderExtractionListener)
    }
    
    /// Use this method to change account state as ConnectedAndDisconnected  and if already connected it returns from the methods.
    /// - Parameter accountDisconnectedListener: It is a listener which gives onAccountDisconnected and onAccountDisconnectionFailed callback
    public func disconnect(accountDisconnectedListener: AccountDisconnectedListener) {
        let orderSource = getOrderSource()
        
        AmazonOrderScrapper.shared.disconnectAccount(account: self,
                                                     accountDisconnectedListener: accountDisconnectedListener, orderSource: orderSource.value)
    }
    
    /// Use this method to fetch already connected account
    /// - Parameter orderExtractionListener: It is a listener which gives onOrderExtractionSuccess and onOrderExtractionFailure callback
    // TODO:- ScrappingMode - fs,bs
    public func fetchOrders(orderExtractionListener: OrderExtractionListener, source: FetchRequestSource) {
        
        AmazonOrderScrapper.shared.startOrderExtraction(account: self,
                                                        orderExtractionListener: orderExtractionListener,source: source)
        
    }
    
    // MARK: - Private Methods
    private func getOrderSource() -> OrderSource {
        return OrderSource(rawValue: self.orderSource)!
    }
}
