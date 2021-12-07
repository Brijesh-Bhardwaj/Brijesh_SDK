import Foundation
//  OrderFetchFailureType.swift
//  OrderScrapper

/*
 Represents the failure type of the order fetch operation
 **/

public enum ErrorType {
    case userAborted  // The operation is aborted while fetching the receipts
    case authError
    case authChallenge
}
