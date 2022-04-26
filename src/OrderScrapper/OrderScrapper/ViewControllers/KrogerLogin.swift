//
//  KrogerLogin.swift
//  OrderScrapper

import Foundation
import UIKit

class KrogerLogin: BaseLoginViewController {
    let viewControllerIdentifier = "KrogerConnectAccountVC"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.userInfoMessage()
    }
    
    override func getScreenTitle() throws -> String {
        return Utils.getString(key: Strings.HeadingConnectKrogerAccount)
    }
    
    override func getHeading() throws -> String {
        return Utils.getString(key: Strings.HeadingPleaseSignInWithKrogerCredentials)
    }
    
    override func getUserIdPlaceHolder() throws -> String {
        return Utils.getString(key: Strings.LabelKrogerEmailId)
    }
    
    override func getUserIdValidationMsg() throws -> String {
        return Utils.getString(key: Strings.ValidationKrogerPleaseEnterValidEmail)
    }
    
    override func getViewController(account: UserAccount) throws -> UIViewController {
        let storyboard = UIStoryboard(name: "OSLibUI", bundle: Bundle(identifier: AppConstants.identifier))
        let viewController = storyboard
            .instantiateViewController(identifier: viewControllerIdentifier) as! ConnectKrogerAccountVC
        viewController.account = account
        return viewController
    }
    
    func userInfoMessage() {
        let regularMessage = [
            NSAttributedString.Key.font: UIFont(name: Strings.UIFontBold, size: 16.0)!
        ]
        let alertMessage = Utils.getString(key: Strings.KRLoginHyperLinkLable)
        let regularText = NSAttributedString(string: alertMessage, attributes: regularMessage)
        let newString = NSMutableAttributedString()
        newString.append(regularText)
        let textRange = NSRange(location: 0, length: alertMessage.count)
        newString.addAttribute(.underlineStyle,
                                            value: NSUnderlineStyle.single.rawValue,
                                            range: textRange)
        loginView.userAlertLabel.attributedText = newString
        self.setHyperLinkLable()
    }
}

