//
//  APIResponse.swift
//  OrderScrapper
//
/*
 {
    "statusCode": <IntValue>,
    "message": <String/Null value>,
    "error": <String/Null value>,
    "data": <Data object/Null value>,
    "isError": <BoolValue>
 }
*/

import Foundation

struct APIResponse<T: Decodable>: Decodable {
    let statusCode: Int
    let message: String?
    let error: String?
    let isError: Bool
    let data: T?
}
