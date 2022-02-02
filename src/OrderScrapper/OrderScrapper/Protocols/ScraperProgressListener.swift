//  CSVScraper.swift
//  OrderScrapper

import Foundation

protocol ScraperProgressListener {
    func onWebviewError(isError: Bool) 
    func onCompletion(isComplete: Bool)
    func updateProgressValue(progressValue: Float)
    func updateStepMessage(stepMessage: String)
    func updateProgressStep(htmlScrappingStep: HtmlScrappingStep)
    func updateSuccessType(successType: OrderFetchSuccessType)
    func onServicesDown(error: ASLException?)
    func updateScrapeProgressPercentage(value: Int)
    func updateProgressHeaderLabel(isUploadingPreviousOrder: Bool) 
}

