//  AmazonLogin.swift
//  OrderScrapper

import Foundation
import UIKit

class AmazonLogin: BaseLoginViewController {
    let viewControllerIdentifier = "ConnectAccountVC"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.userInfoMessage()
      
    }
    
    override func getScreenTitle() throws -> String {
        return Utils.getString(key: Strings.HeadingConnectAmazonAccount)
    }
    
    override func getHeading() throws -> String {
        return Utils.getString(key: Strings.HeadingPleaseSignInWithCredentials)
    }
    
    override func getUserIdPlaceHolder() throws -> String {
        return Utils.getString(key: Strings.LabelEmailOrMobileNumber)
    }
    
    override func getUserIdValidationMsg() throws -> String {
        return Utils.getString(key: Strings.ValidationPleaseEnterValidEmail)
    }
    
    override func getViewController(account: UserAccount) throws -> UIViewController {
        let storyboard = UIStoryboard(name: "OSLibUI", bundle: Bundle(identifier: AppConstants.identifier))
        let viewController = storyboard
            .instantiateViewController(identifier: viewControllerIdentifier) as! ConnectAccountViewController
        viewController.account = account
        return viewController
    }
    
    func userInfoMessage() {
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
           loginView.userAlertLabel.attributedText = newString
       }
    
}
