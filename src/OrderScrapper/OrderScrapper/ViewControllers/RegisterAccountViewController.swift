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
    @IBOutlet weak var invalidUserIdView: UILabel!
    @IBOutlet weak var invalidPasswordView: UILabel!
    @IBOutlet weak var submitButton: UIButton!
    @IBOutlet weak var authErrorLabel: UILabel!
    @IBOutlet weak var showPasswordButton: UIButton!
    
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
        
        setupSubscribers()
        
        if !account.userID.isEmpty {
            self.userIDTextField.text = account.userID
            self.userIDTextField.isEnabled = false
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        WebCacheCleaner.clear(completionHandler: nil)
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
            self.invalidUserIdView.isHidden = false
            return
        }
        guard let password = self.passwordTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            self.invalidPasswordView.isHidden = false
            return
        }
        
        self.invalidUserIdView.isHidden = true
        self.invalidPasswordView.isHidden = true

        if !ValidationUtil.isValidEmail(email: userId) {
            self.invalidUserIdView.isHidden = false
            return
        }
        
        if !ValidationUtil.isValidPassword(password: password) {
            self.invalidPasswordView.isHidden = false
            return
        }
        
        self.invalidUserIdView.isHidden = true
        self.invalidPasswordView.isHidden = true
        self.authErrorView.isHidden = true
        
        WebCacheCleaner.clear() { cleared in
            self.presentConnectVC(userID: userId, password: password)
        }
    }
    
    @IBAction func onBackEvent(_ sender: Any) {
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
        view.layer.borderWidth = 1.0
        view.layer.borderColor = UIColor(red: 0.996, green: 0.761, blue: 0.137, alpha: 1).cgColor
        view.layer.cornerRadius = 8
    }
    
    private func setupSubscribers() {
        authErrorSubscriber = LibContext.shared.webAuthErrorPublisher.receive(on: RunLoop.main).sink { authError in
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
        self.invalidUserIdView.isHidden = true
        self.invalidPasswordView.isHidden = true
    }
}
