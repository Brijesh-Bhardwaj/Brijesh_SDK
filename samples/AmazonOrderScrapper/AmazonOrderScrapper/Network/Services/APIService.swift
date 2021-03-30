//
//  APIService.swift
//  AmazonOrderScrapper


import Foundation
import Alamofire

class APIService {
    static let BASE_URL = "https://ncpiriqa.ncponline.net/recap-ws/Service/v2/Login?"
    static let Method_Type = "POST"
    
    static func loginAPI(userName: String, password: String, _ completionHandler: @escaping (LoginResponse?, Error?) -> Void) {
        // Create the URLSession on the default configuration
        let defaultSessionConfiguration = URLSessionConfiguration.default
        let defaultSession = URLSession(configuration: defaultSessionConfiguration)
        
        // Setup the request with URL
        let url = URL(string: BASE_URL + AppConstant.username + userName)
        var urlRequest = URLRequest(url: url!)  // Note: This is a demo, that's why I use implicitly unwrapped optional
        let gToken = Util.getToken(username: userName, password: password, constant: AppConstant.password)

        // Set the httpMethod and assign httpBody
        urlRequest.httpMethod = Method_Type
        urlRequest.httpBody = gToken.data(using: String.Encoding.utf8)
        
        // Create dataTask
        let dataTask = defaultSession.dataTask(with: urlRequest) { (data, response, error) in
            // Handle your response here
            if let data = data {
                do {
                    let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
                    print(loginResponse)
                    completionHandler(loginResponse, nil)
                } catch let error {
                    completionHandler(nil, error)
                }
            } else {
                completionHandler(nil, error)
            }
        }
        // Fire the request
        dataTask.resume()
    }
}
