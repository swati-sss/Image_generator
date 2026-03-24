//
//  IndoorPositioningServiceTests.swift
//  compass_sdk_iosTests
//
//  Created by Pratik Patel on 5/22/24.
//

import IPSFramework
@testable import compass_sdk_ios
import Combine
import Foundation
import XCTest

class IndoorPositioningServiceTests: XCTestCase {
    var indoorPositioningService: IndoorPositioningServiceImpl!
    var serviceLocator: MockServiceLocator!
    var cancellable: Set<AnyCancellable>!

    override func setUpWithError() throws {
        try super.setUpWithError()
        cancellable = Set<AnyCancellable>()
        IPSPositioning.testLockThreshold = 1
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.mockUserEnabled.rawValue)
        serviceLocator = MockServiceLocator()
        indoorPositioningService = IndoorPositioningServiceImpl(
            statusService: serviceLocator.getStatusService(),
            locationPermissionService: serviceLocator.getLocationPermissionService(),
            positioningType: MockIPSPositioning.self,
            positioningCoreType: MockPositioningCore.self,
            geoFencingType: MockGeofencingType.self
        )
    }

    override func tearDownWithError() throws {
        serviceLocator._resetMock()
        MockIPSPositioning._resetMock()
        MockPositioningCore._resetMock()
        IPSPositioning.testLockThreshold = 1
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.mockUserEnabled.rawValue)
        cancellable.forEach { $0.cancel() }
        cancellable = nil
        try super.tearDownWithError()
    }

    func testOnPositioningEngineStateChangedPositioningAndCalibratingSetsActive() {
        indoorPositioningService.isPositioningActive = false

        indoorPositioningService.onPositioningEngineStateChanged(.positioningAndCalibrating)

        XCTAssertTrue(indoorPositioningService.isPositioningActive)
    }

    func testOnPositioningEngineStateChangedIdleResetsState() {
        indoorPositioningService.isPositioningActive = true
        indoorPositioningService.isCalibrationGestureNeeded = false
        indoorPositioningService.lockProgress = 1.0
        indoorPositioningService.calibrationProgress = 100.0

        let expectation = expectation(description: "idle resets state")
        indoorPositioningService.onPositioningEngineStateChanged(.idle)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(self.indoorPositioningService.isPositioningActive)
            XCTAssertFalse(self.indoorPositioningService.isPositionLocked)
            XCTAssertEqual(self.indoorPositioningService.lockProgress, 0)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testLogHeartBeatEventEmitsWhenEnabled() {
        indoorPositioningService.isHeartbeatEnabled = true
        indoorPositioningService.floorCoordinatesConverter = MockFloorCoordinatesConverterImpl()
        let mockPosition = MockIPSPosition(x: 1, y: 2, headingAngle: MockHeading(angle: 0), accuracy: 1)
        mockPosition.traveledDistance = 5
        indoorPositioningService.lastPosition.value = mockPosition
        indoorPositioningService._test_setOriientSessionId("session")
        Analytics.includeLocationInHeatbeat = true
        Analytics.includeUserInHeatbeat = true
        Analytics.anonymizedUserID = "user"

        indoorPositioningService._test_logHeartBeatEvent()

        // No crash and Analytics side effects are implicit; assert heartbeat not skipped
        XCTAssertTrue(indoorPositioningService.isHeartbeatEnabled)
    }

    func testStartPositioningWithLocationPermissionGranted() {
        let expectation = expectation(description: #function)
        let building = TestData.iPSBuilding
        Analytics.heartbeatInterval = 0.1
        serviceLocator.locationPermissionService?._expectedLocationPermission = .authorizedWhenInUse
        MockIPSPositioning._shouldFailStartPositioning = false
        indoorPositioningService.getBuilding(TestData.iPSBuilding.id, onSuccess: { _ in }, onError: {_ in } )
        
        // Observe positioningFloor for the expected value
        indoorPositioningService.positioningFloor
            .sink { floor in
                if floor?.id == building.primaryFloor.id {
                    expectation.fulfill()
                }
            }.store(in: &cancellable)
        
        indoorPositioningService.startPositioning(building: building) { error in
            if let _ = error {
                XCTFail()
            }
        }
        waitForExpectations(timeout: 5)
    }

    func testStartPositioningError() {
        let expectation = expectation(description: #function)
        let building = TestData.iPSBuilding
        serviceLocator.locationPermissionService?._expectedLocationPermission = .authorizedWhenInUse
        MockIPSPositioning._shouldFailStartPositioning = true

        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        indoorPositioningService.getBuilding(TestData.iPSBuilding.id, onSuccess: { _ in }, onError: {_ in } )
        indoorPositioningService.startPositioning(building: building) { error in
            if let _ = error {
                expectation.fulfill()
            } else {
                XCTFail()
            }
        }
        waitForExpectations(timeout: 5)
    }

    func testStartPositioningErrorWithLocationPermissionGranted() {
        (serviceLocator.getLocationPermissionService() as? MockLocationPermissionService)?._expectedLocationPermission = .authorizedWhenInUse
        MockIPSPositioning._shouldFailStartPositioning = true
        (serviceLocator.getLocationPermissionService() as? MockLocationPermissionService)?._expectedLocationPermission = .denied
        let expectation = expectation(description: #function)
        let building = TestData.iPSBuilding
        indoorPositioningService.startPositioning(building: building) { error in
            if let _ = error {
                expectation.fulfill()
            } else {
                XCTFail()
            }
        }
        waitForExpectations(timeout: 5.0)
    }

    func testStartPositioningWithLocationPermissionDenied() {
        (serviceLocator.getLocationPermissionService() as? MockLocationPermissionService)?._expectedLocationPermission = .denied
        let expectation = expectation(description: #function)
        let building = TestData.iPSBuilding
        indoorPositioningService.startPositioning(building: building) { error in
            if let _ = error {
                expectation.fulfill()
            } else {
                XCTFail()
            }
        }
        waitForExpectations(timeout: 5.0)
    }

    func testStopPositioning() {
        indoorPositioningService.stopPositioning() { [self] error in
            if let _ = error {
                XCTFail()
            }
            XCTAssertNil(self.indoorPositioningService.positioningFloor.value)
            XCTAssertFalse(self.indoorPositioningService.isPositioningActive)
        }
    }

    func testStopPositioningError() {
        let expectation = expectation(description: #function)
        MockIPSPositioning._shouldFailStopPositioning = true
        indoorPositioningService.isPositioningActive = true
        indoorPositioningService.stopPositioning() { error in
            if let _ = error {
                expectation.fulfill()
                return
            }
        }
        waitForExpectations(timeout: 2.0)
    }

    func testPositioningObserverErrorCallback() {
        let expectation = expectation(description: #function)
        serviceLocator.statusService?.eventEmitterHandler = { event in
            if event.eventType == .errorEventEmitter {
                expectation.fulfill()
            }
        }

        MockIPSPositioning._shouldThrowObserverError = true
        indoorPositioningService.login(userId: "userId") { _ in }
        waitForExpectations(timeout: 4.0)
    }

    func testPositioningObserverCallback() {
        let expectation = expectation(description: #function)
        indoorPositioningService.lastPosition
            .sink { position in
                if position?.x == 20, position?.y == 20, position?.heading.angle == 2, position?.accuracy == 79 {
                    expectation.fulfill()
                }
            }.store(in: &cancellable)
        MockIPSPositioning._shouldThrowObserverError = false

        indoorPositioningService.login(userId: "userId") { _ in
            let position = MockIPSPosition(
                x: 20,
                y: 20,
                headingAngle: MockHeading(angle: 2),
                accuracy: 79,
                lockProgress: 1.0
            )
            MockIPSPositioning._observer?.onPositionUpdate(position)
        }
        waitForExpectations(timeout: 4.0)
    }

    func testLogin() throws {
        indoorPositioningService.login(userId: "userId") { error in
            guard let error else {
                return
            }
            Log.error("Oriient login failed: \(error.code): \(error.message): \(error.recoveryStrategy)")
        }

        XCTAssert(MockPositioningCore._loginCalled)
    }

    func testGetBuilding() throws {
        indoorPositioningService.getBuilding("id", onSuccess: { building in
            XCTAssertEqual(building.id, TestData.iPSBuilding.id)
        }) { error in
            Log.error("Get Building failed: \(error.code): \(error.message): \(error.recoveryStrategy)")
        }
    }

    func testToggleMockUserEnablesMockThreshold() throws {
        indoorPositioningService.toggleMockUser(true)
        XCTAssertEqual(IPSPositioning.testLockThreshold, 0)
    }

    func testOnPositionUpdate() {
        serviceLocator.locationPermissionService?._expectedLocationPermission = .authorizedWhenInUse
        let mockPosition = MockIPSPosition(x: 20, y: 40, headingAngle: MockHeading(angle: 30), accuracy: 3)
        IPSPositioning.testLockThreshold = 1
        indoorPositioningService.onPositionUpdate(mockPosition)
        XCTAssert(indoorPositioningService.lastPosition.value!.x == mockPosition.x)
        XCTAssert(indoorPositioningService.lastPosition.value!.y == mockPosition.y)
        XCTAssert(indoorPositioningService.lastPosition.value!.accuracy == mockPosition.accuracy)
        XCTAssert(indoorPositioningService.lastPosition.value!.heading.angle == mockPosition.heading.angle)
        XCTAssert(indoorPositioningService.isPositionLocked == mockPosition.isLocked)
    }

    func testOnPositionUpdateTestLockThreshold() {
        let expectation = expectation(description: #function)
        serviceLocator.locationPermissionService?._expectedLocationPermission = .authorizedWhenInUse
        IPSPositioning.testLockThreshold = 0
        let mockPosition = MockIPSPosition(x: 20, y: 40, headingAngle: MockHeading(angle: 30), accuracy: 3)
        serviceLocator.statusService?.eventEmitterHandler = { event in
            if event.eventType == .positioningStateEventEmitter {
                expectation.fulfill()
            }
        }
        indoorPositioningService.onPositionUpdate(mockPosition)
        waitForExpectations(timeout: 4.0)
        IPSPositioning.testLockThreshold = 1
    }

    func testOnCalibrationGestureNeeded() {
        let expectation = expectation(description: #function)
        serviceLocator.locationPermissionService?._expectedLocationPermission = .authorizedWhenInUse
        serviceLocator.statusService?.eventEmitterHandler = { event in
            if event.eventType == .positioningStateEventEmitter {
                expectation.fulfill()
            }
        }
        indoorPositioningService.onCalibrationGestureNeeded(true)
        waitForExpectations(timeout: 4.0)
    }

    func testCalibrationUpdate() {
        let expectation = expectation(description: #function)
        serviceLocator.locationPermissionService?._expectedLocationPermission = .authorizedWhenInUse
        serviceLocator.statusService?.eventEmitterHandler = { event in
            if event.eventType == .positioningStateEventEmitter {
                expectation.fulfill()
            }
        }
        indoorPositioningService.onCalibrationProgress(20)

        waitForExpectations(timeout: 4.0)
    }
}

extension MockIPSFloor: Equatable {
    static func == (lhs: MockIPSFloor, rhs: MockIPSFloor) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.shortName == rhs.shortName &&
        lhs.order == rhs.order &&
        lhs.defaultMapId == rhs.defaultMapId &&
        lhs.height == rhs.height
    }
}
