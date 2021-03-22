//
//  ViewController.swift
//  AmazonOrderScrapper
//
import UIKit
import OrderScrapper

class ViewController: UIViewController {
    private var orderScrapperLib: OrderScrapper!
    private var presentedVC: UIViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        self.orderScrapperLib = OrderScrapperFactory.createScrapper(orderSource: .Amazon, authProvider: self, viewPresenter: self)
    }
    
    @IBAction func connectAccount(_ sender: Any) {
        self.orderScrapperLib.connectAccount(accountConnectionListener: self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
    }
}

extension ViewController: ViewPresenter {
    func presentView(view: UIViewController) {
        self.presentedVC = view
        self.navigationController?.pushViewController(view, animated: true)
    }

    func dismissView() {
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
}

extension ViewController: AuthProvider {
    func getAuthToken() -> String {
        return "AwFVMUkpWg2l9QEFbdlgt+Pg7EiuCqqbkjvcxc0qP1Mrza5nyDEjmM87fmmmVPEuvHW/RRDUIYcAq8ZdXxnnWpSGx0C9v3ptEjhZ2pcr/AjJpWmWUwzSKsB5CTYUuk10UqaDJkUR9P7vxBGZXoTmp1sMhvAsOp34Je7+xaGy/JuDsg=="
    }
    
    func getPanelistID() -> String {
        return "420007381"
    }
}

extension ViewController: AccountConnectedListener {
    func onAccountConnected(account: Account) {
        
    }
    
    func onAccountConnectionFailed(account: Account) {
        
    }
}
