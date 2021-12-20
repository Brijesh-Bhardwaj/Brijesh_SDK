//  AccountsManager.swift
//  OrderScrapper


import Foundation

class AccountsManager {
    private static var instance: AccountsManager!
    private init() {
    }
    private static var isInitialized = false
    
    
    static var shared: AccountsManager = {
        if instance == nil {
            instance = AccountsManager()
        }
        return instance
    }()
    
    func fetchAccounts(orderSources: [OrderSource], completionHandler: @escaping ([String: AccountInfo]) -> Void) {
        var sourceArray : [String] = []
        var dictionary = [String: AccountInfo]()
        
        for orderSource in orderSources {
            sourceArray.append(orderSource.value)
        }
        
        let panelistId = LibContext.shared.authProvider.getPanelistID()
        _ = AmazonService.getAccounts(orderSource: sourceArray) { response, error in
            DispatchQueue.global().async {
                if let response = response {
                    self.handleResponse(listOfAccounts: response, orderSources: orderSources) { dictionary in
                        completionHandler(dictionary)
                    }
                } else {
                    for orderSource in orderSources {
                        var accounts = CoreDataManager.shared.fetch(orderSource: orderSource, panelistId: panelistId)
                        let showNotification: Bool = false
                        self.shouldShowAlert(showNotification: showNotification, orderSource: orderSource) { boolValue in
                            if boolValue {
                                accounts = self.updateAccountState(boolValue: boolValue, accounts:accounts)
                                let accountInfo = AccountInfo(accounts: accounts, hasNeverConnected: false)
                                dictionary[orderSource.value] = accountInfo
                            } else {
                                let accountInfo = AccountInfo(accounts: accounts, hasNeverConnected: false)
                                dictionary[orderSource.value] = accountInfo
                            }
                        }
                    }
                    completionHandler(dictionary)
                }
            }
        }
    }
    
    
    // this code to be used for each order source in method handleResponse()
    func handleResponse(listOfAccounts: [GetAccountsResponse], orderSources: [OrderSource]
                        , completionHandler: @escaping ([String: AccountInfo]) -> Void) {
        var dictionary: [String: AccountInfo] = [:]
        let panelistId = LibContext.shared.authProvider.getPanelistID()
        var hasNeverConnected: Bool = false
        
        for orderSource in orderSources {
            let accountForSource = self.getAccountsForOrderSource(listOfAccounts: listOfAccounts, orderSource: orderSource)
            var showNotification: Bool = false
            guard let account = accountForSource else {
                break
            }
            
            hasNeverConnected = account.hasNeverConnected
            
            var accountsInDB = CoreDataManager.shared.fetch(orderSource: orderSource, panelistId: panelistId)
            guard let accountDetails = account.accounts else {
                if !accountsInDB.isEmpty {
                    CoreDataManager.shared.deleteAccountByOrderSource(orderSource: orderSource.rawValue, panelistId: panelistId)
                }
                
                let accountInfo = AccountInfo(accounts: nil, hasNeverConnected: hasNeverConnected)
                dictionary[orderSource.value] = accountInfo
                continue
            }
            if !accountDetails.isEmpty {
                let account = accountDetails[0]
                showNotification = account.showNotification ?? false
            } else {
                CoreDataManager.shared.deleteAccountByOrderSource(orderSource: orderSource.rawValue, panelistId: panelistId)
            }
            accountsInDB = CoreDataManager.shared.fetch(orderSource: orderSource, panelistId: panelistId)
            if accountsInDB.isEmpty && accountDetails.isEmpty {
                let accountInfo = AccountInfo(accounts: accountsInDB, hasNeverConnected: hasNeverConnected)
                dictionary[orderSource.value] = accountInfo
            } else if !accountDetails.isEmpty && accountsInDB.isEmpty {
                let account = accountDetails[0]
                CoreDataManager.shared.addAccount(userId: account.platformId, password: "",
                                                  accountStatus: AccountState.ConnectedButException.rawValue,
                                                  orderSource: orderSource.rawValue, panelistId: panelistId)
                var accountsFromDB = CoreDataManager.shared.fetch(orderSource: orderSource, panelistId: panelistId)
                accountsFromDB.first?.isFirstConnectedAccount = account.firstaccount
                self.shouldShowAlert(showNotification: showNotification, orderSource: orderSource) { boolValue in
                    if boolValue {
                        accountsFromDB = self.updateAccountState(boolValue: boolValue, accounts: accountsFromDB)
                        let accountInfo = AccountInfo(accounts: accountsFromDB, hasNeverConnected: hasNeverConnected)
                        dictionary[orderSource.value] = accountInfo
                    } else {
                        let accountInfo = AccountInfo(accounts: accountsFromDB, hasNeverConnected: hasNeverConnected)
                        dictionary[orderSource.value] = accountInfo
                    }
                }
            } else {
                if let account = accountDetails.first, let accountInDb = accountsInDB.first {
                    if account.platformId.caseInsensitiveCompare(accountInDb.userID) == ComparisonResult.orderedSame {
                        accountsInDB.first?.isFirstConnectedAccount = account.firstaccount
                        
                        //Update connected account state from backend to DB if db has connectionInProgress state
                        if account.status == AccountState.Connected.rawValue
                            && accountInDb.accountState == .ConnectionInProgress {
                            do {
                                try CoreDataManager.shared.updateUserAccount(userId: accountInDb.userID, accountStatus: account.status, panelistId: accountInDb.panelistID, orderSource: accountInDb.source.rawValue)
                                if !accountsInDB.isEmpty {
                                    accountsInDB[0].accountState = .Connected
                                }
                            } catch {
                                print("updateAccountWithExceptionState")
                            }
                        }
                        
                        self.shouldShowAlert(showNotification: showNotification, orderSource: orderSource) { boolValue in
                            if boolValue {
                                accountsInDB = self.updateAccountState(boolValue: boolValue, accounts: accountsInDB)
                                let accountInfo = AccountInfo(accounts: accountsInDB, hasNeverConnected: hasNeverConnected)
                                dictionary[orderSource.value] = accountInfo
                            } else {
                                let accountInfo = AccountInfo(accounts: accountsInDB, hasNeverConnected: hasNeverConnected)
                                dictionary[orderSource.value] = accountInfo
                            }
                        }
                    } else {
                        CoreDataManager.shared.deleteAccountsByPanelistId(panelistId: panelistId)
                        CoreDataManager.shared.addAccount(userId: account.platformId,
                                                          password: "",
                                                          accountStatus:AccountState.ConnectedButException.rawValue,
                                                          orderSource: orderSource.rawValue,
                                                          panelistId: panelistId)
                        var accountsFromDB = CoreDataManager.shared.fetch(orderSource: orderSource, panelistId: panelistId)
                        accountsFromDB.first?.isFirstConnectedAccount = account.firstaccount
                        
                        self.shouldShowAlert(showNotification: showNotification, orderSource: orderSource) { boolValue in
                            if boolValue {
                                accountsFromDB = self.updateAccountState(boolValue: boolValue, accounts:accountsFromDB)
                                let accountInfo = AccountInfo(accounts: accountsFromDB, hasNeverConnected: hasNeverConnected)
                                dictionary[orderSource.value] = accountInfo
                            } else {
                                let accountInfo = AccountInfo(accounts: accountsFromDB, hasNeverConnected: hasNeverConnected)
                                dictionary[orderSource.value] = accountInfo
                            }
                        }
                    }
                } else {
                    if let account = accountDetails.first {
                        accountsInDB.first?.isFirstConnectedAccount = account.firstaccount
                    }
                    
                    self.shouldShowAlert(showNotification: showNotification, orderSource: orderSource) { boolValue in
                        if boolValue {
                            accountsInDB = self.updateAccountState(boolValue: boolValue, accounts:accountsInDB)
                            let accountInfo = AccountInfo(accounts: accountsInDB, hasNeverConnected: hasNeverConnected)
                            dictionary[orderSource.value] = accountInfo
                        } else {
                            let accountInfo = AccountInfo(accounts: accountsInDB, hasNeverConnected: hasNeverConnected)
                            dictionary[orderSource.value] = accountInfo
                        }
                    }
                }
            }
        }
        completionHandler(dictionary)
    }
    
