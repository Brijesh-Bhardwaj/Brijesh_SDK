//
//  Data.swift
//  OrderScrapper


import Foundation

extension Data {
    func toString() -> String {
        return String(decoding: self, as: UTF8.self)
    }
}
