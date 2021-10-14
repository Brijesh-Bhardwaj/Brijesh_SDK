//  AuthenticationStatusListener.swift
//  OrderScrapper

import Foundation

protocol BSAuthenticationStatusListener  {
    
    func onAuthenticationSuccess()
    
    func onAuthenticationFailure(errorReason: ASLException)
}
