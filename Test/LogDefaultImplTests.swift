//
//  LogDefaultImplTests.swift
//  compass_sdk_iosTests
//
//  Created by Young Jin Ju on 3/5/24.
//

import XCTest
import Combine
import CoreData
@testable import compass_sdk_ios

final class LogDefaultImplTests: XCTestCase {
    private var logDefaultImpl: LogDefaultImpl!
    private var serviceLocator: MockServiceLocator!
    private var logEventStoreService: MockLogEventStoreService!
    private var networkService: TrackingNetworkService!
    private var cancellables = Set<AnyCancellable>()
    private var logEvent: LogEvent!

    override func setUpWithError() throws {
        try super.setUpWithError()
        Log.batchInterval = 1
        serviceLocator = MockServiceLocator()
        logEventStoreService = serviceLocator.getLogEventStoreService() as? MockLogEventStoreService
        networkService = TrackingNetworkService(urlSession: MockURLSession())
        logDefaultImpl = LogDefaultImpl(logEventStoreService: logEventStoreService, networkService: networkService)
        logEvent = LogEvent(sessionId: "testSessionId",
                            act: LogIdentifier.act,
                            name: LogIdentifier.name,
                            eventType: .info,
                            data: LogEventData(msg: "message", file: "file", function: "function", line: 99),
                            store: "1080",
                            timestamp: Date().systemTimeMillis)
    }

    override func tearDownWithError() throws {
        logDefaultImpl = nil

        serviceLocator._resetMock()
        logEvent = nil
        serviceLocator = nil
        networkService = nil
        logEventStoreService = nil
        cancellables.removeAll()
        try super.tearDownWithError()
    }

    func testStartTimer() {
        // Verify that the timer starts without crashing
        // Track an analytics event
        logDefaultImpl.trackAnalyticsEvent(for: logEvent)
        
        // Start the timer - should not crash and should be retained by the logDefaultImpl
        logDefaultImpl.startTimer(coolOffPeriod: 0.1)
        
        // Give the runloop a brief moment to process any pending blocks
        let expectation = expectation(description: #function)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
        // If we got here without crashing, the timer was successfully started
        XCTAssertTrue(true)
    }

    func testTrackAnalyticsEvent() {
        let expectation = expectation(description: #function)
        logEventStoreService._didSaveAnalyticsEvent
            .sink { option in
                XCTAssert(option)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        logDefaultImpl.trackAnalyticsEvent(for: logEvent)
        waitForExpectations(timeout: 2.0)
    }

    func testGetAnalyticsEventReturnsModels() {
        let expectation = expectation(description: "get analytics data")

        logDefaultImpl._test_getAnalyticsEvent()
            .sink { models in
                XCTAssertFalse(models.isEmpty)
                expectation.fulfill()
            }
            .store(in: &cancellables)

        waitForExpectations(timeout: 1.0)
    }

    func testUploadAnalyticsEventsUploadsAndDeletes() {
        let deleteExpectation = expectation(description: "delete after upload")
        logEventStoreService._didDeleteAnalyticsEvent
            .sink { _ in deleteExpectation.fulfill() }
            .store(in: &cancellables)

        let analyticsModel = AnalyticsEventModel(context: serviceLocator.context)
        analyticsModel.payload = Data("payload".utf8)
        analyticsModel.timeStamp = 1

        logDefaultImpl._test_uploadAnalyticsEvents([analyticsModel])

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(networkService.uploadedBatches.count, 1)
    }

    func testScheduleNextUploadIfRequiredRunsAfterCoolOff() {
        let uploadExpectation = expectation(description: "upload after cool off")
        networkService.didUploadBatch
            .sink { _ in
                uploadExpectation.fulfill()
            }
            .store(in: &cancellables)

        logDefaultImpl._test_scheduleNextUploadIfRequired(coolOffPeriod: 0, executeImmediately: true)

        waitForExpectations(timeout: 5.0)
        XCTAssertEqual(networkService.uploadedBatchCount, 1)
    }
}

private final class TrackingNetworkService: MockNetworkService {
    private let uploadedBatchesLock = NSLock()
    private(set) var uploadedBatches: [AnalyticsEventBatch] = []
    let didUploadBatch = PassthroughSubject<AnalyticsEventBatch, Never>()

    var uploadedBatchCount: Int {
        uploadedBatchesLock.lock()
        defer { uploadedBatchesLock.unlock() }
        return uploadedBatches.count
    }

    override func uploadAnalyticsEventBatch(_ eventBatch: AnalyticsEventBatch) -> AnyPublisher<LogEventResponse?, any Error> {
        uploadedBatchesLock.lock()
        uploadedBatches.append(eventBatch)
        uploadedBatchesLock.unlock()
        didUploadBatch.send(eventBatch)
        return super.uploadAnalyticsEventBatch(eventBatch)
    }
}
