//
//  ViewController.swift
//  AmazonOrderScrapper
//
import UIKit

class ViewController: UIViewController {
    static let UserEmail = "UserEmail"
    
    @IBOutlet weak var emailIdLabel: UITextField!
    @IBOutlet weak var passwordLabel: UITextField!
    @IBOutlet weak var progressView: UIActivityIndicatorView!
    
    @IBOutlet weak var invalidEmailLabel: UILabel!
    @IBOutlet weak var invalidPasswordLabel: UILabel!
    
    var panelistId: String = ""
    var gToken: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let userId = UserDefaults.standard.string(forKey: ViewController.UserEmail) ?? ""
        self.emailIdLabel.text = userId
        self.emailIdLabel.delegate = self
        self.passwordLabel.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            if self.view.frame.origin.y == 0 {
                let frame = self.progressView.frame
                let endPoint = frame.origin.y + frame.height
                if endPoint > keyboardSize.origin.y {
                    self.view.frame.origin.y -= (endPoint - keyboardSize.origin.y)
                }
            }
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        if self.view.frame.origin.y != 0 {
            self.view.frame.origin.y = 0
        }
    }
    
    @IBAction func login(_ sender: Any) {
        self.invalidEmailLabel.isHidden = true
        self.invalidPasswordLabel.isHidden = true
        
        if !emailIdLabel.hasText || !ValidationUtil.isValidEmail(email: self.emailIdLabel.text!) {
            self.invalidEmailLabel.isHidden = false
            return
        }
        if !passwordLabel.hasText {
            self.invalidPasswordLabel.isHidden = false
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
                        UserDefaults.standard.setValue(emailId, forKey: ViewController.UserEmail)
                        
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
