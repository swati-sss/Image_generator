//
//  LogEvent.swift
//  compass_sdk_ios
//
//  Created by Rakesh Shetty on 7/18/23.
//

import Foundation

class LogEvent: Codable {
    private let sessionId: String
    private let accountId: String
    private let act: String?
    private let name: String?
    private let context: String?
    private let data: LogEventData?
    private let payload: AnalyticsPayload?
    private let store: String?
    private let timestamp: Int?
    let eventType: EventType?
    private let workflowId: String?
    private let workflowType: String?
    private let workflowValue: String?

    init(sessionId: String = UserDefaultsStore().sessionId,
         accountId: String = DeviceInformation.getAccountId(),
         act: String? = nil,
         name: String? = nil,
         context: String? = LogIdentifier.context,
         eventType: EventType,
         data: LogEventData? = nil,
         payload: AnalyticsPayload? = nil,
         store: String? = Analytics.storeId,
         timestamp: Int? = Date().systemTimeMillis,
         workflowId: String? = Analytics.workflow?.id,
         workflowType: String? = Analytics.workflow?.type,
         workflowValue: String? = Analytics.workflow?.value) {
        self.sessionId = sessionId
        self.accountId = accountId
        self.act = act
        self.name = name
        self.context = context
        self.eventType = eventType
        self.data = data
        self.store = store
        self.timestamp = timestamp
        self.payload = payload
        self.workflowId = workflowId
        self.workflowType = workflowType
        self.workflowValue = workflowValue
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        accountId = try container.decode(String.self, forKey: .accountId)
        act = try container.decodeIfPresent(String.self, forKey: .act)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        context = try container.decodeIfPresent(String.self, forKey: .context)
        eventType = try container.decode(EventType.self, forKey: .eventType)
        data = try container.decodeIfPresent(LogEventData.self, forKey: .data)
        store = try container.decodeIfPresent(String.self, forKey: .store)
        timestamp = try container.decodeIfPresent(Int.self, forKey: .timestamp)
        workflowId = try container.decodeIfPresent(String.self, forKey: .workflowId)
        workflowType = try container.decodeIfPresent(String.self, forKey: .workflowType)
        workflowValue = try container.decodeIfPresent(String.self, forKey: .workflowValue)

        if let eventType {
            payload = LogEvent.decodePayload(for: eventType, from: container)
        } else {
            payload = nil
        }
    }

    enum CodingKeys: CodingKey {
        case sessionId
        case accountId
        case act
        case name
        case context
        case data
        case payload
        case store
        case timestamp
        case eventType
        case workflowId
        case workflowType
        case workflowValue
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.sessionId, forKey: .sessionId)
        try container.encode(self.accountId, forKey: .accountId)
        try container.encodeIfPresent(self.act, forKey: .act)
        try container.encodeIfPresent(self.name, forKey: .name)
        try container.encodeIfPresent(self.context, forKey: .context)
        try container.encodeIfPresent(self.data, forKey: .data)
        try container.encodeIfPresent(self.store, forKey: .store)
        try container.encodeIfPresent(self.timestamp, forKey: .timestamp)
        try container.encodeIfPresent(self.eventType, forKey: .eventType)
        try container.encodeIfPresent(workflowId, forKey: .workflowId)
        try container.encodeIfPresent(workflowType, forKey: .workflowType)
        try container.encodeIfPresent(workflowValue, forKey: .workflowValue)

        switch payload {
        case .baseAnalytics(let baseAnalytics):
            try container.encode(baseAnalytics, forKey: .payload)
        case .initialization(let initializationAnalytics):
            try container.encode(initializationAnalytics, forKey: .payload)
        case .heartbeat(let heartbeatAnalytics):
            try container.encode(heartbeatAnalytics, forKey: .payload)
        case .displayMap(let displayMapAnalytics):
            try container.encode(displayMapAnalytics, forKey: .payload)
        case .displayPin(let displayPinAnalytics):
            try container.encode(displayPinAnalytics, forKey: .payload)
        case .zoomInteraction(let zoomInteractionAnalytics):
            try container.encode(zoomInteractionAnalytics, forKey: .payload)
        case .floorSelection(let floorSelectionAnalytics):
            try container.encode(floorSelectionAnalytics, forKey: .payload)
        case .mapInteraction(let mapInteractionAnalytics):
            try container.encode(mapInteractionAnalytics, forKey: .payload)
        case .telemetry(let telemetryAnalytics):
            try container.encode(telemetryAnalytics, forKey: .payload)
        case .updateEvent(let updateEventAnalytics):
            try container.encode(updateEventAnalytics, forKey: .payload)
        case .navigation(let navigationAnalytics):
            try container.encode(navigationAnalytics, forKey: .payload)
        case .userDistance(let userDistanceAnalytics):
            try container.encode(userDistanceAnalytics, forKey: .payload)
        case .navigationError(let navigationErrorAnalytics):
            try container.encode(navigationErrorAnalytics, forKey: .payload)
        case .staticPath(let staticPathAnalytics):
            try container.encode(staticPathAnalytics, forKey: .payload)
        default:
            break
        }
    }
}

