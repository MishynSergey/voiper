

import Foundation
import PromiseKit
import Alamofire

protocol ServiceProtocol {
    var configuration: ServiceConfig { get }
    var headers: HTTPHeaders { get }
    var retry: Int { get set }
    
    init(_ configuration: ServiceConfig)
    func execute<Response: Decodable & CustomStringConvertible>(_ request: API) -> Promise<Response>
}

public class Service: ServiceProtocol {
    public static let shared = {
        return Service(ServiceConfig.appConfig())
    }()
    
    var configuration: ServiceConfig
    var headers: HTTPHeaders
    var retry: Int
    
    required init(_ configuration: ServiceConfig) {
        self.configuration = configuration
        self.headers = ["Content-Type": "application/json"]
        self.retry = 2
    }
    
    func execute<Response: Decodable & CustomStringConvertible>(_ api: API) -> Promise<Response> {
        return firstly {
            checkAuthorize(for: api)
            }
            .then { _ -> Promise<DataRequest> in
                return self.requestPromise(for: api)
            }.then { (request: DataRequest) -> Promise<Response> in
                return Promise<Response> { seal in
                    self.handle(request: request, for: api, with: seal)
                }
        }
    }
    
    func executeMultipart<Response: Decodable & CustomStringConvertible>(_ api: API, multipartFormData: @escaping (MultipartFormData) -> Void) -> Promise<Response> {
        return firstly {
            checkAuthorize(for: api)
                .then { _ -> Promise<Response> in
                    return Promise<Response> { seal in
                        let request = AF.upload(multipartFormData: multipartFormData,
                                                to: self.requestURL(for: api),
                                                headers: self.headers(for: api))
                        request.uploadProgress(closure: { (progress) in
                            print("Upload Progress: \(progress.fractionCompleted)")
                        })
                        self.handle(request: request, for: api, with: seal)
                    }
            }
        }
    }
    
    private func handle<Response: Decodable & CustomStringConvertible>(request: DataRequest, for api: API, with seal: Resolver<Response>) {
        request.validate().responseData(queue: self.queue) { response in
            switch response.result {
            case .failure(let error):
                print(error)
                if let data = response.data {
                    print(String(data: data, encoding: .utf8) ?? "Undefined Error Data")
                    let decoder = JSONDecoder()
                    if let code = response.response?.statusCode,
                        code == 401 {
                        seal.reject(ServiceError.notAuthorized)
                    } else if let errorObject = try? decoder.decode(ErrorResponse.self, from: data) {
                        print("Response: \(api.endpoint)\nError: " + errorObject.description)
                        seal.reject(ServiceError.networkError(api, response.response?.statusCode ?? 0, errorObject.error))
                    } else {
                        seal.reject(ServiceError.other(error))
                    }
                    
                } else {
                    seal.reject(ServiceError.undefined)
                }
            case .success(let data):
                let decoder = JSONDecoder.serviceDecoder
                do {
                    let decodedObject = try decoder.decode(Response.self, from: data)
                    print("Response: \(api.endpoint)\nBody: \(decodedObject.description)")
                    seal.fulfill(decodedObject)
                } catch {
                    print("Can't decode response \(error)")
                    seal.reject(ServiceError.undecodable)
                }
            }
        }
    }
    
    private func checkAuthorize(for api:API) -> Promise<Void> {
        if api.shouldAuthorize {
            if Settings.userToken != nil {
                return Promise.value(())
            } else {
                return Promise(error: ServiceError.notAuthorized)
            }
        } else {
            return Promise.value(())
        }
    }
    
    private var queue = DispatchQueue.global(qos: .default)
    
    private func requestPromise(for api: API) -> Promise<DataRequest> {
        let request = AF.request(requestURL(for: api),
                                        method: httpMethod(for: api),
                                        parameters: parameters(for: api),
                                        encoding: encoding(for: api),
                                        headers: headers(for: api))
        
        print(request.description)
        return Promise<DataRequest>.value(request)
    }
    
    private func requestURL(for api: API) -> URL {
        return configuration.baseURL.appendingPathComponent(api.endpoint, isDirectory: true)
    }
    
    private func parameters(for api: API) -> [String : Any] {
        var parameters: [String: Any] = api.parameters
        commonParameters().forEach({ (key: String, value: Any) in
            parameters[key] = value
        })
        return parameters
    }
    
    private func httpMethod(for api: API) -> HTTPMethod {
        switch api.method {
        case .get:      return .get
        case .post:     return .post
        case .patch:    return .patch
        case .delete:   return .delete
        case .put:      return .put
        }
    }
    
    private func encoding(for api: API) -> ParameterEncoding {
        switch api.method {
        case .get,
             .patch,
             .delete:       return URLEncoding()
        case .post,
             .put:          return JSONEncoding()
        }
    }
    
    private func headers(for api: API) -> HTTPHeaders {
        var headers = self.headers
        if api.shouldAuthorize {
            headers["Authorization"] = "OAuth \(Settings.userToken ?? "")"
        }
        api.headers.forEach {
            headers.update($0)
        }
        
        return headers
    }
    
    private func commonParameters() -> [String: Any] {
        return [:]
    }
}
