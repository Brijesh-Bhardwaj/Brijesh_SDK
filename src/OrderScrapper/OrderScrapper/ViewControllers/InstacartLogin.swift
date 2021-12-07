//  InstacartLogin.swift
//  OrderScrapper

import Foundation
import UIKit

class InstacartLogin: BaseLoginViewController {
    let viewControllerIdentifier = "InstacartConnectAccountVC"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.userInfoMessage()
    }
    
    override func getScreenTitle() throws -> String {
        return Utils.getString(key: Strings.HeadingConnectInstacartAccount)
    }
    
    override func getHeading() throws -> String {
        return Utils.getString(key: Strings.HeadingPleaseSignInWithInstacartCredentials)
    }
    
    override func getUserIdPlaceHolder() throws -> String {
        return Utils.getString(key: Strings.LabelInstacartEmailId)
    }
    
    override func getUserIdValidationMsg() throws -> String {
        return Utils.getString(key: Strings.ValidationInstacartPleaseEnterValidEmail)
    }
    
    override func getViewController(account: UserAccountMO) throws -> UIViewController {
        let storyboard = UIStoryboard(name: "OSLibUI", bundle: Bundle(identifier: AppConstants.identifier))
        let viewController = storyboard
            .instantiateViewController(identifier: viewControllerIdentifier) as! ConnectInstacartAccountVC
        viewController.account = account
        return viewController
    }
    
    func userInfoMessage() {
           let regularMessage = [
               NSAttributedString.Key.font: UIFont(name: Strings.UIFontLight, size: 17.0)!
           ]
           let alertMessage = Utils.getString(key: Strings.ICAlertUserMessage)
           let alert = alertMessage + "."
           let regularText = NSAttributedString(string: alert, attributes: regularMessage)
           let newString = NSMutableAttributedString()
           newString.append(regularText)
           loginView.userAlertLabel.attributedText = newString
       }
}
