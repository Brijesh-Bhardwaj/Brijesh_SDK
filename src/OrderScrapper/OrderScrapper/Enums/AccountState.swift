import Foundation
//  StatusEnum.swift
//  OrderScrapper
/*
 Represents the connection state of the account
 **/
public enum AccountState: Int16 {
    case NeverConnected  // the account was never conencted
    case Connected  // the account conencted
    case ConnectedAndDisconnected  // the account was connected one but manually disconnected
    case ConnectedButException  // the account is connected but the SDK is not able to conenct to it
}
