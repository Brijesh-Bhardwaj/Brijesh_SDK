//
//  AccountsViewController.swift
//  AmazonOrderScrapper
//

import UIKit
import OrderScrapper
import Firebase

enum ButtonAction: Int {
    case connectAccount, fetchReceipts
}

class AccountsViewController: UIViewController {
    var panelistID: String!
    var authToken: String!
    
    @IBOutlet weak var parentView: Gradient!
    @IBOutlet weak var noAccountsLabel: UILabel!
    @IBOutlet weak var accountIDLabel: UILabel!
    @IBOutlet weak var disconnectButton: UIButton!
    @IBOutlet weak var actionButton: UIButton!
    @IBOutlet weak var tickImage: UIImageView!
    
    private var currentAccount: Account!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            let configValue = OrderExtractorConfig()
            configValue.baseURL = Util.getBaseUrl()
            configValue.appName = "ReceiptStraw-Dev"
            configValue.appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String)!
            try OrdersExtractor.initialize(authProvider: self, viewPresenter: self, analyticsProvider: self, orderExtractionConfig: configValue)
        } catch let error {
            debugPrint(error.localizedDescription)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        
        self.loadAccounts()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        parentView.clipsToBounds = true
        parentView.layer.cornerRadius = 40
        parentView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
    }
    
    private func loadAccounts() {
        do {
            try OrdersExtractor.getAccounts(orderSource: nil) { accounts, hasNeverConnected in
                let connectedAccounts = accounts.filter() { $0.accountState != .ConnectedAndDisconnected }
                if connectedAccounts.isEmpty {
                    self.showViewForNoAccount()
                } else {
                    self.showViewFor(account: connectedAccounts[0])
                }
            }
        } catch {
            let message = "An error occurred while loading accounts"
            showAlert(title: "Alert", message: message, completionHandler: nil)
        }
    }
    
    //Ideally it could be a listview, take it up for later
    private func showViewFor(account: Account) {
        self.currentAccount = account
        let userID = account.userID
        
        self.noAccountsLabel.isHidden = true
        hideAccountView(hide: false)
        
        self.accountIDLabel.text = userID
        self.actionButton.setTitle("Fetch Receipts", for: .normal)
        self.actionButton.tag = ButtonAction.fetchReceipts.rawValue
        
        if account.accountState == .ConnectedButException {
            self.disconnectButton.setTitle("Reconnect", for: .normal)
            self.actionButton.isHidden = true
        } else {
            self.disconnectButton.setTitle("Disconnect", for: .normal)
            self.actionButton.isHidden = false
        }
    }
    
    private func showViewForNoAccount() {
        hideAccountView(hide: true)
        self.noAccountsLabel.isHidden = false
        self.actionButton.setTitle("Connect Account", for: .normal)
        self.actionButton.tag = ButtonAction.connectAccount.rawValue
    }
    
    private func hideAccountView(hide: Bool) {
        self.accountIDLabel.isHidden = hide
        self.disconnectButton.isHidden = hide
        self.tickImage.isHidden = hide
    }
    
    @IBAction func disconnectAccount(_ sender: Any) {
        if let title = self.disconnectButton.title(for: .normal) {
            if title.elementsEqual("Reconnect") {
                self.currentAccount.connect(orderExtractionListener: self)
                return
            }
        }
        self.currentAccount.disconnect(accountDisconnectedListener: self)
    }
    
    @IBAction func onActionButtonClick(_ sender: Any) {
        if self.actionButton.tag == ButtonAction.connectAccount.rawValue {
            do {
                try OrdersExtractor.registerAccount(orderSource: .Amazon, orderExtractionListner: self)
            } catch {
                let message = "An error occured while displaying register screen"
                showAlert(title: "Alert", message: message, completionHandler: nil)
            }
        } else {
            self.currentAccount.fetchOrders(orderExtractionListener: self)
        }
    }
}

