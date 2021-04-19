import Foundation
//  ASLException.swift
//  OrderScrapper
/*
 Represents the error object in the SDK. The application should
 expect an ASLException obejct ncase of any error in the SDK.
 **/
public class ASLException: Error {
    public let errorMessage: String
    
    init(errorMessage: String) {
        self.errorMessage = errorMessage
    }
}
