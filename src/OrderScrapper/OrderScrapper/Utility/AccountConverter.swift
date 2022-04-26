//
//  AccountConverter.swift
//  OrderScrapper
//
//  Created by Avinash Mohanta on 04/04/22.
//

import Foundation

internal class AccountConverter {
    
    public static func getAccountsFromDBAccounts(dbAccounts: [UserAccountMO]?) -> [UserAccount] {
        guard let dbAccounts = dbAccounts, !dbAccounts.isEmpty else {
            return []
        }
        
        var accounts: [UserAccount] = []
        for dbAccount in dbAccounts {
            accounts.append(UserAccount(dbAccount: dbAccount))
        }
        
        return accounts
    }
}
