//
//  NetworkClient.swift
//  OrderScrapper
//

import Foundation
import Alamofire
import Sentry

enum RequestMethod {
    case get, post, put, delete, multipart
}

class APIError: Error {
    let errorMessage: String
    
    init(error: String) {
        self.errorMessage = error
    }
}

class NetworkClient<T: Codable>: APIClient {
    private let AuthErrorResponseCode = 401
    private let ServiceDownResponseCode = 500
    private let BaseURL = LibContext.shared.orderExtractorConfig.baseURL
    private let HeaderContentType = "Content-Type"
    
    var ContentTypeJSON = "application/json"
    var relativeURL: String
    var requestMethod: RequestMethod
    var headers: [String: String]?
    var body: [String: Any]?
    var multipartFormClosure: ((MultipartFormData) -> Void)?
    
    required init(relativeURL url: String, requestMethod method: RequestMethod) {
        self.relativeURL = url
        self.requestMethod = method
    }
    
    required init(relativeURL url: String, requestMethod method: RequestMethod, contentType type:String) {
        self.relativeURL = url
        self.requestMethod = method
        self.ContentTypeJSON = type
    }
    
    func executeAPI(completionHandler: @escaping (Any?, ASLException?) -> Void) {
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
                            _ completionHandler: @escaping (Any?, ASLException?) -> Void) {
        _ = AF.request(url, headers: headers)
            .validate(statusCode: 200..<300)
            .responseDecodable(of: T.self) { response in
                self.onResponse(response, completionHandler)
            }
    }
    
    private func executePost(_ url: String,
                             _ headers: HTTPHeaders?,
                             _ completionHandler: @escaping (Any?, ASLException?) -> Void) {
        guard let body = self.body else { return }
        
        _ = AF.request(url, method: .post, parameters: body, encoding: JSONEncoding.default, headers: headers)
            .validate(statusCode: 200..<300)
            .responseDecodable(of: T.self) { response in
                self.onResponse(response, completionHandler)
            }
    }
    
    private func executeMultipartPost(_ url: String,
                                      _ headers: HTTPHeaders?,
                                      _ completionHandler: @escaping (Any?, ASLException?) -> Void) {
        guard let multipartData = self.multipartFormClosure else { return }
        
        _ = AF.upload(multipartFormData:multipartData, to: url, headers: headers)
            .validate(statusCode: 200..<300)
            .responseDecodable(of: T.self) { response in
                self.onResponse(response, completionHandler)
            }
    }
    
    private func executePut(_ url: String,
                            _ headers: HTTPHeaders?,
                            _ completionHandler: @escaping (Any?, ASLException?) -> Void) {
        
        guard let body = self.body else { return }
        
        _ = AF.request(url, method: .put, parameters: body, encoding: JSONEncoding.default, headers: headers)
            .validate(statusCode: 200..<300)
            .responseDecodable(of: T.self) { response in
                self.onResponse(response, completionHandler)
            }
    }
    
    private func onResponse(_ response:DataResponse<T, AFError>,
                            _ completionHandler: @escaping (Any?, ASLException?) -> Void) {
        debugPrint("On Response:", response)
        let httpResponseCode = response.response?.statusCode
        if httpResponseCode == AuthErrorResponseCode {
            LibContext.shared.authProvider.refreshAuthToken() { authToken, error in
                if authToken != nil {
                    self.executeAPI(completionHandler: completionHandler)
                } else {
                    let asl = ASLException(error: error, errorMessage: "", failureType: .servicesDown)
                    completionHandler(nil, asl)
                    if let error = error {
                        FirebaseAnalyticsUtil.logSentryError(error: error)
                    }
                }
            }
        } else if let httpResponseCode = httpResponseCode, httpResponseCode >= ServiceDownResponseCode {
            let error = ASLException(error: nil, errorMessage: "", failureType: .servicesDown)
            completionHandler(nil, error)
        }else {
            switch response.result {
            case let .success(result):
                FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_APICall\(relativeURL)")

                completionHandler(result, nil)
            case let .failure(error):
                FirebaseAnalyticsUtil.logSentryMessage(message: "Blackstraw_APICall\(relativeURL) \(error)")
                let asl = ASLException(error: error, errorMessage: "", failureType: nil)
                completionHandler(nil, asl)
                
                let panelistId = LibContext.shared.authProvider.getPanelistID()
                var logEventAttributes:[String:String] = [:]
                logEventAttributes = [EventConstant.PanelistID: panelistId,
                                      EventConstant.EventName: EventType.APIFailed,
                                      EventConstant.URL: relativeURL,
                                      EventConstant.Status: EventStatus.Failure]
                FirebaseAnalyticsUtil.logSentryError(eventAttributes: logEventAttributes, error: error)
            }
        }
    }
}
    
