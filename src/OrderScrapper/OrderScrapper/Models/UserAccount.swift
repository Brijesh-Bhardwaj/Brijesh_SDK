//
//  UserAccount.swift
//  OrderScrapper
//
//  Created by Avinash Mohanta on 04/04/22.
//

import Foundation

public class UserAccount: Account {
    var userId: String
    var password: String
    var accountStatus: String
    var orderSource: Int16
    var firstAcc: Bool
    var panelistId: String
    
    init() {
        self.userId = ""
        self.password = ""
        self.accountStatus = AccountState.NeverConnected.rawValue
        self.orderSource = 0
        self.firstAcc = false
        self.panelistId = ""
    }
    
    init(dbAccount: UserAccountMO) {
        self.userId = dbAccount.userId
        self.password = dbAccount.password
        self.accountStatus = dbAccount.accountStatus
        self.orderSource = dbAccount.orderSource
        self.firstAcc = dbAccount.firstAcc
        self.panelistId = dbAccount.panelistId
    }
    
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
    public func fetchOrders(orderExtractionListener: OrderExtractionListener, source: FetchRequestSource) -> RetailerScrapingStatus {
        
        let isScrapping =  AmazonOrderScrapper.shared.startOrderExtraction(account: self,
                                                        orderExtractionListener: orderExtractionListener,source: source)
        return isScrapping
    }
    
    // MARK: - Private Methods
    private func getOrderSource() -> OrderSource {
        return OrderSource(rawValue: self.orderSource)!
    }
}