extension LogEvent: Equatable {
        static func == (lhs: LogEvent, rhs: LogEvent) -> Bool {
        return lhs.sessionId == rhs.sessionId
    }
}

extension LogEvent {
//    func toLogPayload() -> [String: Encodable] {
//        var logPayload: [String: Encodable] = [
//            "sessionId": sessionId,
//            "act": act,
//            "name": name,
//            "context": context,
//            "eventType": eventType,
//            "store": store,
//            "timestamp": timestamp
//        ]
//
//        if data != nil {
//            logPayload.updateValue(data, forKey: "data")
//        }
//
//        guard let payload = self.payload else {
//            return logPayload
//        }
//
//        switch payload {
//        case .baseAnalytics(let baseAnalytics):
//            logPayload.updateValue(baseAnalytics, forKey: "payload")
//        case .initialization(let initializationAnalytics):
//            logPayload.updateValue(initializationAnalytics, forKey: "payload")
//        case .heartbeat(let heartbeatAnalytics):
//            logPayload.updateValue(heartbeatAnalytics, forKey: "payload")
//        case .displayMap(let displayMapAnalytics):
//            logPayload.updateValue(displayMapAnalytics, forKey: "payload")
//        case .displayPin(let displayPinAnalytics):
//            logPayload.updateValue(displayPinAnalytics, forKey: "payload")
//        }
//        return logPayload
//    }
//
//    func convertToLogEventData(_ logEventModel: LogEventModel) {
//        guard let data = try? JSONEncoder().encode(self) else { return }
//        logEventModel.payload = data
//        logEventModel.timeStamp = Int64(Date().systemTimeMillis)
//    }

    func convertToAnalyticsEventData(_ analyticsEventModel: AnalyticsEventModel) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        analyticsEventModel.payload = data
        analyticsEventModel.timeStamp = Int64(Date().systemTimeMillis)
    }

    var debugSessionId: String {
        sessionId
    }

    var debugTimestamp: Int? {
        timestamp
    }

    var debugEventTypeName: String {
        eventType?.rawValue ?? "unknown"
    }
}

private extension LogEvent {
    // swiftlint:disable:next cyclomatic_complexity
    static func decodePayload(for eventType: EventType,
                              from container: KeyedDecodingContainer<CodingKeys>) -> AnalyticsPayload? {
        switch eventType {
        case .initialization:
            if let object = try? container.decodeIfPresent(InitializationAnalytics.self, forKey: .payload) {
                return AnalyticsPayload.initialization(object)
            }
        case .heartBeat:
            if let object = try? container.decodeIfPresent(HeartbeatAnalytics.self, forKey: .payload) {
                return AnalyticsPayload.heartbeat(object)
            }
        case .displayPin:
            if let object = try? container.decodeIfPresent(DisplayPinAnalytics.self, forKey: .payload) {
                return AnalyticsPayload.displayPin(object)
            }
        case .displayMap:
            if let object = try? container.decodeIfPresent(DisplayMapAnalytics.self, forKey: .payload) {
                return AnalyticsPayload.displayMap(object)
            }
        case .zoomInteraction:
            if let object = try? container.decodeIfPresent(ZoomInteractionAnalytics.self, forKey: .payload) {
                return AnalyticsPayload.zoomInteraction(object)
            }
        case .floorSelection:
            if let object = try? container.decodeIfPresent(FloorSelectionAnalytics.self, forKey: .payload) {
                return AnalyticsPayload.floorSelection(object)
            }
        case .mapInteraction:
            if let object = try? container.decodeIfPresent(MapInteractionAnalytics.self, forKey: .payload) {
                return AnalyticsPayload.mapInteraction(object)
            }
        case .telemetry:
            if let object = try? container.decodeIfPresent(TelemetryAnalytics.self, forKey: .payload) {
                return AnalyticsPayload.telemetry(object)
            }
        case .updateEvent:
            if let object = try? container.decodeIfPresent(EventAnalytics.self, forKey: .payload) {
                return AnalyticsPayload.updateEvent(object)
            }
        case .navigation:
            if let object = try? container.decodeIfPresent(NavigationAnalytics.self, forKey: .payload) {
                return AnalyticsPayload.navigation(object)
            }
        case .getUserDistance:
            if let object = try? container.decodeIfPresent(UserDistanceAnalytics.self, forKey: .payload) {
                return AnalyticsPayload.userDistance(object)
            }
        case .navigationError:
            if let object = try? container.decodeIfPresent(NavigationErrorAnalytics.self, forKey: .payload) {
                return AnalyticsPayload.baseAnalytics(object)
            }
        case .staticPath:
            if let object = try? container.decodeIfPresent(StaticPathAnalytics.self, forKey: .payload) {
                return AnalyticsPayload.staticPath(object)
            }
        default:
            if let object = try? container.decodeIfPresent(BaseAnalytics.self, forKey: .payload) {
                return AnalyticsPayload.baseAnalytics(object)
            }
        }
        return nil
    }
}

extension Date {
    var systemTimeMillis: Int {
        Int(timeIntervalSince1970 * 1000)
    }
}
