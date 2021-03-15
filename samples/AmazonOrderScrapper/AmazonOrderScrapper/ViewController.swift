//
//  ViewController.swift
//  AmazonOrderScrapper
//
import UIKit
import OrderScrapper

class ViewController: UIViewController {
    private var orderScrapperLib: OrderScrapper!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        self.orderScrapperLib = OrderScrapperFactory.createScrapper(orderSource: .Amazon, authProvider: self, viewPresenter: self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.orderScrapperLib.connectAccount(accountConnectionListener: self)
    }
}

extension ViewController: ViewPresenter {
    func presentView(view: UIViewController) {
        self.navigationController?.pushViewController(view, animated: true)
    }

    func dismissView() {
        self.dismiss(animated: true, completion: nil)
    }
}

extension ViewController: AuthProvider {
    func getAuthToken() -> String {
        return ""
    }
}

extension ViewController: AccountConnectedListener {
    func onAccountConnected(account: Account) {
        
    }
    
    func onAccountConnectionFailed(account: Account) {
        
    }
}
