//
//  ASLException.swift
//  OrderScrapper

import Foundation

public class ASLException: Error {
    public let errorMessage: String
    
    init(errorMessage: String) {
        self.errorMessage = errorMessage
    }
}
