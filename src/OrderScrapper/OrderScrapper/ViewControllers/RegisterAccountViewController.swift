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
    
    var account: UserAccountMO!
    
    private var authErrorSubscriber: AnyCancellable? = nil
    private var completionSubscriber: AnyCancellable? = nil
    
    // MARK: - Lifecycle Methods
    deinit {
        authErrorSubscriber?.cancel()
        completionSubscriber?.cancel()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        makeRoundedView(view: self.userIDTextField)
        makeRoundedView(view: self.passwordTextField)
        
        setupSubscribers()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.contentView.clipsToBounds = true
        self.contentView.layer.cornerRadius = self.contentView.bounds.width * 0.1
        self.contentView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
    }
    
    // MARK: - IBActions
    @IBAction func didSubmit(_ sender: Any) {
        guard let userId = self.userIDTextField.text else {
            return
        }
        guard let password = self.passwordTextField.text else {
            return
        }
        
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
        
        self.presentConnectVC(userID: userId, password: password)
    }
    
    @IBAction func onBackEvent(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
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
        }
        
        completionSubscriber = LibContext.shared.scrapeCompletionPublisher.receive(on: RunLoop.main).sink { isComplete, error in
            self.dismiss(animated: true, completion: nil)
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
