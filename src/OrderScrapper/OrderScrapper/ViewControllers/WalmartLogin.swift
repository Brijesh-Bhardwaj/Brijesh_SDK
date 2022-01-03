//  WalmartLogin.swift
//  OrderScrapper


import Foundation
import UIKit

class WalmartLogin: BaseLoginViewController {
    let viewControllerIdentifier = "WalmartConnectAccountVC"
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func getScreenTitle() throws -> String {
        return Utils.getString(key: Strings.HeadingConnectWalmartAccount)
    }
    
    override func getHeading() throws -> String {
        return Utils.getString(key: Strings.HeadingPleaseSignInWithWalmartCredentials)
    }
    
    override func getUserIdPlaceHolder() throws -> String {
        return Utils.getString(key: Strings.LabelWalmartEmailId)
    }
    
    override func getUserIdValidationMsg() throws -> String {
        return Utils.getString(key: Strings.ValidationWalmartPleaseEnterValidEmail)
    }
    
    override func getViewController(account: UserAccountMO) throws -> UIViewController {
        let storyboard = UIStoryboard(name: "OSLibUI", bundle: Bundle(identifier: AppConstants.identifier))
        let viewController = storyboard
            .instantiateViewController(identifier: viewControllerIdentifier) as! ConnectWalmartAccountVC
        viewController.account = account
        return viewController
    }
}
