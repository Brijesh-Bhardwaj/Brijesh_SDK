import Foundation

//  AuthProvider.swift
//  OrderScrapper
/*
 Provides auth related data to the SDK when required.
 The application must implement this protocol.
 **/
public protocol AuthProvider {
    /// Gets the auth token of the logged in panelist user .
    /// This token used for the authentication of APIs internal to the SDK
    func getAuthToken() -> String
    
    /// Get the panelist ID of the logged in panelist user
    func getPanelistID() -> String
    
    /// Notifies the application to refrsh the auth tojken incase of the 401 failure.
    /// The SDK pauses API call for which 401 is received and awaits new token
    /// in the completionhandler closure. On reception of the new token , the SDK
    ///  resumes its opeartion
    /// - Parameter completionHandler : The application must either provide
    ///  a new authentication token or an error in case of failure. Application to ensure
    ///  that completion handler is called.
    func refreshAuthToken(completionHandler:(String?, Error?) -> Void)
}
