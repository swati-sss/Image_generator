//
//  NetworkService.swift
//  compass_sdk_ios
//
//  Created by Pratik Patel on 5/15/24.
//

import Combine
import Foundation

protocol NetworkServiceType {
    init(urlSession: URLSessionType)
    func getConfigData(for storeId: String) -> AnyPublisher<ConfigurationResponse?, Error>
    func getTokenData(for clientId: String, consumerId: String) -> AnyPublisher<AccessTokenResponse?, Error>
    func getAsset(for assetId: String, storeId: Int) -> AnyPublisher<AssetResponse?, Error>
    func getAisle(for assetId: String?, storeId: Int, position: CGPoint) -> AnyPublisher<AssetResponse?, Error>
    func getFeatureLocation(aisleIds: [String], storeId: Int) -> AnyPublisher<FeatureLocationResponse?, Error>
    func uploadAnalyticsEventBatch(_ eventBatch: AnalyticsEventBatch) -> AnyPublisher<LogEventResponse?, Error>
//    func uploadLogEventBatch(_ eventBatch: AnalyticsEventBatch) -> AnyPublisher<LogEventResponse?, Error> {
    func addEvent(_ event: CompassEvent,
                  position: CGPoint,
                  storeId: Int,
                  userId: String,
                  sessionId: String) -> AnyPublisher<PinCreateResponse?, Error>
}

class NetworkService: NetworkServiceType {
    private let urlSession: URLSessionType
    private var headers: [String: String] {
        APIHelper.getStandardRequestHeaders()
    }

    required init(urlSession: URLSessionType = URLSession.shared) {
        self.urlSession = urlSession
    }

    func getTokenData(for clientId: String, consumerId: String) -> AnyPublisher<AccessTokenResponse?, Error> {
        let urlString = APIPath.accessTokenAPI

        let queryParams: [Int: [String]] = [
            1: [RequestIdentifier.grantType.rawValue, RequestIdentifier.clientCredentials.rawValue],
            2: [RequestIdentifier.clientId.rawValue, consumerId],
            3: [RequestIdentifier.clientSecret.rawValue, clientId]
        ]

        let requestHeaders = [
            RequestIdentifier.contentType.rawValue: RequestIdentifier.applicationXUrlEncoded.rawValue,
            RequestIdentifier.wmConsumerId.rawValue: consumerId
        ]

        return URLSessionRequest<AccessTokenResponse>(urlString: urlString,
                                                      method: .post,
                                                      urlComponentParameters: queryParams,
                                                      headers: requestHeaders,
                                                      urlSession: urlSession)
        .execute()
    }

    func getConfigData(for storeId: String) -> AnyPublisher<ConfigurationResponse?, Error> {
        var urlString = APIPath.configurationAPI
        var consumerId: String = ""
        if let authParam = StaticStorage.authParameter {
            consumerId = authParam.consumerID
        }
        let timestamp = String(Int(1000 * Date().timeIntervalSince1970))
        urlString.substituteQueryParams([.storeId: storeId, .consumerId: consumerId, .timestamp: timestamp])
        return URLSessionRequest<ConfigurationResponse>(urlString: urlString,
                                                        method: .get,
                                                        headers: headers,
                                                        urlSession: urlSession)
        .execute()
    }

    func getAsset(for assetId: String, storeId: Int) -> AnyPublisher<AssetResponse?, Error> {
        var urlString = APIPath.assetAPI
        urlString.substituteQueryParams([.storeId: storeId, .assetId: assetId])
        return URLSessionRequest<AssetResponse>(urlString: urlString,
                                                method: .get,
                                                headers: headers,
                                                urlSession: urlSession)
        .execute()
    }

    func getFeatureLocation(
        aisleIds: [String],
        storeId: Int
    ) -> AnyPublisher<FeatureLocationResponse?, Error> {
        var urlString = APIPath.featureLocationAPI
        urlString.substituteQueryParams(
            [.storeId: storeId, .assetids: aisleIds]
        )
        return URLSessionRequest<FeatureLocationResponse>(urlString: urlString,
                                                          method: .get,
                                                          headers: headers,
                                                          urlSession: urlSession)
        .execute()
    }

    func getAisle(for assetId: String?, storeId: Int, position: CGPoint) -> AnyPublisher<AssetResponse?, Error> {
        let assetidQueryString = "asset_id={assetid}&"

        // Remove the asset Id parameter from url query string for the generic type
        var urlString = (assetId != nil) ?
            APIPath.aisleAPI : APIPath.aisleAPI.replacingOccurrences(of: assetidQueryString, with: "")

        urlString.substituteQueryParams([
            .storeId: storeId,
            .assetId: assetId ?? "",
            .positionX: position.x,
            .positionY: position.y
        ])

        return URLSessionRequest<AssetResponse>(urlString: urlString,
                                                method: .get,
                                                headers: headers,
                                                urlSession: urlSession)
        .execute()
    }

