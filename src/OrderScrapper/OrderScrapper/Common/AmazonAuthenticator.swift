//
//  AmazonAuthenticator.swift
//  OrderScrapper
//

import Foundation
import WebKit
import SwiftUI
import Combine

enum JSInjectValue {
    case email, password, captcha, error, identification, generateReport, downloadReport, dateRange
}

internal class AmazonAuthenticator: Authenticator {
    @ObservedObject var viewModel: WebViewModel
    
    var jsResultSubscriber: AnyCancellable? = nil
    
    required init(_ viewModel: WebViewModel) {
        self.viewModel = viewModel
    }
    
    deinit {
        self.jsResultSubscriber?.cancel()
    }
    
    func authenticate() {
        self.jsResultSubscriber = viewModel.jsResultPublisher.receive(on: RunLoop.main)
            .sink(receiveValue: { (injectValue, result) in
                let (response, _) = result
                switch injectValue {
                case .email, .password, .generateReport, .downloadReport, .dateRange: break
                case .error:
                    if let response = response {
                        let strResult = response as! String
                        if (strResult.isEmpty) {
                            self.injectCaptchaIdentificationJS()
                        } else {
                            self.notifyAuthError(errorMessage: strResult)
                        }
                    } else {
                        self.injectCaptchaIdentificationJS()
                    }
                case .identification:
                    if let response = response as? String {
                        if response.contains("other") {
                            self.viewModel.showWebView.send(true)
                        } else if response.contains("emailId") {
                            self.injectEmailJS()
                        } else {
                            self.injectPasswordJS()
                        }
                    } else {
                        self.injectPasswordJS()
                    }
                case .captcha:
                    if let response = response as? String {
                        if response.contains("captcha") {
                            self.updateAccountWithExceptionState(message: AppConstants.msgCapchaEncountered)
                            self.viewModel.showWebView.send(true)
                        } else {
                            self.injectFieldIdentificationJS()
                        }
                    } else {
                        self.injectFieldIdentificationJS()
                    }
                }
            })
        
        self.injectAuthErrorVerificationJS()
    }
    
    private func injectAuthErrorVerificationJS() {
        let js = "(function() { var element = document.getElementById('auth-error-message-box');" +
            "if (element != null && element.innerHTML !== null) " +
            "{return element.getElementsByClassName('a-list-item')[0].innerText;} else {" +
            " return ''}})()"
        
        self.viewModel.jsPublisher.send((.error, js))
    }
    
    private func injectEmailJS() {
        let email = self.viewModel.userAccount.userID
        let js = "javascript:" +
            "document.getElementById('ap_email_login').value = '" + email + "';" + "document.querySelector('#accordion-row-login #continue #continue').click()"
        
        self.viewModel.jsPublisher.send((.email, js))
    }
    
    private func injectPasswordJS() {
        let password = self.viewModel.userAccount.userPassword
        let js = "javascript:" +
            "document.getElementById('ap_password').value = '" + password + "';" +
            "document.getElementById('signInSubmit').click()"
        
        self.viewModel.jsPublisher.send((.password, js))
    }
    
    private func injectFieldIdentificationJS() {
        let js = "(function() { var element = document.getElementById('ap_email_login');" +
            "if (element != null && element.innerHTML !== null) " +
            " { return 'emailId' } else { " +
            " var element = document.getElementById('ap_password');" +
            " if (element != null && element.innerHTML !== null) " +
            " { return 'pwd'} else { return 'other' }}})()"
        
        self.viewModel.jsPublisher.send((.identification, js))
    }
    
    private func injectCaptchaIdentificationJS() {
        let js = "(function() { var element = document.getElementById('auth-captcha-guess');" +
            "if (element != null && element.innerHTML !== null) " +
            "{return 'captcha'} else {" +
            " return null}})()"
        
        self.viewModel.jsPublisher.send((.captcha, js))
    }
    
    private func updateAccountWithExceptionState(message: String) {
        let userId = self.viewModel.userAccount.userID
        let panelistId = LibContext.shared.authProvider.getPanelistID()
        let accountState = self.viewModel.userAccount.accountState
        var status: String
        
        switch accountState {
        case .NeverConnected:
            status = AccountState.NeverConnected.rawValue
        case .ConnectedButException, .ConnectedAndDisconnected, .Connected:
            status = AccountState.ConnectedButException.rawValue
            
            do {
                try CoreDataManager.shared.updateUserAccount(userId: self.viewModel.userAccount.userID, accountStatus: AccountState.ConnectedButException.rawValue, panelistId: panelistId)
            } catch let error {
                print(AppConstants.tag, "updateAccountWithExceptionState", error.localizedDescription)
            }
        }
        _ = AmazonService.updateStatus(amazonId: userId, status: status
                                       , message: message, orderStatus: OrderStatus.Initiated.rawValue) { response, error in
            //Todo
        }
    }
    
    private func notifyAuthError(errorMessage: String) {
        let accountState = self.viewModel.userAccount.accountState.rawValue
        if accountState == AccountState.NeverConnected.rawValue {
            let userId = self.viewModel.userAccount.userID
            _ = AmazonService.registerConnection(amazonId: userId,
                                                 status: AccountState.NeverConnected.rawValue,
                                                 message: errorMessage, orderStatus: OrderStatus.None.rawValue) { response, error in
               //TODO
            }
        } else {
            self.updateAccountWithExceptionState(message: AppConstants.msgAuthError)
        }
        self.viewModel.authError.send((true, ""))
        WebCacheCleaner.clear(completionHandler: nil)
    }
}
