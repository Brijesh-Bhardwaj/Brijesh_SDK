//
//  ValidationUtil.swift
//  AmazonOrderScrapper


import Foundation

class ValidationUtil {
    
    static let emailRegEx = "[A-Z0-9a-z.-_]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,3}"
    
    static func isValidEmail(email: String) -> Bool {
        let emailTest = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        if emailTest.evaluate(with: email)  {
            return true
        }
        return false
    }
}
