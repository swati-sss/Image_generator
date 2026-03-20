//
//  Log.swift
//  LibConverseiOS
//
//  Created by Rakesh Shetty on 7/18/23.
//

import CoreData
import Combine

protocol LogDefault {
    init(logEventStoreService: LogEventStoreService, networkService: NetworkServiceType)
    func startTimer(coolOffPeriod: Double)
    func trackAnalyticsEvent(for logEvent: LogEvent)
}

final class LogDefaultImpl: LogDefault {
    /* // Splunk Log
     var logEventSubscription: AnyCancellable?
     var logUploadSubscription: AnyCancellable?
     */

    var analyticsEventSubscription: AnyCancellable?
    var analyticsUploadSubscription: AnyCancellable?

    private var cancellable: [AnyCancellable] = []
    private var logEventStoreService: LogEventStoreService
    private let eventBatchFactory: EventBatchFactory
    private let networkService: NetworkServiceType
    private let uploadExecutionQueue: DispatchQueue
    private var requestTimer: Timer?

    init(logEventStoreService: LogEventStoreService, networkService: NetworkServiceType) {
        self.logEventStoreService = logEventStoreService
        self.networkService = networkService
        eventBatchFactory = EventBatchFactory()
        uploadExecutionQueue = DispatchQueue.global(qos: .background)
    }

    func startTimer(coolOffPeriod: Double = LogConstants.uploadCoolOfPeriod.rawValue) {
        Log.info("Starting analytics upload timer. batchIntervalSeconds=\(Log.batchInterval), coolOffSeconds=\(coolOffPeriod)")
        requestTimer = .scheduledTimer(withTimeInterval: Log.batchInterval, repeats: true) { [weak self] _ in
            self?.scheduleNextUploadIfRequired(coolOffPeriod: coolOffPeriod)
        }
    }

    func trackAnalyticsEvent(for logEvent: LogEvent) {
        analyticsEventSubscription?.cancel()
        analyticsEventSubscription = saveAnalyticsEvent(logEvent)
            .sink { _ in }
    }

    /* // Splunk Log
     func trackEvent(for logEvent: LogEvent) {
     logEventSubscription?.cancel()
     logEventSubscription = saveLogEvent(logEvent)
     .sink { _ in }
     }
     */

    deinit {
        requestTimer?.invalidate()
        requestTimer = nil
        Log.info("Released LogDefaultImpl")
    }
}

private extension LogDefaultImpl {
    func scheduleNextUploadIfRequired(coolOffPeriod: Double) {
        Log.info("Analytics upload timer fired. batchIntervalSeconds=\(Log.batchInterval), coolOffSeconds=\(coolOffPeriod)")
        analyticsUploadSubscription?.cancel()
        analyticsUploadSubscription = getAnalyticsEvent()
            .sink { [weak self] analyticsEvents in
                self?.uploadExecutionQueue.asyncAfter(deadline: .now() + coolOffPeriod) { [weak self] in
                    self?.uploadAnalyticsEvents(analyticsEvents)
                }
            }

        /* // Splunk Log
         logUploadSubscription?.cancel()
         logUploadSubscription = getLogEvent()
         .sink { [weak self] events in
         guard let self else {
         return
         }
         self.uploadExecutionQueue.asyncAfter(deadline: .now() + coolOffPeriod) { [weak self] in
         guard let self else {
         return
         }
         self.uploadLogEvents(events)
         }
         }
         */
    }