    func getAccountsForOrderSource(listOfAccounts: [GetAccountsResponse], orderSource: OrderSource) -> GetAccountsResponse? {
        var accountResponse: GetAccountsResponse?
        for account in listOfAccounts {
            if account.platformSource.caseInsensitiveCompare(orderSource.value) == .orderedSame {
                accountResponse = account
                break
            }
        }
        return accountResponse
    }
    
    func shouldShowAlert(showNotification: Bool, orderSource: OrderSource, completion: @escaping (Bool) -> Void) {
        //TODO:- Add orderSource
        ConfigManager.shared.getConfigurations(orderSource: orderSource) { (configurations, error) in
            if let configuration = configurations {
                let numberOfCapchaRetry = Utils.getKeyForNumberOfCaptchaRetry(orderSorce: orderSource)
                
                let showNotification = showNotification
                let captchaRetries = configuration.captchaRetries
                let failureCount = UserDefaults.standard.integer(forKey: numberOfCapchaRetry)
                completion(showNotification || failureCount > captchaRetries!)
            } else {
                completion(false)
            }
        }
    }
    
    func updateAccountState(boolValue: Bool, accounts: [UserAccountMO]) -> [UserAccountMO]{
        if boolValue {
            if !accounts.isEmpty {
                accounts[0].accountState = .ConnectedButScrappingFailed
            }
        }
        return accounts
    }
}