extension AccountsViewController: AccountDisconnectedListener {
    func onAccountDisconnected(account: Account) {
        self.showAlert(title: "Alert", message: "Account disconnected successfully!") { (action) in
            self.loadAccounts()
        }
    }
    func onAccountDisconnectionFailed(account: Account, error: ASLException) {
        self.loadAccounts()
    }
}

extension AccountsViewController: ViewPresenter {
    func presentView(view: UIViewController) {
        self.present(view, animated: true, completion: nil)
    }
    
    func dismissView() {
        self.dismiss(animated: true, completion: nil)
    }
}

extension AccountsViewController: AuthProvider {
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

extension AccountsViewController: OrderExtractionListener {
    func onOrderExtractionSuccess(successType: OrderFetchSuccessType, account: Account) {
        if successType == .fetchSkipped {
            showAlert(title: "Alert", message: "Receipts scrapped already.", completionHandler: nil)
        }
        
        if account.isFirstConnectedAccount {
            showAlert(title: "Alert", message: "You've received 1000 points for connecting your first Amazon account!", completionHandler: nil)
        }
        
        showAlert(title: "Alert", message: "Extraction process completed", completionHandler: nil)
        loadAccounts()
    }
    
    func onOrderExtractionFailure(error: ASLException, account: Account) {
        showAlert(title: "Alert", message: error.errorMessage, completionHandler: nil)
        loadAccounts()
    }
}

extension AccountsViewController: AnalyticsProvider {
    func logEvent(eventType: String, eventAttributes: Dictionary<String, String>) {
        Analytics.logEvent(eventType, parameters: eventAttributes)
    }
    
    func setUserProperty(userProperty: String, userPropertyValue: String) {
        Analytics.setUserProperty(userPropertyValue, forName: userProperty)
    }
}
extension UIViewController {
    func showAlert(title: String, message: String, completionHandler: ((UIAlertAction) -> Void)?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let ok = UIAlertAction(title: "OK", style: .default, handler: { (action) -> Void in
            if completionHandler != nil {
                completionHandler!(action)
            }
        })
        
        //Add OK button to a dialog message
        alert.addAction(ok)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            self.present(alert, animated: true, completion: nil)
        }
    }
}

@IBDesignable
public class Gradient: UIView {
    @IBInspectable var startColor:   UIColor = .black { didSet { updateColors() }}
    @IBInspectable var endColor:     UIColor = .white { didSet { updateColors() }}
    @IBInspectable var startLocation: Double =   0.05 { didSet { updateLocations() }}
    @IBInspectable var endLocation:   Double =   0.95 { didSet { updateLocations() }}
    @IBInspectable var horizontalMode:  Bool =  false { didSet { updatePoints() }}
    @IBInspectable var diagonalMode:    Bool =  false { didSet { updatePoints() }}
    
    override public class var layerClass: AnyClass { CAGradientLayer.self }
    
    var gradientLayer: CAGradientLayer { layer as! CAGradientLayer }
    
    func updatePoints() {
        if horizontalMode {
            gradientLayer.startPoint = diagonalMode ? .init(x: 1, y: 0) : .init(x: 0, y: 0.5)
            gradientLayer.endPoint   = diagonalMode ? .init(x: 0, y: 1) : .init(x: 1, y: 0.5)
        } else {
            gradientLayer.startPoint = diagonalMode ? .init(x: 0, y: 0) : .init(x: 0.5, y: 0)
            gradientLayer.endPoint   = diagonalMode ? .init(x: 1, y: 1) : .init(x: 0.5, y: 1)
        }
    }
    func updateLocations() {
        gradientLayer.locations = [startLocation as NSNumber, endLocation as NSNumber]
    }
    func updateColors() {
        gradientLayer.colors = [startColor.cgColor, endColor.cgColor]
    }
    override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updatePoints()
        updateLocations()
        updateColors()
    }
}