    func saveAnalyticsEvent(_ logEvent: LogEvent) -> AnyPublisher<AnalyticsEventModel, Never> {
        logEventStoreService.setAnalyticsData(logEvent)
            .retry()
            .catch { error -> AnyPublisher<AnalyticsEventModel, Never> in
                Log.error(error)
                return Empty(completeImmediately: true).eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func getAnalyticsEvent() -> AnyPublisher<[AnalyticsEventModel], Never> {
        logEventStoreService.getAnalyticsData()
            .retry()
            .handleEvents(receiveOutput: { [weak self] events in
                guard let self else { return }
                Log.info("Fetched analytics queue snapshot. \(self.analyticsSummary(for: events))")
            }, receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    Log.error("Failed to fetch analytics queue: \(error)")
                }
            })
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func uploadAnalyticsEvents(_ events: [AnalyticsEventModel]) {
        guard !events.isEmpty else {
            Log.info("No analytics events to upload.")
            return
        }

        let batches = eventBatchFactory.generateAnalyticsBatches(events: events)
        let batchSizes = batches.map { $0.events.count }
        Log.info("Starting analytics upload cycle. queuedRows=\(events.count), totalBatches=\(batches.count), batchSizes=\(batchSizes)")
        Publishers.Sequence(sequence: batches)
            .flatMap { [weak self] batch -> AnyPublisher<Void, Never> in
                guard let self else {
                    return Empty().eraseToAnyPublisher()
                }

                let batchSummary = self.analyticsSummary(for: batch.events)
                Log.info("Submitting analytics batch. \(batchSummary)")
                return self.networkService.uploadAnalyticsEventBatch(batch)
                    .retry()
                    .catch { error -> AnyPublisher<LogEventResponse?, Never> in
                        Log.error("Failed to upload analytics batch after retries. \(batchSummary). Batch remains queued. Error: \(error)")
                        return Empty().eraseToAnyPublisher()
                    }
                    .flatMap { response -> AnyPublisher<Void, Never> in
                        guard response != nil else {
                            Log.warning("Analytics batch publisher returned nil response. Skipping deletion. \(batchSummary)")
                            return Empty().eraseToAnyPublisher()
                        }

                        Log.info("Analytics batch upload acknowledged. Deleting stored rows. \(batchSummary)")
                        let deletionPublishers = batch.events.map { event in
                            self.logEventStoreService.deleteAnalyticsData(event.timeStamp)
                                .retry()
                                .catch { error -> AnyPublisher<Void, Never> in
                                    Log.error("Failed to delete event \(event.timeStamp): \(error)")
                                    return Empty().eraseToAnyPublisher()
                                }
                        }

                        return Publishers.MergeMany(deletionPublishers)
                            .collect()
                            .map { _ in
                                Log.info("Finished deleting analytics batch rows. deletedRows=\(batch.events.count), deletedLocalTimeStamps=\(batch.events.map(\.timeStamp))")
                            }
                            .eraseToAnyPublisher()
                    }.eraseToAnyPublisher()
            }
            .sink { _ in }
            .store(in: &cancellable)
    }

    /*// Splunk Log
     func saveLogEvent(_ logEvent: LogEvent) -> AnyPublisher<LogEventModel, Never> {
     logEventStoreService.setLog(logEvent)
     .retry()
     .catch { error -> AnyPublisher<LogEventModel, Never> in
     Log.error(error)
     return Empty(completeImmediately: true).eraseToAnyPublisher()
     }
     .receive(on: DispatchQueue.main)
     .eraseToAnyPublisher()
     }

     func getLogEvent() -> AnyPublisher<[LogEventModel], Never> {
     logEventStoreService.getLog()
     .retry()
     .replaceError(with: [])
     .receive(on: DispatchQueue.main)
     .eraseToAnyPublisher()
     }

     private func uploadLogEvents(_ events: [LogEventModel]) {
     Publishers.Sequence(sequence: eventBatchFactory.generateLogBatches(events: events))
     .flatMap { [weak self] batch -> AnyPublisher<Void, Never> in
     guard let self else { return Empty().eraseToAnyPublisher() }
     return self.networkService.uploadLogEventBatch(batch)
     .retry()
     .catch { error -> AnyPublisher<LogEventResponse?, Never> in
     Log.error("Error uploading log batch: \(error)")
     return Empty().eraseToAnyPublisher()
     }
     .receive(on: DispatchQueue.main)
     .flatMap { _ -> AnyPublisher<Void, Never> in
     Publishers.Sequence(sequence: batch.events)
     .flatMap { [weak self] event -> AnyPublisher<Void, Never> in
     guard let self else { return Empty().eraseToAnyPublisher() }
     return self.logEventStoreService.deleteLog(event.timeStamp)
     .retry()
     .receive(on: DispatchQueue.main)
     .catch { error -> AnyPublisher<Void, Never> in
     Log.error("Error deleting logs: \(error)")
     return Empty().eraseToAnyPublisher()
     }.eraseToAnyPublisher()
     }.eraseToAnyPublisher()
     }.eraseToAnyPublisher()
     }
     .sink { _ in }
     .store(in: &cancellable)
     }
     */
}

private extension LogDefaultImpl {
    func analyticsSummary(for rows: [AnalyticsEventModel]) -> String {
        let decodedEvents = decodeLogEvents(from: rows)
        let eventTypeCounts = Dictionary(grouping: decodedEvents, by: \.debugEventTypeName)
            .mapValues(\.count)
        let sessionIDs = decodedEvents.map(\.debugSessionId)
        let eventTimestamps = decodedEvents.compactMap(\.debugTimestamp)
        let rowTimestamps = rows.map(\.timeStamp)

        return """
        rows=\(rows.count), decoded=\(decodedEvents.count), decodeFailures=\(rows.count - decodedEvents.count), \
        localRowTimeStampRange=\(format(range: rowTimestamps.map(Int.init))), eventTimeRange=\(format(range: eventTimestamps)), \
        uniqueSessions=\(sessionIDs.isEmpty ? 0 : Set(sessionIDs).count) \(summarize(values: sessionIDs)), \
        eventTypes=\(format(counts: eventTypeCounts))
        """
    }

    func decodeLogEvents(from rows: [AnalyticsEventModel]) -> [LogEvent] {
        rows.compactMap { row in
            guard let payload = row.payload else { return nil }
            return try? JSONDecoder().decode(LogEvent.self, from: payload)
        }
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

#if DEBUG
extension LogDefaultImpl {
    // Test helper: invoke upload pipeline with custom cool-off.
    func _test_scheduleNextUploadIfRequired(coolOffPeriod: Double) {
        scheduleNextUploadIfRequired(coolOffPeriod: coolOffPeriod)
    }

    // Test helper: surface analytics fetcher.
    func _test_getAnalyticsEvent() -> AnyPublisher<[AnalyticsEventModel], Never> {
        getAnalyticsEvent()
    }

    // Test helper: surface analytics uploader.
    func _test_uploadAnalyticsEvents(_ events: [AnalyticsEventModel]) {
        uploadAnalyticsEvents(events)
    }
}
#endif
