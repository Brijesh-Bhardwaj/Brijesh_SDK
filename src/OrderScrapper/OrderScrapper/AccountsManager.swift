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
        
        _ = AmazonService.getAccounts(orderSource: sourceArray) { response, error in
            DispatchQueue.global().async {
                if let response = response {
                    self.handleResponse(listOfAccounts: response, orderSources: orderSources) { dictionary in
                        completionHandler(dictionary)
                    }
                    return
                }
                
                //If response is not received check for specific error for service unavailable
                if let error = error, let failureType = error.errorEventLog, failureType == .servicesDown {
                    let error = ASLException(error: nil, errorMessage: Strings.ErrorServicesDown, failureType: .servicesDown)
                    LibContext.shared.servicesStatusListener.onServicesFailure(exception: error)
                    return
                }
                
                //In case API fails to get the accounts, check in local DB and return
                let panelistId = LibContext.shared.authProvider.getPanelistID()
                var counter = orderSources.count
                for orderSource in orderSources {
                    let account = CoreDataManager.shared.fetch(orderSource: orderSource, panelistId: panelistId)
                    var accounts = AccountConverter.getAccountsFromDBAccounts(dbAccounts: account)
                    let showNotification: Bool = false
                    self.shouldShowAlert(showNotification: showNotification, orderSource: orderSource) { boolValue in
                        if boolValue {
                            accounts = self.updateAccountState(accounts:accounts)
                            let accountInfo = AccountInfo(accounts: accounts, hasNeverConnected: false)
                            dictionary[orderSource.value] = accountInfo
                        } else {
                            let accountInfo = AccountInfo(accounts: accounts, hasNeverConnected: false)
                            dictionary[orderSource.value] = accountInfo
                        }
                        counter -= 1
                        if counter == 0 {
                            completionHandler(dictionary)
                        }
                    }
                }
            }
        }
    }
    
    
    // this code to be used for each order source in method handleResponse()
    func handleResponse(listOfAccounts: [GetAccountsResponse], orderSources: [OrderSource]
                        , completionHandler: @escaping ([String: AccountInfo]) -> Void) {
        var dictionary: [String: AccountInfo] = [:]
        var counter = orderSources.count
        
        for orderSource in orderSources {
            parseResponseForSource(orderSource: orderSource, listOfAccounts: listOfAccounts) { result in
                if !result.isEmpty {
                    dictionary.merge(result, uniquingKeysWith: { ( _, last) in last })
                }
                
               counter -= 1
                if counter == 0 {
                    completionHandler(dictionary)
                }
            }
        }
    }
    
    private func parseResponseForSource(orderSource: OrderSource, listOfAccounts: [GetAccountsResponse], completionHandler: @escaping ([String: AccountInfo]) -> Void) {
        var dictionary: [String: AccountInfo] = [:]
        let panelistId = LibContext.shared.authProvider.getPanelistID()
        
        let accountForSource = self.getAccountsForOrderSource(listOfAccounts: listOfAccounts, orderSource: orderSource)
        var showNotification: Bool = false
        guard let account = accountForSource else {
            completionHandler(dictionary)
            return
        }
        
        let hasNeverConnected = account.hasNeverConnected
        
        guard let accountDetails = account.accounts, !accountDetails.isEmpty else {
            CoreDataManager.shared.deleteAccountByOrderSource(orderSource: orderSource.rawValue, panelistId: panelistId)
            
            let accountInfo = AccountInfo(accounts: nil, hasNeverConnected: hasNeverConnected)
            dictionary[orderSource.value] = accountInfo
            
            completionHandler(dictionary)
            return
        }
        
        let accountDetail = accountDetails.first
        showNotification = accountDetail?.showNotification ?? false
        
        let accounts = CoreDataManager.shared.fetch(orderSource: orderSource, panelistId: panelistId)
        var accountsInDB = AccountConverter.getAccountsFromDBAccounts(dbAccounts: accounts)
        
        
        if accountsInDB.isEmpty {
            let account = accountDetails[0]
            CoreDataManager.shared.addAccount(userId: account.platformId, password: "",
                                              accountStatus: AccountState.ConnectedButException.rawValue,
                                              orderSource: orderSource.rawValue, panelistId: panelistId)
            let accounts = CoreDataManager.shared.fetch(orderSource: orderSource, panelistId: panelistId)
            var accountsFromDB = AccountConverter.getAccountsFromDBAccounts(dbAccounts: accounts)
            accountsFromDB.first?.isFirstConnectedAccount = account.firstaccount
            self.shouldShowAlert(showNotification: showNotification, orderSource: orderSource) { showAlert in
                if showAlert {
                    accountsFromDB = self.updateAccountState(accounts: accountsFromDB)
                    let accountInfo = AccountInfo(accounts: accountsFromDB, hasNeverConnected: hasNeverConnected)
                    dictionary[orderSource.value] = accountInfo
                } else {
                    let accountInfo = AccountInfo(accounts: accountsFromDB, hasNeverConnected: hasNeverConnected)
                    dictionary[orderSource.value] = accountInfo
                }
                completionHandler(dictionary)
                return
            }
            self.logPushEvent( orderSource: orderSource.value,message: AppConstants.user_account_not_exist)

        }
        
        if let account = accountDetails.first, let accountInDb = accountsInDB.first {
            if account.platformId.caseInsensitiveCompare(accountInDb.userID) == ComparisonResult.orderedSame {
                accountInDb.isFirstConnectedAccount = account.firstaccount
                
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
                
                self.shouldShowAlert(showNotification: showNotification, orderSource: orderSource) { showAlert in
                    if showAlert {
                        accountsInDB = self.updateAccountState(accounts: accountsInDB)
                        let accountInfo = AccountInfo(accounts: accountsInDB, hasNeverConnected: hasNeverConnected)
                        dictionary[orderSource.value] = accountInfo
                    } else {
                        let accountInfo = AccountInfo(accounts: accountsInDB, hasNeverConnected: hasNeverConnected)
                        dictionary[orderSource.value] = accountInfo
                    }
                    completionHandler(dictionary)
                    return
                }
                
            } else {
                CoreDataManager.shared.deleteAccountsByPanelistId(panelistId: panelistId)
                CoreDataManager.shared.addAccount(userId: account.platformId,
                                                  password: "",
                                                  accountStatus:AccountState.ConnectedButException.rawValue,
                                                  orderSource: orderSource.rawValue,
                                                  panelistId: panelistId)
                let accounts = CoreDataManager.shared.fetch(orderSource: orderSource, panelistId: panelistId)
                var accountsFromDB = AccountConverter.getAccountsFromDBAccounts(dbAccounts: accounts)
                accountsFromDB.first?.isFirstConnectedAccount = account.firstaccount
                self.shouldShowAlert(showNotification: showNotification, orderSource: orderSource) { showAlert in
                    if showAlert {
                        accountsFromDB = self.updateAccountState(accounts: accountsFromDB)
                        let accountInfo = AccountInfo(accounts: accountsFromDB, hasNeverConnected: hasNeverConnected)
                        dictionary[orderSource.value] = accountInfo
                    } else {
                        let accountInfo = AccountInfo(accounts: accountsFromDB, hasNeverConnected: hasNeverConnected)
                        dictionary[orderSource.value] = accountInfo
                    }
                    completionHandler(dictionary)
                    return
                }
                self.logPushEvent( orderSource: orderSource.value,message: AppConstants.user_account_not_exist)

            }
        } else {
                if let account = accountDetails.first, let accountInDb = accountsInDB.first {
                    if account.platformId.caseInsensitiveCompare(accountInDb.userID) == ComparisonResult.orderedSame {
                        accountInDb.isFirstConnectedAccount = account.firstaccount
                        
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
                                accountsInDB = self.updateAccountState(accounts: accountsInDB)
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
                        var accounts = CoreDataManager.shared.fetch(orderSource: orderSource, panelistId: panelistId)
                        var accountsFromDB = AccountConverter.getAccountsFromDBAccounts(dbAccounts: accounts)
                        accountsFromDB.first?.isFirstConnectedAccount = account.firstaccount
                        
                        self.shouldShowAlert(showNotification: showNotification, orderSource: orderSource) { boolValue in
                            if boolValue {
                                accountsFromDB = self.updateAccountState(accounts:accountsFromDB)
                                let accountInfo = AccountInfo(accounts: accountsFromDB, hasNeverConnected: hasNeverConnected)
                                dictionary[orderSource.value] = accountInfo
                            } else {
                                let accountInfo = AccountInfo(accounts: accountsFromDB, hasNeverConnected: hasNeverConnected)
                                dictionary[orderSource.value] = accountInfo
                            }
                        }
                self.logPushEvent( orderSource: orderSource.value,message: AppConstants.user_account_not_exist)

                    }
                } else {
                    let accountInfo = AccountInfo(accounts: accountsInDB, hasNeverConnected: hasNeverConnected)
                    dictionary[orderSource.value] = accountInfo
                }
            
            
                completionHandler(dictionary)
                return
            }

        

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
        ConfigManager.shared.getConfigurations(orderSource: orderSource) { (configurations, error) in
            if let configuration = configurations {
                let numberOfCapchaRetry = Utils.getKeyForNumberOfCaptchaRetry(orderSorce: orderSource)
                let captchaRetries = configuration.captchaRetries ?? AppConstants.captchaRetryCount
                let failureCount = UserDefaults.standard.integer(forKey: numberOfCapchaRetry)
                completion(showNotification || failureCount > captchaRetries)
            } else {
                completion(false)
            }
        }
    }
    
    func updateAccountState(accounts: [UserAccount]) -> [UserAccount]{
        if !accounts.isEmpty {
            accounts[0].accountState = .ConnectedButScrappingFailed
        }
        return accounts
    }
    private func logPushEvent( orderSource:String ,message:String){

        let eventLogs = EventLogs(panelistId: LibContext.shared.authProvider.getPanelistID(), platformId:nil, section: SectionType.orderUpload.rawValue, type: FailureTypes.none.rawValue, status: EventState.Info.rawValue, message: message, fromDate: nil, toDate: nil, scrapingType: ScrappingType.html.rawValue, scrapingContext: ScrapingMode.Foreground.rawValue,url:nil)
        _ = AmazonService.logEvents(eventLogs: eventLogs, orderSource: orderSource ) { response, error in}
    }
}


