//
//  JSUtils.swift
//  OrderScrapper

import Foundation

class JSUtils {
    
    static func getAuthErrorVerificationJS() -> String {
        return "(function() { var element = document.getElementById('auth-error-message-box');" +
            "if (element != null && element.innerHTML !== null) " +
            "{return element.getElementsByClassName('a-list-item')[0].innerText;} else {" +
            " return ''}})()"
    }
    
    static func getFieldIdentificationJS() -> String{
        return "(function() { var element = document.getElementById('ap_email_login');" +
            "if (element != null && element.innerHTML !== null) " +
            " { return 'emailId' } else { " +
            " var element = document.getElementById('ap_password');" +
            " if (element != null && element.innerHTML !== null) " +
            " { return 'pwd'} else { return 'other' }}})()"
    }
    
    static func getCaptchaIdentificationJS() -> String {
        return "(function() { var element = document.getElementById('auth-captcha-guess');" +
            "if (element != null && element.innerHTML !== null) " +
            "{return 'captcha'} else {" +
            " return null}})()"
    }
    
    static func getEmailInjectJS(email: String) -> String {
        return "javascript:" +
            "document.getElementById('ap_email_login').value = '" + email + "';" + "document.querySelector('#accordion-row-login #continue #continue').click()"
    }
    
    static func getPasswordInjectJS(password: String) -> String {
        return "javascript:" +
            "document.getElementById('ap_password').value = '" + password + "';" +
            "document.getElementById('signInSubmit').click()"
    }
}
