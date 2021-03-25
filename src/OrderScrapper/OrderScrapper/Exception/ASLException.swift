//
//  ASLException.swift
//  OrderScrapper

import Foundation

public class ASLException: Error {
    let errorMessage: String?
    
    init(errorMessage: String?) {
        self.errorMessage = errorMessage
    }
}
