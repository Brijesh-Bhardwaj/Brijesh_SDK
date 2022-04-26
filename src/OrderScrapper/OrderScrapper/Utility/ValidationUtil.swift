//
//  File.swift
//  OrderScrapper


import Foundation

class ValidationUtil {
    static let emailRegEx = "[a-zA-Z0-9_.+-]+@[a-zA-Z0-9]+\\.+[a-z.]+"
    static let mobileNoRegex = "^[+]?[0-9]{10,13}$"
    
    static func isValidEmail(email: String) -> Bool {
        let emailTest = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        let mobileTest = NSPredicate(format: "SELF MATCHES %@", mobileNoRegex)
        if !emailTest.evaluate(with: email) && !mobileTest.evaluate(with: email) {
            return false
        }
        return true
    }
    
    static func isValidPassword(password: String) -> Bool {
        return !password.isEmpty
    }
}

