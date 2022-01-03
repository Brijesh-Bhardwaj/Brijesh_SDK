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
    public let error: Error?
    
    init(errorMessage: String, errorType: ErrorType?) {
        self.errorMessage = errorMessage
        self.errorType = errorType
        self.errorEventLog = nil
        self.errorScrappingType = nil
        self.error = nil
    }
    init(errorMessages: String, errorTypes: ErrorType?, errorEventLog: FailureTypes?, errorScrappingType: ScrappingType?) {
        self.errorMessage = errorMessages
        self.errorType = errorTypes
        self.errorEventLog = errorEventLog
        self.errorScrappingType = errorScrappingType
        self.error = nil
    }
    init(error: Error?, errorMessage: String, failureType: FailureTypes?) {
        self.error = error
        self.errorMessage = errorMessage
        self.errorEventLog = failureType
        self.errorType = nil
        self.errorScrappingType = nil
    }
}
