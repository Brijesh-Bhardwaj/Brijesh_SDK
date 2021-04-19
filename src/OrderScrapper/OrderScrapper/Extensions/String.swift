//
//  String.swift
//  OrderScrapper

import Foundation

extension String {
    func toData() -> Data {
        return Data(self.utf8)
    }
}
