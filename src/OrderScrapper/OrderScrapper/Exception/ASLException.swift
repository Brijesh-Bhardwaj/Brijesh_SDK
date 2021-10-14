import Foundation
//  ASLException.swift
//  OrderScrapper
/*
 Represents the error object in the SDK. The application should
 expect an ASLException obejct ncase of any error in the SDK.
 **/
public class ASLException: Error {
    public let errorMessage: String
    public let errorType: ErrorType?
    public let errorEventLog: FailureTypes?
    public let errorScrappingType: ScrappingType?
    
    init(errorMessage: String, errorType: ErrorType?) {
        self.errorMessage = errorMessage
        self.errorType = errorType
        self.errorEventLog = nil
        self.errorScrappingType = nil
    }
    init(errorMessages: String, errorTypes: ErrorType?, errorEventLog: FailureTypes?, errorScrappingType: ScrappingType?) {
        self.errorMessage = errorMessages
        self.errorType = errorTypes
        self.errorEventLog = errorEventLog
        self.errorScrappingType = errorScrappingType
    }
}
