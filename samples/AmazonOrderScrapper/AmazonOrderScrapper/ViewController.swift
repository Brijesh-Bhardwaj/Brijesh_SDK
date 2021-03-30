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
            DispatchQueue.main.async {
                self.progressView.isHidden = true
                if let response = response {
                    if let panelistId = response.panelistId, let token = response.token {
                        if panelistId.isEmpty || token.isEmpty {
                            self.showAuthErrorAlert()
                            return
                        }
                        self.panelistId = panelistId

                        self.gToken = Util.getToken(username: self.panelistId, password: token, constant: AppConstant.token)
                        UserDefaults.standard.setValue(emailId, forKey: ViewController.PanelistID)
                        
                        let mainStoryboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
                        let vc = mainStoryboard.instantiateViewController(withIdentifier: "AccountsVC") as! AccountsViewController
                        vc.panelistID = self.panelistId
                        vc.authToken = self.gToken
                        self.navigationController?.pushViewController(vc, animated: true)
                    } else {
                        self.showAuthErrorAlert()
                    }
                } else {
                    self.showAuthErrorAlert()
                }
            }
        }
    }
    
    func showAuthErrorAlert() {
        self.showAlert(title: "Alert", message: "Failed to login. Please check your credentials and try again", completionHandler: nil)
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
