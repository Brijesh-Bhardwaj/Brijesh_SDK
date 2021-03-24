//
//  ViewController.swift
//  AmazonOrderScrapper
//
import UIKit

class ViewController: UIViewController {
    static let PanelistID = "PanelistID"
    static let AuthToken = "AuthToken"
    
    @IBOutlet weak var panelistID: UITextField!
    @IBOutlet weak var authToken: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let panelistID = UserDefaults.standard.string(forKey: ViewController.PanelistID) ?? "420007381"
        let authToken = UserDefaults.standard.string(forKey: ViewController.AuthToken) ?? "AwFVMUkpWg2l9QEFbdlgt+Pg7EiuCqqbkjvcxc0qP1Mrza5nyDEjmM87fmmmVPEuvHW/RRDUIYcAq8ZdXxnnWpSGx0C9v3ptEjhZ2pcr/AjJpWmWUwzSKsB5CTYUuk10UqaDJkUR9P7vxBGZXoTmp1sMhvAsOp34Je7+xaGy/JuDsg=="
        
        self.panelistID.text = panelistID
        self.authToken.text = authToken
    }
    
    @IBAction func login(_ sender: Any) {
        if !panelistID.hasText || !authToken.hasText {
            return
        }
        
        UserDefaults.standard.setValue(panelistID.text, forKey: ViewController.PanelistID)
        UserDefaults.standard.setValue(authToken.text, forKey: ViewController.AuthToken)
        
        let mainStoryboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = mainStoryboard.instantiateViewController(withIdentifier: "AccountsVC") as! AccountsViewController
        vc.panelistID = panelistID.text
        vc.authToken = authToken.text
        
        self.navigationController?.pushViewController(vc, animated: true)
    }
}