    func addEvent(_ event: CompassEvent,
                  position: CGPoint,
                  storeId: Int,
                  userId: String,
                  sessionId: String) -> AnyPublisher<PinCreateResponse?, Error> {
        let urlString = APIPath.eventAPI
        let timestamp = Int(1000 * Date().timeIntervalSince1970)
        let authParam: AuthParameter? = StaticStorage.authParameter
        let eventLocationRoc = EventLocationRoc(x: position.x, y: position.y)
        let eventLocation = EventLocation(storeId: String(storeId), roc: eventLocationRoc)
        let event = Event(eventId: RequestIdentifier.id1.rawValue,
                          eventType: event.eventType,
                          eventValue: event.eventValue)
        let eventData = EventData(userId: userId,
                                  clientId: authParam?.accountID ?? "",
                                  sessionId: sessionId,
                                  timestamp: timestamp,
                                  location: eventLocation,
                                  event: event)
        return URLSessionRequest<PinCreateResponse>(urlString: urlString,
                                                    method: .post,
                                                    parameters: eventData.jsonEncodedParameters(),
                                                    headers: headers,
                                                    urlSession: urlSession)
        .execute()
    }

    func uploadAnalyticsEventBatch(_ eventBatch: AnalyticsEventBatch) -> AnyPublisher<LogEventResponse?, Error> {
        let eventPayloads: [LogEvent] = eventBatch.events.compactMap {
            guard let payload = $0.payload, let event = try? JSONDecoder().decode(LogEvent.self, from: payload) else {
                return nil
            }
            return event
        }

        let eventBody = EventBody(events: eventPayloads, deviceInformation: DeviceInformation.current)
        Log.info("Prepared analytics batch for request. \(analyticsDebugSummary(for: eventBatch.events, decodedEvents: eventPayloads, batchTimestamp: eventBody.batchTimestamp))")

        if let jsontring = eventBody.toJSONString() {
            let data = Data(jsontring.utf8)
            Log.info("Uploading AnalyticsEvent: \(data.prettyPrintedJSONString)")
        }

        return URLSessionRequest<LogEventResponse>(urlString: APIPath.analyticsAPI,
                                                   method: .post,
                                                   parameters: eventBody.jsonEncodedParameters(),
                                                   headers: headers,
                                                   urlSession: urlSession)
        .execute()
    }

//    func uploadLogEventBatch(_ eventBatch: EventBatch) -> AnyPublisher<LogEventResponse?, Error> {
//        let eventPayloads: [LogEvent] = eventBatch.events.compactMap {
//            guard let payload = $0.payload, let event = try? JSONDecoder().decode(LogEvent.self, from: payload) else {
//                return nil
//            }
//            return event
//        }
//
//        let eventBody = EventBody(events: eventPayloads)
//        URLSessionRequest<LogEventResponse>(urlString: APIPath.logAPI,
//                                            method: .post,
//                                            parameters: eventBody.jsonEncodedParameters(),
//                                            headers: headers,
//                                            urlSession: urlSession)
//        .execute()
//    }
}

private extension NetworkService {
    func analyticsDebugSummary(for rows: [AnalyticsEventModel],
                               decodedEvents: [LogEvent],
                               batchTimestamp: Int) -> String {
        let sessionIds = decodedEvents.map(\.debugSessionId)
        let eventTypeCounts = Dictionary(grouping: decodedEvents, by: \.debugEventTypeName)
            .mapValues(\.count)
        let eventTimestamps = decodedEvents.compactMap(\.debugTimestamp)
        let rowTimestamps = rows.map(\.timeStamp)

        return """
        batchTimestamp=\(batchTimestamp), rows=\(rows.count), decoded=\(decodedEvents.count), decodeFailures=\(rows.count - decodedEvents.count), \
        rowTimeStampRange=\(format(range: rowTimestamps.map(Int.init))), eventTimeRange=\(format(range: eventTimestamps)), \
        uniqueSessions=\(sessionIds.count == 0 ? 0 : Set(sessionIds).count) \(summarize(values: sessionIds)), \
        eventTypes=\(format(counts: eventTypeCounts))
        """
    }

    func format(counts: [String: Int]) -> String {
        guard !counts.isEmpty else { return "[]" }
        let values = counts.keys.sorted().map { "\($0):\(counts[$0] ?? 0)" }
        return "[" + values.joined(separator: ", ") + "]"
    }

    func summarize(values: [String], maxItems: Int = 4) -> String {
        let uniqueValues = Array(Set(values)).sorted()
        guard !uniqueValues.isEmpty else { return "[]" }
        let preview = uniqueValues.prefix(maxItems).joined(separator: ", ")
        return uniqueValues.count > maxItems ? "[\(preview), +\(uniqueValues.count - maxItems) more]" : "[\(preview)]"
    }

    func format(range values: [Int]) -> String {
        guard let minValue = values.min(), let maxValue = values.max() else { return "n/a" }
        return minValue == maxValue ? "\(minValue)" : "\(minValue)...\(maxValue)"
    }
}
