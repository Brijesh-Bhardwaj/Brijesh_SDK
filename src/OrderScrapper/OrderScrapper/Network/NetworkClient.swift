//
//  NetworkClient.swift
//  OrderScrapper
//

import Foundation
import Alamofire

enum RequestMethod {
    case get, post, put, delete, multipart
}

class APIError: Error {
    let errorMessage: String
    
    init(error: String) {
        self.errorMessage = error
    }
}

class NetworkClient<T: Decodable>: APIClient {
    private let AuthErrorResponseCode = 401
    private let BaseURL = LibContext.shared.orderExtractorConfig.baseURL
    private let HeaderContentType = "Content-Type"
    private let ContentTypeJSON = "application/json"
    
    var relativeURL: String
    var requestMethod: RequestMethod
    var headers: [String: String]?
    var body: [String: Any]?
    var multipartFormClosure: ((MultipartFormData) -> Void)?
    
    required init(relativeURL url: String, requestMethod method: RequestMethod) {
        self.relativeURL = url
        self.requestMethod = method
    }
    
    func executeAPI(completionHandler: @escaping (Any?, Error?) -> Void) {
        let url = BaseURL + self.relativeURL
        var httpHeaders = HTTPHeaders()
        if let headers = self.headers {
            httpHeaders = HTTPHeaders(headers)
        }
        
        httpHeaders.add(HTTPHeader.contentType(ContentTypeJSON))
        httpHeaders.add(HTTPHeader.accept(ContentTypeJSON))
        httpHeaders.add(HTTPHeader.authorization(bearerToken: LibContext.shared.authProvider.getAuthToken()))
        httpHeaders.add(HTTPHeader.init(name: "panelist_id", value: LibContext.shared.authProvider.getPanelistID()))
        
        switch self.requestMethod {
        case .get:
            executeGet(url, httpHeaders, completionHandler)
        case .post:
            executePost(url, httpHeaders, completionHandler)
        case .multipart:
            executeMultipartPost(url, httpHeaders, completionHandler)
        case .put:
            executePut(url, httpHeaders, completionHandler)
        case .delete: break
        }
    }
    
    func cancelAPI() {
        
    }
    
    private func executeGet(_ url: String,
                            _ headers: HTTPHeaders?,
                            _ completionHandler: @escaping (Any?, Error?) -> Void) {
        _ = AF.request(url, headers: headers)
            .validate(statusCode: 200..<300)
            .responseDecodable(of: T.self) { response in
                self.onResponse(response, completionHandler)
            }
    }
    
    private func executePost(_ url: String,
                             _ headers: HTTPHeaders?,
                             _ completionHandler: @escaping (Any?, Error?) -> Void) {
        guard let body = self.body else { return }
        
        _ = AF.request(url, method: .post, parameters: body, encoding: JSONEncoding.default, headers: headers)
            .validate(statusCode: 200..<300)
            .responseDecodable(of: T.self) { response in
                self.onResponse(response, completionHandler)
            }
    }
    
    private func executeMultipartPost(_ url: String,
                                      _ headers: HTTPHeaders?,
                                      _ completionHandler: @escaping (Any?, Error?) -> Void) {
        guard let multipartData = self.multipartFormClosure else { return }
        
        _ = AF.upload(multipartFormData:multipartData, to: url, headers: headers)
            .validate(statusCode: 200..<300)
            .responseDecodable(of: T.self) { response in
                self.onResponse(response, completionHandler)
            }
    }
    
    private func executePut(_ url: String,
                            _ headers: HTTPHeaders?,
                            _ completionHandler: @escaping (Any?, Error?) -> Void) {
        
        guard let body = self.body else { return }
        
        _ = AF.request(url, method: .put, parameters: body, encoding: JSONEncoding.default, headers: headers)
            .validate(statusCode: 200..<300)
            .responseDecodable(of: T.self) { response in
                self.onResponse(response, completionHandler)
            }
    }
    
    private func onResponse(_ response:DataResponse<T, AFError>,
                            _ completionHandler: @escaping (Any?, Error?) -> Void) {
        debugPrint("On Response:", response)
        let httpResponseCode = response.response?.statusCode
        if httpResponseCode == AuthErrorResponseCode {
            LibContext.shared.authProvider.refreshAuthToken() { authToken, error in
                if authToken != nil {
                    self.executeAPI(completionHandler: completionHandler)
                } else {
                    completionHandler(nil, error)
                }
            }
        } else {
            switch response.result {
            case let .success(result):
                completionHandler(result, nil)
            case let .failure(error):
                completionHandler(nil, error)
            }
        }
    }
}
    
