//  Queue.swift
//  OrderScrapper

import Foundation

class Queue<T> {
    var orderDetailsQueue: [T]
    
    init(orderDetails: [T]) {
        self.orderDetailsQueue = orderDetails
    }
    
    func isEmpty() -> Bool {
        return orderDetailsQueue.isEmpty
    }
    
    func peek() -> T? {
        if (!isEmpty())  {
            return orderDetailsQueue.removeFirst()
        }
        return nil
    }
}
