import Foundation
//  OrderFetchSuccessType.swift
//  OrderScrapper

/*
 Represents the success type the order fetch operation
 **/

public enum OrderFetchSuccessType {
    case fetchCompleted  // The operation is completed by fetching the receipts successfully
    case fetchSkipped  // The operation is completed and receipt fetching is skipped due to configuration
}
