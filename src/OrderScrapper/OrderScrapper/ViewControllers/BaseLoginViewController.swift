//  BaseLoginViewController.swift
//  OrderScrapper

import Foundation
import UIKit
import Combine

class BaseLoginViewController: UIViewController, LoginViewDelegate {
    private var authErrorSubscriber: AnyCancellable? = nil
    private var showPassword = false
    var loginView: LoginView!
    var account: UserAccountMO!
    
    // MARK: - Lifecycle Methods
    deinit {
        authErrorSubscriber?.cancel()
    }
    
    override func viewDidLoad() {
        loginView = LoginView(frame: self.view.bounds)
        loginView.delegate = self
        
        setLabelText(loginView: loginView)
        setupSubscribers(loginView: loginView)
        
        if !account.userID.isEmpty {
            loginView.userIDTextField.text = account.userID
            loginView.userIDTextField.isEnabled = false
        }
        WebCacheCleaner.clear(completionHandler: nil)
        
        view.addSubview(loginView)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        loginView.bodyView.clipsToBounds = true
        loginView.bodyView.layer.cornerRadius = self.loginView.bounds.width * 0.1
        loginView.bodyView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
    }
    
    // MARK: - Private Methods
    private func makeRoundedView(view: UIView) {
        view.layer.borderWidth = 2.0
        view.layer.borderColor = UIColor(hex: "#FFE9ADFF")?.cgColor
        view.layer.cornerRadius = 5
    }
    
    private func setLabelText(loginView: LoginView) {
        loginView.titleTextField.text = try! getScreenTitle()
        loginView.headerTextField.text = try! getHeading()
        loginView.userIDTextField.placeholder = try! getUserIdPlaceHolder()
    }
    
    private func setupSubscribers(loginView: LoginView) {
        authErrorSubscriber = LibContext.shared.webAuthErrorPublisher.receive(on: RunLoop.main).sink { [weak self] authError in
            guard let self = self else { return }
            
            loginView.authErrorView.isHidden = false
            var message = authError.1
            if message.isEmpty {
                message = Utils.getString(key: Strings.ErrorEnterValidUsernamePassword)
            }
            loginView.authErrorLabel.text = message
        }
    }
    
    func onBackEvent() {
        AmazonOrderScrapper.shared.isScrappingGoingOn = false
        self.dismiss(animated: true, completion: nil)
    }
    
    func toggleShowPassword() {
        showPassword = !showPassword
        if showPassword {
            loginView.showPasswordButton.setBackgroundImage(Utils.getImage(named: IconNames.CheckboxChecked), for: .normal)
            loginView.passwordTextField.isSecureTextEntry = false
        } else {
            loginView.showPasswordButton.setBackgroundImage(Utils.getImage(named: IconNames.CheckboxUnchecked), for: .normal)
            loginView.passwordTextField.isSecureTextEntry = true
        }
    }
    
    func setHyperLinkLable(){
        loginView.userAlertLabel.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.labelTapped))
        loginView.userAlertLabel.addGestureRecognizer(tap)
        loginView.userAlertLabel.textColor = .blue
    }
    @objc func labelTapped(_ gestureRecognizer: UITapGestureRecognizer) {
        print("Label clicked")
        let storyboard = UIStoryboard(name: "OSLibUI", bundle: Bundle(identifier: AppConstants.identifier))
        let viewController = storyboard
            .instantiateViewController(identifier: "KrogerSubsidiaryAccountVC") as! KrogerSubsidiaryAccountVC
        viewController.modalPresentationStyle = .fullScreen
        self.present(viewController, animated: true, completion: nil)        
    }

    func onSubmit() {
        guard let userId = loginView.userIDTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            loginView.authErrorLabel.text = Utils.getString(key: try! getUserIdValidationMsg())
            loginView.authErrorView.isHidden = false
            return
        }
        guard let password = loginView.passwordTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            loginView.authErrorLabel.text = Utils.getString(key: Strings.ValidationPleaseEnterValidPassword)
            loginView.authErrorView.isHidden = false
            return
        }
        
        loginView.authErrorView.isHidden = true
        
        if !ValidationUtil.isValidEmail(email: userId) {
            loginView.authErrorLabel.text = Utils.getString(key: try! getUserIdValidationMsg())
            loginView.authErrorView.isHidden = false
            return
        }
        
        if !ValidationUtil.isValidPassword(password: password) {
            loginView.authErrorLabel.text = Utils.getString(key: Strings.ValidationPleaseEnterValidPassword)
            loginView.authErrorView.isHidden = false
            return
        }
        
        loginView.authErrorView.isHidden = true
        
        WebCacheCleaner.clear() { [weak self] cleared in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.presentConnectVC(userID: userId, password: password)
            }
        }
        //TODO :- OrderSource   
        FirebaseAnalyticsUtil.logUserProperty(orderSourceId: userId, orderSource: self.account.source)
    }
    
    private func presentConnectVC(userID: String, password: String) {
        self.account.userID = userID
        self.account.userPassword = password
        let viewController = try! getViewController(account: self.account)
        viewController.modalPresentationStyle = .fullScreen
        self.present(viewController, animated: true, completion: nil)
    }
    
    func getScreenTitle() throws -> String {
        throw ASLException(errorMessage: Strings.ErrorLabelStringNotPassed, errorType: nil)
    }
    
    func getHeading() throws -> String {
        throw ASLException(errorMessage: Strings.ErrorLabelStringNotPassed, errorType: nil)
    }
    
    func getUserIdPlaceHolder() throws -> String {
        throw ASLException(errorMessage: Strings.ErrorLabelStringNotPassed, errorType: nil)
    }
    
    func getUserIdValidationMsg() throws -> String {
        throw ASLException(errorMessage: Strings.ErrorLabelStringNotPassed, errorType: nil)
    }
    
    func getViewController(account: UserAccountMO) throws -> UIViewController {
        throw ASLException(errorMessage: Strings.ErrorViewControllerNotPassed, errorType: nil)
    }
}

