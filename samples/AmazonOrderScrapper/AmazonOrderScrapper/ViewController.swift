//
//  ViewController.swift
//  AmazonOrderScrapper
//
import UIKit

class ViewController: UIViewController {
    static let PanelistID = "PanelistID"
    static let AuthToken = "AuthToken"
    
    @IBOutlet weak var emailIdLabel: UITextField!
    @IBOutlet weak var passwordLabel: UITextField!
    @IBOutlet weak var progressView: UIActivityIndicatorView!
    
    var panelistId: String = ""
    var gToken: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let userId = UserDefaults.standard.string(forKey: ViewController.PanelistID) ?? ""
        self.emailIdLabel.text = userId
        self.emailIdLabel.delegate = self
        self.passwordLabel.delegate = self
    }
    
    @IBAction func login(_ sender: Any) {
        if !emailIdLabel.hasText || !passwordLabel.hasText {
            return
        }
        if !ValidationUtil.isValidEmail(email: self.emailIdLabel.text!) {
            return
        }
        let emailId = self.emailIdLabel.text!
        self.progressView.isHidden = false
        APIService.loginAPI(userName: self.emailIdLabel.text!, password: self.passwordLabel.text!) { response, error in
            if let response = response {
                self.panelistId = response.panelistId!
                let token = response.token
                self.gToken = Util.getToken(username: self.panelistId, password: token!, constant: AppConstant.token)
                UserDefaults.standard.setValue(emailId, forKey: ViewController.PanelistID)
                
                DispatchQueue.main.async {
                    let mainStoryboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
                    let vc = mainStoryboard.instantiateViewController(withIdentifier: "AccountsVC") as! AccountsViewController
                    vc.panelistID = self.panelistId
                    vc.authToken = self.gToken
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            }
            DispatchQueue.main.async {
                self.progressView.isHidden = true
            }
        }
    }
}

extension ViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.isEqual(self.emailIdLabel) {
            self.passwordLabel.becomeFirstResponder()
        } else {
            textField.endEditing(true)
        }
        return false
    }
}
