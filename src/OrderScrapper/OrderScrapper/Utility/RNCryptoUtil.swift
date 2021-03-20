//
//  RNCryptoUtil.swift
//  OrderScrapper


import Foundation
import RNCryptor

struct RNCryptoUtil {
    static func encryptData(userId: String, value: String) -> String {
        let data: Data = value.toData()
        let cryptoPassword = getCryptoPassword(userId: userId)
        let encryptedData = RNCryptor.encrypt(data: data, withPassword: cryptoPassword)
        return encryptedData.base64EncodedString()
    }
    
    static func decryptData(userId: String, value: String) -> String {
        var decryptedString: String = ""
        var decrypt: Data
        do {
            let data: Data = Data(base64Encoded: value)!
            
            decrypt =  try RNCryptor.decrypt(data: data, withPassword: getCryptoPassword(userId: userId))
            decryptedString = decrypt.toString()
        } catch {
            print("Error in decyption")
        }
        return decryptedString
    }
    
    /*
     * Generate password for encryption/decryption using userId
     */
    static func getCryptoPassword(userId: String) -> String {
        return (userId.data(using: .utf8)?.base64EncodedString())!
    }
}
