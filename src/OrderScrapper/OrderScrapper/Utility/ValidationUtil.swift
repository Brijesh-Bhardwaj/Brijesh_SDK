//
//  File.swift
//  OrderScrapper


import Foundation

class ValidationUtil {
    static let emailRegEx = "[A-Z0-9a-z.-_]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,3}"
    
    static func isValidEmail(email: String) -> Bool {
        let emailTest = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        if !email.isEmpty && emailTest.evaluate(with: email) {
            return true
        }
           return false
    }
    
    static func isValidPassword(password: String) -> Bool {
        return !password.isEmpty
    }
}
