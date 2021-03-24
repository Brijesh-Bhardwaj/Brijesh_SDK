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
        return userId
    }
    
    public var accountState: AccountState {
        return AccountState(rawValue: accountStatus)!
    }
}
