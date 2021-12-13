//  JSCallback.swift
//  OrderScrapper

import Foundation

struct JSCallback<T: Codable>: Codable {
    let type: String
    let status: String
    let isError: Bool
    let message: String?
    let errorMessage: String?
    let data: T?
}

