//  JSCallback.swift
//  OrderScrapper

import Foundation

struct JSCallback<T: Decodable>: Decodable {
    let type: String
    let status: String
    let isError: Bool
    let message: String
    let errorMessage: String?
    let data: T?
}

