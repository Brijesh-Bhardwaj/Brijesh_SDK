//
//  AmazonAuthenticator.swift
//  OrderScrapper
//

import Foundation
import WebKit
import SwiftUI
import Combine

enum JSInjectValue {
    case email, password, captcha, error, identification, generateReport, downloadReport
}

internal class AmazonAuthenticator {
    @ObservedObject var viewModel: WebViewModel
    
    var jsResultSubscriber: AnyCancellable? = nil
    
    required init(_ viewModel: WebViewModel) {
        self.viewModel = viewModel
    }
    
    deinit {
        self.jsResultSubscriber?.cancel()
    }
    
    public func authenticate() {
        self.jsResultSubscriber = viewModel.jsResultPublisher.receive(on: RunLoop.main)
            .sink(receiveValue: { (injectValue, result) in
                print("JS Result: ", injectValue, result)
                let (response, _) = result
                switch injectValue {
                case .email, .password, .generateReport, .downloadReport: break
                case .error:
                    if let response = response {
                        let strResult = response as! String
                        if (strResult.isEmpty) {
                            self.injectCaptchaIdentificationJS()
                        } else {
                            //Error
                        }
                    } else {
                        self.injectCaptchaIdentificationJS()
                    }
                case .identification:
                    if let response = response as? String {
                        if response.contains("emailId") {
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
        let email = self.viewModel.userEmail!
        print("Injecting email ", email)
        let js = "javascript:" +
            "document.getElementById('ap_email_login').value = '" + email + "';" + "document.querySelector('#accordion-row-login #continue #continue').click()"
        
        self.viewModel.jsPublisher.send((.email, js))
    }
    
    private func injectPasswordJS() {
        let password = self.viewModel.userPassword!
        print("Injecting password: ", password)
        let js = "javascript:" +
            "document.getElementById('ap_password').value = '" + password + "';" +
            "document.getElementById('signInSubmit').click()"
        
        self.viewModel.jsPublisher.send((.password, js))
    }
    
    private func injectFieldIdentificationJS() {
        let js = "(function() { var element = document.getElementById('ap_email_login');" +
            "if (element != null && element.innerHTML !== null) " +
            "{return 'emailId'} else {" +
            " return null}})()"
        
        self.viewModel.jsPublisher.send((.identification, js))
    }
    
    private func injectCaptchaIdentificationJS() {
        let js = "(function() { var element = document.getElementById('auth-captcha-guess');" +
            "if (element != null && element.innerHTML !== null) " +
            "{return 'captcha'} else {" +
            " return null}})()"
        
        self.viewModel.jsPublisher.send((.captcha, js))
    }
}
