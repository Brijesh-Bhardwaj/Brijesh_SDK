//
//  Util.swift
//  AmazonOrderScrapper

import Foundation
import RNCryptor

class Util {
    static func getToken(username: String, password: String, constant: String)-> String {
        let encodedUsernamePassword: String = AppConstant.username
            + username.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlHostAllowed)!
            + constant
            + password.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlHostAllowed)!
        
        let encryptedData = encryptData(encryptData: encodedUsernamePassword, value: AppConstant.tokenKey)
        
        let gToken  = AppConstant.gToken + encryptedData + AppConstant.enableEncoding
        return gToken
    }
    
    static func encryptData(encryptData: String, value: String) -> String {
        let data: Data = encryptData.toData()
        let encryptedData = RNCryptor.encrypt(data: data, withPassword: AppConstant.tokenKey)
        return encryptedData.base64EncodedString()
    }
    
}
