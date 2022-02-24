//  AccountListViewController.swift
//  AmazonOrderScrapper

import Foundation
import OrderScrapper
import UIKit
import Firebase

class AccountListViewController: UIViewController, UITableViewDataSource
                                 , UITableViewDelegate, ConnectAccountDelegate, AccountActionDelegate, UNUserNotificationCenterDelegate {
    @IBOutlet weak var tableView: UITableView!
    private let Amazon = "Amazon"
    private let Instacart = "Instacart"
    private let Kroger = "Kroger"
    private let Walmart = "Walmart"
    private let userNotificationCenter = UNUserNotificationCenter.current()
    var panelistID: String!
    var authToken: String!
    var accountData: [String : [Account]] = [:]
    var accounts:[Account] = []
    var currentAccount: Account!
    
    private lazy var foregroundOrderExtractionListner: ForegroundOrderExtractionListener = {
        return ForegroundOrderExtractionListener(accountViewController: self)
    }()
    private lazy var backgroundOrderExtractionListner: BackgroundOrderExtractionListener = {
        return BackgroundOrderExtractionListener(accountViewController: self)
    }()
    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            self.userNotificationCenter.delegate = self
            let configValue = OrderExtractorConfig()
            self.requestNotificationAuthorization()
            configValue.baseURL = Util.getBaseUrl()
            configValue.appName = "ReceiptStraw-Dev"
            configValue.appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)!
            configValue.deviceId = Util.getDeviceIdentifier()
            try OrdersExtractor.initialize(authProvider: self, viewPresenter: self, analyticsProvider: self, orderExtractionConfig: configValue, servicesStatusListener: self)
        } catch let error {
            debugPrint(error.localizedDescription)
        }
        
        accountData[Amazon] = accounts
        accountData[Instacart] = accounts
        accountData[Kroger] = accounts
        accountData[Walmart] = accounts
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 170
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        self.loadAccounts()
        self.isUserEligible()
    }
    
    func connectAccount(section: Int) {
        //Section value 0 for Amazon, 1 for Instacart, 2 for Kroger while connecting new account
        if section == 0 {
            do {
                try OrdersExtractor.registerAccount(orderSource: .Amazon, orderExtractionListner: self.foregroundOrderExtractionListner)
            } catch {
                let message = "An error occured while displaying register screen"
                showAlert(title: "Alert", message: message, completionHandler: nil)
            }
        } else if section == 1 {
            do {
                try OrdersExtractor.registerAccount(orderSource: .Instacart, orderExtractionListner: self.foregroundOrderExtractionListner)
            } catch {
                let message = "An error occured while displaying register screen"
                showAlert(title: "Alert", message: message, completionHandler: nil)
            }
        } else if section == 2 {
            do {
                try OrdersExtractor.registerAccount(orderSource: .Kroger, orderExtractionListner: self.foregroundOrderExtractionListner)
            } catch {
                let message = "An error occured while displaying register screen"
                showAlert(title: "Alert", message: message, completionHandler: nil)
            }
        } else if section == 3 {
            do {
                try OrdersExtractor.registerAccount(orderSource: .Walmart, orderExtractionListner: self.foregroundOrderExtractionListner)
            } catch {
                let message = "An error occured while displaying register screen"
                showAlert(title: "Alert", message: message, completionHandler: nil)
            }
        }
    }
    
    func requestNotificationAuthorization() {
        let authOptions = UNAuthorizationOptions.init(arrayLiteral: .alert, .badge, .sound)
        
        self.userNotificationCenter.requestAuthorization(options: authOptions) { (success, error) in
            if let error = error {
                print("Error: ", error)
            }
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == UNNotificationDismissActionIdentifier {
            // The user dismissed the notification without taking action
            //            sendNotification()
            print("dismmised the notification")
        } else if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            // The user launched the app
            print("Tapped the notification")
            self.currentAccount.fetchOrders(orderExtractionListener: self.backgroundOrderExtractionListner, source: .notification)
        }
        completionHandler()
    }
    
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .badge, .sound])
    }
    
    func sendNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Authorization needed"
        content.subtitle = "Coinout"
        content.body = "You are missing some extra credit points in application"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1.0, repeats: false)
        let request = UNNotificationRequest(identifier: "ai.blackstraw.receiptstraw.dev", content: content, trigger: trigger)
        
        let center = UNUserNotificationCenter.current()
        center.add(request) { (error : Error?) in
            if let theError = error {
                print(theError.localizedDescription)
            }
        }
    }
    
    func disconnectAccount(account: Account, action: String) {
        if action.elementsEqual("Reconnect") {
            account.connect(orderExtractionListener: self.foregroundOrderExtractionListner)
            return
        }
        account.disconnect(accountDisconnectedListener: self)
    }
    
    func backgroundScrapping(account: Account) {
        if account.accountState == .Connected || account.accountState == .ConnectionInProgress {
            account.fetchOrders(orderExtractionListener: self.backgroundOrderExtractionListner, source: .general)
        }
    }
    
     func isUserEligible() {
         do {
             try OrdersExtractor.isUserEligibleForIncentive() { response in
                 if response {
                     print("!!!! isUserEligible true ",response)
                 } else {
                     print("!!!! isUserEligible false ",response)
                 }
             }
         } catch {
             
         }
     }
    
    func loadAccounts() {
        do {
            try OrdersExtractor.getAccounts(orderSource: .Amazon,.Instacart,.Kroger,.Walmart) { response in
                for account in response {
                    let accountSource = account.key
                    let connectedAccount = account.value.account
                    if connectedAccount != nil && connectedAccount!.count > 0 {
                        let connectedAccounts = connectedAccount?.filter() { $0.accountState != .ConnectedAndDisconnected }
                        if let accountConnected = connectedAccounts , accountConnected.count > 0 {
                            self.accountData[accountSource] = connectedAccounts
                        } else {
                            self.accountData[accountSource] = []
                        }
                    } else {
                        if self.accountData[accountSource] != nil {
                            self.accountData[accountSource] = []
                        }
                    }
                }
                self.tableView.reloadData()
            }
        } catch {
            let message = "An error occurred while loading accounts"
            showAlert(title: "Alert", message: message, completionHandler: nil)
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var numberOfRows: Int
        switch section {
        case 0:
            numberOfRows = accountData[Amazon]?.count ?? 1
        case 1:
            numberOfRows = accountData[Instacart]?.count ?? 1
        case 2:
            numberOfRows = accountData[Kroger]?.count ?? 1
        case 3:
            numberOfRows = accountData[Walmart]?.count ?? 1
        default:
            numberOfRows = 1
        }
        if numberOfRows == 0 {
            numberOfRows = 1
        }
        return numberOfRows
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var numberOfAccount = 0
        var account: Account?
        switch indexPath.section {
        case 0:
            numberOfAccount = accountData[Amazon]?.count ?? 0
            if numberOfAccount > 0 {
                let rowNumber = indexPath.row
                if let accounts = accountData[Amazon] {
                    account = accounts[rowNumber]
                }
            }
        case 1:
            numberOfAccount = accountData[Instacart]?.count ?? 0
            if numberOfAccount > 0 {
                let rowNumber = indexPath.row
                if let accounts = accountData[Instacart] {
                    account = accounts[rowNumber]
                }
            }
        case 2:
            numberOfAccount = accountData[Kroger]?.count ?? 0
            if numberOfAccount > 0 {
                let rowNumber = indexPath.row
                if let accounts = accountData[Kroger] {
                    account = accounts[rowNumber]
                }
            }
        case 3:
            numberOfAccount = accountData[Walmart]?.count ?? 0
            if numberOfAccount > 0 {
                let rowNumber = indexPath.row
                if let accounts = accountData[Walmart] {
                    account = accounts[rowNumber]
                }
            }
        default:
            print("Do nothing")
            let cell = UITableViewCell(style: .default, reuseIdentifier: "cell");
            return cell
        }
        
        if numberOfAccount == 0 {
            let connectAccountCell = tableView.dequeueReusableCell(withIdentifier: "connectAccountCell") as! ConnectAccountCell
            connectAccountCell.delegate = self
            connectAccountCell.connectAccount.tag = indexPath.section
            return connectAccountCell
        } else {
            let accountActionCell = tableView.dequeueReusableCell(withIdentifier: "accountActionCell") as! AccountActionCell
            accountActionCell.delegate = self
            accountActionCell.setAccountDetails(account: account!)
            return accountActionCell
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let cell = tableView.dequeueReusableCell(withIdentifier: "headerCell") as! HeaderCell
        switch section {
        case 0:
            cell.headerLabel.text = Amazon
        case 1:
            cell.headerLabel.text = Instacart
        case 2:
            cell.headerLabel.text = Kroger
        case 3:
            cell.headerLabel.text = Walmart
        default:
            print("Do nothing")
        }
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return accountData.count
    }
}

extension AccountListViewController: AccountDisconnectedListener {
    func onAccountDisconnected(account: Account) {
        self.showAlert(title: "Alert", message: "Account disconnected successfully!") { (action) in
            self.loadAccounts()
        }
    }
    func onAccountDisconnectionFailed(account: Account, error: ASLException) {
        self.loadAccounts()
    }
}

extension AccountListViewController: ViewPresenter {
    func presentView(view: UIViewController) {
        self.present(view, animated: true, completion: nil)
    }
    
    func dismissView() {
        self.dismiss(animated: true, completion: nil)
    }
}

extension AccountListViewController: AuthProvider {
    func refreshAuthToken(completionHandler: (String?, Error?) -> Void) {
        //This is for simulation of auth token renewal, actual logic would differ
        completionHandler(authToken, nil)
    }
    
    func getAuthToken() -> String {
        return self.authToken
    }
    
    func getPanelistID() -> String {
        return self.panelistID
    }
}

extension AccountListViewController: AnalyticsProvider {
    func logEvent(eventType: String, eventAttributes: Dictionary<String, String>) {
        Analytics.logEvent(eventType, parameters: eventAttributes)
    }
    
    func setUserProperty(userProperty: String, userPropertyValue: String) {
        Analytics.setUserProperty(userPropertyValue, forName: userProperty)
    }
}

extension AccountListViewController: ServicesStatusListener {
    func onServicesFailure(exception: ASLException) {
        print("##### onServicesFailure")
    }
}
class ForegroundOrderExtractionListener: OrderExtractionListener {
    
    private weak var accountListViewController: AccountListViewController?
    
    init(accountViewController: AccountListViewController) {
        self.accountListViewController = accountViewController
    }
    
    func onOrderExtractionSuccess(successType: OrderFetchSuccessType, account: Account) {
        if successType == .fetchSkipped {
            accountListViewController?.showAlert(title: "Alert", message: "Receipts scrapped already.", completionHandler: nil)
        }
        
        if account.isFirstConnectedAccount {
            if account.source == .Amazon {
                accountListViewController?.showAlert(title: "Alert", message: "You've received 1000 points for connecting your first Amazon account!", completionHandler: nil)
            }else if account.source == .Instacart{
                accountListViewController?.showAlert(title: "Alert", message: "You've received 1000 points for connecting your first Instacart account!", completionHandler: nil)
            }else if account.source == .Kroger{
                accountListViewController?.showAlert(title: "Alert", message: "You've received 1000 points for connecting your first Kroger account!", completionHandler: nil)
            }else if account.source == .Walmart{
                accountListViewController?.showAlert(title: "Alert", message: "You've received 1000 points for connecting your first Walmart account!", completionHandler: nil)
            }
        }
    }
    
    func onOrderExtractionFailure(error: ASLException, account: Account) {
        accountListViewController?.showAlert(title: "Alert", message: error.errorMessage, completionHandler: nil)
        accountListViewController?.loadAccounts()
    }
    
    func showNotification(account: Account) {
        //
    }
}

class BackgroundOrderExtractionListener: OrderExtractionListener {
    
    private weak var accountListViewController: AccountListViewController?
    
    init(accountViewController: AccountListViewController) {
        self.accountListViewController = accountViewController
    }
    
    func onOrderExtractionSuccess(successType: OrderFetchSuccessType, account: Account) {

        if successType == .fetchSkipped {
            let message = "\(account.source): \("Background extraction skipped")"
            accountListViewController?.showAlert(title: "Alert", message: message, completionHandler: nil)
        } else {
            let message = "\(account.source): \("Background extraction process completed")"
            accountListViewController?.showAlert(title: "Alert", message: message, completionHandler: nil)
            accountListViewController?.loadAccounts()
        }
    }
    
    func onOrderExtractionFailure(error: ASLException, account: Account) {
        accountListViewController?.showAlert(title: "Alert", message: error.errorMessage, completionHandler: nil)
        accountListViewController?.loadAccounts()
    }
    
    func showNotification(account: Account) {
    //TODO
        self.accountListViewController?.currentAccount = account
        self.accountListViewController?.sendNotification()
    }
}
