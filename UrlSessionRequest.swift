//
//  URLSessionRequest.swift
//  compass_sdk_ioss
//
//  Created by Rakesh Shetty on 9/23/22.
//

import Combine
import Foundation

final class URLSessionRequest<T: Decodable>: URLSessionRequestType {
    var urlString: String
    var method: HTTPMethod
    var parameters: HashMap?
    var urlComponentParameters: HashMap?
    var headers: [String: String]
    var urlComponents: URLComponents?
    var urlSession: URLSessionType

    required init(urlString: String,
                  method: HTTPMethod,
                  parameters: HashMap? = nil,
                  urlComponentParameters: [Int: [String]] = [:],
                  headers: [String: String] = [:],
                  urlSession: URLSessionType) {
        self.urlString = urlString
        self.method = method
        self.parameters = parameters
        self.headers = headers
        self.urlSession = urlSession
        addQueryItems(with: urlComponentParameters)
    }

    func execute() -> AnyPublisher<T?, Error> {
        var dataTask: URLSessionDataTask?
        do {
            let  urlRequest = try self.createURLRequest(method: method, headers: headers)
            let requestID = String(UUID().uuidString.prefix(8))
            let bodyData = urlRequest.httpBody
            let bodyHash = bodyData?.fnv1a64Hex ?? "no-body"
            let bodySize = bodyData?.count ?? 0
            let isAnalyticsRequest = (urlRequest.url?.absoluteString.contains("/analytics/allspark") ?? false)
            let analyticsBatchTimestamp = extractAnalyticsBatchTimestamp(from: bodyData)
            let analyticsEventCount = extractAnalyticsEventCount(from: bodyData)
            var attempt = 0
            return Deferred {
                Future<T?, Error> { [weak self] promise in
                    attempt += 1
                    let currentAttempt = attempt
                    if isAnalyticsRequest {
                        Log.info("""
                                 - Analytics Request Attempt -
                                 RequestId: \(requestID)
                                 Attempt: \(currentAttempt)
                                 URL: \(String(describing: urlRequest.url))
                                 BodyBytes: \(bodySize)
                                 BodyHash: \(bodyHash)
                                 BatchTimestamp: \(analyticsBatchTimestamp)
                                 EventCount: \(analyticsEventCount)
                                 """)
                    }
                    let dataTask = self?.urlSession
                        .createDataTask(with: urlRequest) { data, response, error in
                            let nsError = error as NSError?
                            Log.info("""
                                     - Response Info -
                                     RequestId: \(requestID)
                                     Attempt: \(currentAttempt)
                                     URL: \(String(describing: urlRequest.url))
                                     Response: \(String(describing: response)),
                                     Error: \(String(describing: error)),
                                     ErrorDomain: \(nsError?.domain ?? "nil"),
                                     ErrorCode: \(nsError?.code ?? 0),
                                     BodyHash: \(bodyHash),
                                     BatchTimestamp: \(analyticsBatchTimestamp),
                                     EventCount: \(analyticsEventCount),
                                     Data: \(String(describing: (data?.prettyPrintedJSONString)))
                                     """)
                            if let error = error {
                                promise(.failure(ErrorResponse(errorCode: -1, error: error)))
                                return
                            }

                            guard let httpResponse  = response as? HTTPURLResponse else {
                                promise(.failure(ErrorResponse(errorCode: -2,
                                                               error: WebAPIRequestError.nilHTTPResponse)))
                                return
                            }

                            guard httpResponse.isStatusCodeSuccessFull else {
                                var data = data
                                let config = StaticStorage.storeConfig
                                let shouldLogSensitiveInfo = config?.debugLog?.sensitiveInfoEnabled ?? false
                                if shouldLogSensitiveInfo {
                                    data = nil
                                }
                                promise(.failure(ErrorResponse(response: httpResponse,
                                                               error: WebAPIRequestError.unsuccessfulHTTPStatusCode,
                                                               data: data)))
                                return
                            }

                            switch T.self {
                            case is String.Type:
                                let body = data.map { String(data: $0, encoding: .utf8) }
                                promise(.success(body as? T))
                            case is Void.Type:
                                promise(.success(nil))
                            default:
                                guard let data = data, !data.isEmpty else {
                                    promise(.failure(ErrorResponse(response: httpResponse,
                                                                   error: WebAPIRequestError.emptyDataResponse)))
                                    return
                                }

                                let decodeResult = CodableHelper.decode(T.self, from: data)
                                switch decodeResult {
                                case let .success(decodableObj):
                                    promise(.success(decodableObj))
                                case let .failure(error):
                                    promise(.failure(ErrorResponse(response: httpResponse, error: error, data: data)))
                                }
                            }
                        }
                    dataTask?.resume()
                }
                .handleEvents(receiveCancel: {
                    dataTask?.cancel()
                    dataTask = nil
                })
            }
            .eraseToAnyPublisher()
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
    }
}

private extension URLSessionRequest {
    func createURLRequest(method: HTTPMethod, headers: [String: String]) throws -> URLRequest {
        guard let url = URL(string: urlString) else {
            throw WebAPIRequestError.requestMissingURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue

        headers.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        let encoding = JSONDataEncoding()

        if let urlComponents = urlComponents {
            urlRequest = encoding.encode(urlRequest, with: urlComponents)
        } else {
            urlRequest = encoding.encode(urlRequest, with: parameters)
        }

        let headersSummary = formatHeadersForLogging(headers)
        Log.info("""
                 - Request Info -
                 URL: \(String(describing: urlRequest.url))
                 Method: \(urlRequest.httpMethod ?? "GET")
                 Body: \(String(data: urlRequest.httpBody ?? Data(), encoding: .utf8) ?? "nil")
                 Headers Used:
                 \(headersSummary)
                 """)

        return urlRequest
    }

    func formatHeadersForLogging(_ headers: [String: String]) -> String {
        let displayKeys = [
            RequestIdentifier.consumerId.rawValue,
            RequestIdentifier.wmConsumerId.rawValue,
            RequestIdentifier.clientId.rawValue,
            "Content-Type"
        ]

        return headers
            .sorted { $0.key.lowercased() < $1.key.lowercased() }
            .map { key, value in
                let shouldDisplay = displayKeys.contains { $0.lowercased() == key.lowercased() }
                return "\(key): \(shouldDisplay ? value : "***")"
            }
            .joined(separator: "\n")
    }

    func addQueryItems(with parameters: [Int: [String]]?) {
        guard let parameters = parameters, !parameters.isEmpty else {
            urlComponents = nil
            return
        }
        urlComponents = URLComponents()
        urlComponents?.queryItems = parameters.sorted { $0.key < $1.key }
            .map { URLQueryItem(name: $0.value[0], value: $0.value[1]) }
    }

    func extractAnalyticsBatchTimestamp(from body: Data?) -> String {
        guard let body,
              let jsonObject = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let batchTimestamp = jsonObject["batchTimestamp"] else {
            return "n/a"
        }
        return String(describing: batchTimestamp)
    }

    func extractAnalyticsEventCount(from body: Data?) -> String {
        guard let body,
              let jsonObject = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let events = jsonObject["events"] as? [Any] else {
            return "n/a"
        }
        return String(events.count)
    }
}
