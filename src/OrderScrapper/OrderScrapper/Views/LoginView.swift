//  LoginView.swift
//  OrderScrapper

import Foundation
import UIKit

protocol LoginViewDelegate  {
    func onSubmit()
    func onBackEvent()
    func toggleShowPassword()
}

class LoginView: UIView {
    let nibName = "LoginView"
    
    @IBOutlet weak var userIDTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var submitButton: UIButton!
    @IBOutlet weak var showPasswordButton: UIButton!
    @IBOutlet weak var authErrorView: UIStackView!
    @IBOutlet weak var headerTextField: UILabel!
    @IBOutlet weak var authErrorLabel: UILabel!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var titleTextField: UILabel!
    @IBOutlet weak var bodyView: UIView!
    
    @IBOutlet weak var userAlertLabel: UILabel!
    var delegate: LoginViewDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initView()
    }
    
    private func initView() {
        let nib = UINib(nibName: nibName, bundle: AppConstants.bundle)
        nib.instantiate(withOwner: self, options: nil)

        self.contentView.frame = self.bounds
        
        makeRoundedView(view: self.userIDTextField)
        makeRoundedView(view: self.passwordTextField)
        
        self.passwordTextField.delegate = self
        self.userIDTextField.delegate = self
        
        self.addSubview(self.contentView)
    }
    
    @IBAction func didSubmit(_ sender: Any) {
        delegate?.onSubmit()
    }
    
    @IBAction func onBackEvent(_ sender: Any) {
        delegate?.onBackEvent()
    }
    
    @IBAction func toggleShowPassword(_ sender: Any) {
        delegate?.toggleShowPassword()
    }
    
    // MARK: - Private Methods
    private func makeRoundedView(view: UIView) {
        view.layer.borderWidth = 2.0
        view.layer.borderColor = UIColor(hex: "#FFE9ADFF")?.cgColor
        view.layer.cornerRadius = 5
    }
}

extension LoginView: UITextFieldDelegate {
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
