//
//  RegisterAccountViewController.swift
//  OrderScrapper
//

import UIKit
import Combine

class RegisterAccountViewController: UIViewController {
    // MARK: - IBOutlets
    @IBOutlet weak var userIDTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var authErrorView: UIView!
    @IBOutlet weak var submitButton: UIButton!
    @IBOutlet weak var authErrorLabel: UILabel!
    @IBOutlet weak var showPasswordButton: UIButton!
    
    @IBOutlet weak var userAlertLabel: UILabel!
    var account: UserAccountMO!
    
    private var authErrorSubscriber: AnyCancellable? = nil
    
    private var showPassword = false
    
    // MARK: - Lifecycle Methods
    deinit {
        authErrorSubscriber?.cancel()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        makeRoundedView(view: self.userIDTextField)
        makeRoundedView(view: self.passwordTextField)
        
        self.passwordTextField.delegate = self
        self.userIDTextField.delegate = self
        userInfoMessage()
        setupSubscribers()
        
        if !account.userID.isEmpty {
            self.userIDTextField.text = account.userID
            self.userIDTextField.isEnabled = false
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
//        WebCacheCleaner.clear(completionHandler: nil)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.contentView.clipsToBounds = true
        self.contentView.layer.cornerRadius = self.contentView.bounds.width * 0.1
        self.contentView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
    }
    
    // MARK: - IBActions
    @IBAction func didSubmit(_ sender: Any) {
        guard let userId = self.userIDTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            self.authErrorLabel.text = Utils.getString(key: Strings.ValidationPleaseEnterValidEmail)
            self.authErrorView.isHidden = false
            return
        }
        guard let password = self.passwordTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            self.authErrorLabel.text = Utils.getString(key: Strings.ValidationPleaseEnterValidPassword)
            self.authErrorView.isHidden = false
            return
        }
        
        self.authErrorView.isHidden = true
        
        if !ValidationUtil.isValidEmail(email: userId) {
            self.authErrorLabel.text = Utils.getString(key: Strings.ValidationPleaseEnterValidEmail)
            self.authErrorView.isHidden = false
            return
        }
        
        if !ValidationUtil.isValidPassword(password: password) {
            self.authErrorLabel.text = Utils.getString(key: Strings.ValidationPleaseEnterValidPassword)
            self.authErrorView.isHidden = false
            return
        }
        
        self.authErrorView.isHidden = true
        
        WebCacheCleaner.clear() { [weak self] cleared in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.presentConnectVC(userID: userId, password: password)
            }
        }
        FirebaseAnalyticsUtil.logUserProperty(orderSourceId: userId, orderSource: OrderSource.Amazon)
    }
    
    @IBAction func onBackEvent(_ sender: Any) {
        AmazonOrderScrapper.shared.isScrapping = false
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func toggleShowPassword(_ sender: Any) {
        showPassword = !showPassword
        if showPassword {
            self.showPasswordButton.setBackgroundImage(Utils.getImage(named: IconNames.CheckboxChecked), for: .normal)
            self.passwordTextField.isSecureTextEntry = false
        } else {
            self.showPasswordButton.setBackgroundImage(Utils.getImage(named: IconNames.CheckboxUnchecked), for: .normal)
            self.passwordTextField.isSecureTextEntry = true
        }
    }
    
    // MARK: - Private Methods
    private func makeRoundedView(view: UIView) {
        view.layer.borderWidth = 2.0
        view.layer.borderColor = UIColor(hex: "#FFE9ADFF")?.cgColor
        view.layer.cornerRadius = 5
    }
    
    private func setupSubscribers() {
        authErrorSubscriber = LibContext.shared.webAuthErrorPublisher.receive(on: RunLoop.main).sink { [weak self] authError in
            guard let self = self else { return }
            
            self.authErrorView.isHidden = false
            var message = authError.1
            if message.isEmpty {
                message = Utils.getString(key: Strings.ErrorEnterValidUsernamePassword)
            }
            self.authErrorLabel.text = message
        }
    }
    
    private func presentConnectVC(userID: String, password: String) {
        self.account.userID = userID
        self.account.userPassword = password
        
        let storyboard = UIStoryboard(name: "OSLibUI", bundle: Bundle(identifier: AppConstants.identifier))
        let viewController = storyboard.instantiateViewController(identifier: "ConnectAccountVC") as! ConnectAccountViewController
        viewController.account = self.account
        viewController.modalPresentationStyle = .fullScreen
        self.present(viewController, animated: true, completion: nil)
    }
    
    private func userInfoMessage() {
        let boldMessage = [
            NSAttributedString.Key.font: UIFont(name: Strings.UIFontBold, size: 17.0)!
        ]
        let regularMessage = [
            NSAttributedString.Key.font: UIFont(name: Strings.UIFontLight, size: 17.0)!
        ]
        let message = Utils.getString(key: Strings.AlertBoldMessage)
        let alertMessage = Utils.getString(key: Strings.AlertUserMessage)
        let appName = LibContext.shared.orderExtractorConfig.appName
        let alert = alertMessage + appName + "."
        let boldText = NSAttributedString(string: message, attributes: boldMessage)
        let regularText = NSAttributedString(string: alert, attributes: regularMessage)
        let newString = NSMutableAttributedString()
        newString.append(boldText)
        newString.append(regularText)
        userAlertLabel.attributedText = newString
    }
}

extension RegisterAccountViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.isEqual(self.userIDTextField) {
            self.passwordTextField.becomeFirstResponder()
        } else {
            textField.endEditing(true)
        }
        
        return false
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.authErrorView.isHidden = true
        let borderColor = UIColor(hex: "#fec223ff")
        textField.borderColor = borderColor
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        let borderColor = UIColor(hex: "#ffe9adff")
        textField.borderColor = borderColor
    }
}


