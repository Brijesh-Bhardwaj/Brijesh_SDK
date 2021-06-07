//  BSHtmlScrappingStatusListener.swift
//  OrderScrapper

import Foundation

protocol BSHtmlScrappingStatusListener {
    
    func onHtmlScrappingSucess(response: String)
    
    func onHtmlScrappingFailure(error: ASLException)
    
    func onScrapeDataUploadCompleted(complete: Bool)
}
