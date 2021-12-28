//  ServicesStatusListener.swift
//  OrderScrapper

import Foundation

public protocol ServicesStatusListener {
    
    func onServicesFailure(exception: ASLException)
    
}
