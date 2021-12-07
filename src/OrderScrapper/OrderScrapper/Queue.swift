//  Queue.swift
//  OrderScrapper

import Foundation

class Queue<T> {
    var dataQueue: [T]
    
    init(queue: [T]) {
        self.dataQueue = queue
    }
    
    func isEmpty() -> Bool {
        return dataQueue.isEmpty
    }
    
    func peek() -> T? {
        if (!isEmpty())  {
            return dataQueue.removeFirst()
        }
        return nil
    }
    
    func peekData() -> T? {
        if (!isEmpty()) {
            return dataQueue.first
        }
        return nil
    }
}
