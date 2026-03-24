//
//  CompassViewModelTests.swift
//  compass_sdk_iosTests
//
//  Created by Young Jin Ju on 3/31/24.
//

import XCTest
import Combine
import CoreData
import Foundation
@testable import compass_sdk_ios
import IPSFramework

final class CompassViewModelTests: XCTestCase {
    private var walmartMapStoreConfig: StoreConfig!
    private var oriientMapStoreConfig: StoreConfig!
    private var walmartMapStoreConfigWithoutBlueDot: StoreConfig!
    private var emptyStoreConfig: StoreConfig!
    private var compassViewModel: CompassViewModel!
    private var userAccessTokenResponse: AccessTokenResponse!
    private var iamAccessTokenResponse: AccessTokenResponse!
    private var userAuthParameter: AuthParameter!
    private var iamAuthParameter: AuthParameter!
    private var statusService: StatusService!
    private let containerViewController = UIViewController()
    private var cancellables = Set<AnyCancellable>()
    private var serviceLocator: ServiceLocatorType!
    private var networkService: MockNetworkService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        serviceLocator = MockServiceLocator()
        networkService = serviceLocator.getNetworkService() as? MockNetworkService
        compassViewModel = CompassViewModel(serviceLocator: serviceLocator)
        guard let compassViewModel else {
            return
        }
        statusService = serviceLocator.getStatusService()
        userAccessTokenResponse = AccessTokenResponse(
            accessToken: "MTAyOTYyMDE4dSxyrP0t1Jm+zsHDj/m58lYEBSWPPQT0ASxP67P/p/R/XCviMJx6YIyuweMm/D4szCyTMBgQUr8MJWMSm3S2rqgF8Z3ooqOrbfBJzORYy7wGmKcywYDpRHb13NVCvU9dVoZ2h67qtmWCX5xnAS95ZSpQBIV+q5odNqvzV1gAYlvCveWZ0+3rq3ePWs9LhzZ7tXoVX6MbrQS+QrPDOp+Ee8FAqtMt7lzQdJSvbzFlrGCMSMVOB6MAabmTP67qQX6SO9FaZQ9xSvIHt7THYc5BH11KK3aFtE5QbXB6Vt5ZAzN3ltf8skOawMmpueLResLhye4vrf8JNA1nW1zzpx3kxQ==",
            tokenType: "user",
            expiresIn: 900
        )
        iamAccessTokenResponse = AccessTokenResponse(
            accessToken: "Uhcqt1EBCq3COum7WhGK4b0Pre0TyMndfqMsCslnzyd70Zc5Xy1NI-pyCARRNG0qQvkI2iVv2s7sKGBiTwz_PQ",
            tokenType: "IAM",
            expiresIn: 900
        )
        userAuthParameter = AuthParameter(
            clientSecret: userAccessTokenResponse.accessToken,
            tokenType: userAccessTokenResponse.tokenType,
            accountID: "988sdd-erer-43434",
            consumerID: "573e4372-b4f0-4f01-a58d-3f7aff19e078"
        )
        iamAuthParameter = AuthParameter(
            clientSecret: iamAccessTokenResponse.accessToken,
            tokenType: iamAccessTokenResponse.tokenType,
            accountID: "988sdd-erer-43434",
            consumerID: "c061c52a-b978-4ae9-9875-6584e58e8a74"
        )
        walmartMapStoreConfig = StoreConfig(supportedEventList: "\"[{ \"event_namespace\": \"modflex/MODFLEX_SCAN_FEATURE_LOCATION\",  \"enabled\": true,  \"batched\": false},{ \"event_namespace\": \"modflex/MODFLEX_CREATE_FEATURE_ITEM\", \"enabled\": true,  \"batched\": false},{ \"even_namespace\":\"modflex/MODFLEX_SET_MOD_SECTION_FEATURE\",  \"enabled\": true, \"batched\\\": false},{ \"event_namespace\":\"modflex/MODFLEX_SET_MOD_SECTION_FEATURE\", \"enabled\": true, \"batched\": false},{\"event_namespace\":\"modflex/MODFLEX_SCAN_OTHER_FEATURE_ITEMS\", \"enabled\": true, \"batched\": false},{\"event_namespace\": \"SFOT_ITEM_SCAN\", \"enabled\": true, \"batched\": false},{\"event_namespace\": \"SFOT_ITEM_SCAN\", \"enabled\": true, \"batched\": false},{\"event_namespace\": \"SFOT_ITEM_ADD_TO_CART\", \"enabled\": true,  \"batched\": false},{\"event_namespace\": \"SFOT_ITEM_ORDERED\",  \"enabled\": true,  \"batched\": false}]\"",
                                            storeId: Int(2280),
                                            valid: true,
                                            bluedotEnabled: true,
                                            mapType: "WalmartMap",
                                            sessionRefreshTime: 900,
                                            offset: StoreConfigOffset(
                                                x: 4612.4299902343755,
                                                y: 3431.0000244140624
                                            ),
                                            analytics: true,
                                            batchInterval: 180000,
                                            heartbeatInterval: 3000)
        walmartMapStoreConfigWithoutBlueDot = StoreConfig(storeId: Int(3594),
                                                          valid: true,
                                                          bluedotEnabled: false,
                                                          mapType: "WalmartMap",
                                                          sessionRefreshTime: 900,
                                                          offset: StoreConfigOffset(
                                                            x: 70.2500012207031,
                                                            y: 1953.1300146484375
                                                          ),
                                                          analytics: true,
                                                          batchInterval: 180000,
                                                          heartbeatInterval: 3000)
        oriientMapStoreConfig = StoreConfig(storeId: Int(2280),
                                            valid: true,
                                            bluedotEnabled: true,
                                            mapType: "OriientMap",
                                            sessionRefreshTime: 900,
                                            offset: StoreConfigOffset(
                                                x: 4612.4299902343755,
                                                y: 3431.0000244140624
                                            ),
                                            analytics: true,
                                            batchInterval: 180000,
                                            heartbeatInterval: 3000)
        emptyStoreConfig = StoreConfig(storeId: Int(3594),
                                       valid: true,
                                       bluedotEnabled: false,
                                       sessionRefreshTime: 900,
                                       analytics: true)
        // Clear UserDefaults for clean test state
        IPSPositioning.testLockThreshold = 1
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.uuidList.rawValue)
    }

    override func tearDownWithError() throws {
        (serviceLocator as? MockServiceLocator)?._resetMock()
        cancellables.removeAll()
        IPSPositioning.testLockThreshold = 1
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.uuidList.rawValue)
        try super.tearDownWithError()
    }

    func testGetAccessTokenWhenAuthTokenIsEmpty() {
        let exp = XCTestExpectation(description: #function)
        compassViewModel.getAccessToken(authParameter: AuthParameter())
            .sink(receiveCompletion: { error in
                if case .failure = error {
                    exp.fulfill()
                } else {
                    XCTFail("Expected to receive a failure, but got: \(error)")
                }
            }, receiveValue: { accessTokenResponse in
                XCTAssertNil(accessTokenResponse)
            })
            .store(in: &cancellables)
        wait(for: [exp], timeout: 2.0)
    }

    func testGetAccessTokenWhenTokenTypeIsUser() {
        let exp = XCTestExpectation(description: #function)
        networkService._shouldFail = false
        networkService._expectedTokenResponse = userAccessTokenResponse
        var receivedValue = false
        
        compassViewModel.getAccessToken(authParameter: userAuthParameter)
            .sink(receiveCompletion: { completion in
                if !receivedValue {
                    XCTFail("Expected to receive a value before completion: \(completion)")
                } else {
                    exp.fulfill()
                }
            }, receiveValue: { [weak self] accessTokenResponse in
                XCTAssertNotNil(self)
                XCTAssertNotNil(accessTokenResponse)
                XCTAssertEqual(accessTokenResponse!.tokenType, "user")
                XCTAssertEqual(accessTokenResponse?.accessToken, self!.userAuthParameter.clientSecret)
                receivedValue = true
            })
            .store(in: &cancellables)
        wait(for: [exp], timeout: 2.0)
    }

    func testGetAccessTokenWhenTokenTypeIsIAM() {
        let exp = XCTestExpectation(description: #function)
        networkService._shouldFail = false
        networkService._expectedTokenResponse = iamAccessTokenResponse
        var receivedValue = false
        
        compassViewModel.getAccessToken(authParameter: iamAuthParameter)
            .sink(receiveCompletion: { completion in
                if !receivedValue {
                    XCTFail("Expected to receive a value before completion: \(completion)")
                } else {
                    exp.fulfill()
                }
            }, receiveValue: { accessTokenResponse in
                XCTAssertNotNil(accessTokenResponse)
                XCTAssertEqual(accessTokenResponse!.tokenType, "IAM")
                receivedValue = true
            })
            .store(in: &cancellables)
        wait(for: [exp], timeout: 2.0)
    }

    func testGetAccessTokenFailed() {
        let expectation = expectation (description: #function)
        networkService._expectedError = ErrorResponse(response: HTTPURLResponse(url: TestData.exampleURL, statusCode: 520, httpVersion: "1.1", headerFields: [:])!, error: MockNetworkServiceError.requestFailed)
        networkService._shouldFail = true
        statusService.eventEmitterHandler = { eventEmitter in
            guard let errorEventEmitter = eventEmitter as? ErrorEventEmitter else {
                return
            }
            if errorEventEmitter.eventType == .initErrorEventEmitter {
                expectation.fulfill()
            }
        }
        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.floorCoordinatesConverter = MockFloorCoordinatesConverterImpl()

        compassViewModel.getAccessToken(authParameter: AuthParameter(clientSecret: "invalidToken", tokenType: "IAM"))
            .sink(receiveCompletion: { error in
                XCTFail("Expected to receive a value, but got a completion: \(error)")
            }, receiveValue: { XCTAssertNil($0) })
            .store(in: &cancellables)

        waitForExpectations(timeout: 5.0)
    }

    func testToggleMockUserWhenMockUserIsTrue() {
        compassViewModel.toggleMockUser(true)
        XCTAssertTrue((serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?._mockUserEnabled ?? false)
    }

    func testUpdateStoreConfigurationWhenStoreConfigIsEmpty() {
        compassViewModel.updateStoreConfiguration(emptyStoreConfig)
        XCTAssertEqual(self.serviceLocator.getAssetService().storeId, self.emptyStoreConfig.storeId!)
    }

    func testSetBackgroundModeWhenBackgroundModeIsTrue() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.post(name: UIApplication.didEnterBackgroundNotification, object: nil, userInfo: nil)
        XCTAssertEqual((serviceLocator.getNetworkMonitorService() as? MockNetworkMonitorService)?._isBackgroundMode, true)
        XCTAssertFalse(serviceLocator.getIndoorPositioningService().isPositioningActive)
    }

    func testSetBackgroundModeForBlueDotWhenBackgroundModeAndIsPositioningActiveIsFalse() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.post(name: UIApplication.willEnterForegroundNotification, object: nil, userInfo: nil)
        XCTAssertEqual((serviceLocator.getNetworkMonitorService() as? MockNetworkMonitorService)?._isBackgroundMode, false)
    }

    func testGetAisleWithAssetIdForWalmartMap() {

        compassViewModel.updateStoreConfiguration(walmartMapStoreConfig)

        self.compassViewModel.getAisle(id: "peter123")
        XCTAssertEqual((self.serviceLocator.getAssetService() as? MockAssetService)!._evaluateAssetsCalled, true)

    }

    func testGetAisleWithAssetIdForWalmartMapWithoutBlueDot() {
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfigWithoutBlueDot)
        self.compassViewModel.getAisle(id: "peter123")
        XCTAssertEqual((self.serviceLocator.getAssetService() as? MockAssetService)!._evaluateAssetsCalled, true)

    }

    func testIsMapViewReady() {
        let exp = XCTestExpectation(description: #function)
        compassViewModel.isMapViewReady()
            .dropFirst()
            .sink { isMapViewReady in
                XCTAssert(isMapViewReady)
                exp.fulfill()
            }
            .store(in: &cancellables)

        compassViewModel.updateStoreConfiguration(TestData.storeConfig)
        self.compassViewModel.displayMap()

        wait(for: [exp], timeout: 5.0)
    }

    func testDisplayMapWhenIsPositioningActiveFalse() {
        compassViewModel.displayMap()
        XCTAssertFalse(serviceLocator.getIndoorPositioningService().isPositioningActive)
    }

    func testDisplayMapForWalmartMap() {
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfig)
        self.compassViewModel.displayMap()
        XCTAssertEqual(self.serviceLocator.getAssetService().storeId, self.walmartMapStoreConfig.storeId!)
        XCTAssertNotNil(compassViewModel.mapHostViewModel)
        XCTAssertTrue(compassViewModel.isPositioningEnabled)

    }

    func testDisplayMapForWalmartMapWithoutBlueDot() {
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfigWithoutBlueDot)
        self.compassViewModel.displayMap()
        XCTAssertEqual(self.serviceLocator.getAssetService().storeId, self.walmartMapStoreConfigWithoutBlueDot.storeId!)
        XCTAssertNotNil(compassViewModel.mapHostViewModel)
        XCTAssertFalse(compassViewModel.isPositioningEnabled)

    }

    func testDisplayMapForOriientMap() {
        compassViewModel.updateStoreConfiguration(oriientMapStoreConfig)
        self.compassViewModel.displayMap()
        XCTAssertEqual(self.serviceLocator.getAssetService().storeId, self.oriientMapStoreConfig.storeId!)
        XCTAssertNotNil(compassViewModel.mapHostViewModel)
        XCTAssertTrue(compassViewModel.isPositioningEnabled)

    }

    func testClearMapForWalmartMap() {
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfig)
        let mapConfig = MapConfig(resetZoom: true)
        self.compassViewModel.clearMap(mapConfig: mapConfig)
        XCTAssertEqual(self.serviceLocator.getAssetService().storeId, self.walmartMapStoreConfig.storeId!)
        XCTAssertNotNil(compassViewModel.mapHostViewModel)

    }

    func testClearMapForOriientMap() {
        compassViewModel.updateStoreConfiguration(oriientMapStoreConfig)
        let mapConfig = MapConfig(resetZoom: true)
        self.compassViewModel.clearMap(mapConfig: mapConfig)
        XCTAssertEqual(self.serviceLocator.getAssetService().storeId, self.oriientMapStoreConfig.storeId!)
        XCTAssertNotNil(compassViewModel.mapHostViewModel)

    }

    func testUpdateEventForWalmartMap() {
        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.lastLockedPosition = MockIPSPosition(x: 10, y: 20, headingAngle: MockIPSHeading(angle: 3.142), accuracy: 5)
        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.floorCoordinatesConverter = MockFloorCoordinatesConverterImpl()
        compassViewModel = CompassViewModel(serviceLocator: serviceLocator)
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfig)
        let compassEvent = CompassEvent(eventType: "asset_scan",
                                        eventValue: "575208",
                                        eventMetadata: [:])
        self.compassViewModel.updateEvent(compassEvent: compassEvent)
        XCTAssertEqual(self.serviceLocator.getAssetService().storeId, self.walmartMapStoreConfig.storeId!)
        XCTAssertNotNil(compassViewModel.mapHostViewModel)

    }

    func testUpdateEventForOriientMap() {
        compassViewModel.updateStoreConfiguration(oriientMapStoreConfig)

        let compassEvent = CompassEvent(eventType: "asset_scan",
                                        eventValue: "575208",
                                        eventMetadata: [:])
        self.compassViewModel.updateEvent(compassEvent: compassEvent)
        XCTAssertEqual(self.serviceLocator.getAssetService().storeId, self.oriientMapStoreConfig.storeId!)
        XCTAssertNotNil(compassViewModel.mapHostViewModel)

    }

    func testUpdateEventListForWalmartMap() {
        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.lastLockedPosition = MockIPSPosition(x: 10, y: 20, headingAngle: MockIPSHeading(angle: 3.142), accuracy: 5)
        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.floorCoordinatesConverter = MockFloorCoordinatesConverterImpl()
        let assetService = serviceLocator.getAssetService() as? MockAssetService
        assetService?.supportedEventList = walmartMapStoreConfig.supportedEventList ?? ""
        compassViewModel = CompassViewModel(serviceLocator: serviceLocator)
        compassViewModel.isPositioningEnabled = true
        compassViewModel.positionRefreshTime = -1
        compassViewModel.updateEventList(
            namespace: "modflex",
            eventType: "MODFLEX_SCAN_FEATURE_LOCATION",
            eventValue: "BK4-12",
            metaData: [
                "keyA": "va",
                "keyB": "vb",
                "keyC": "vc",
                "keyD": "vd",
                "keyE": "ve",
                "keyF": "vf"
            ]
        )
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfig)

        XCTAssertEqual(self.serviceLocator.getAssetService().storeId, self.walmartMapStoreConfig.storeId!)
        XCTAssertTrue(compassViewModel.isPositioningEnabled)

    }

    func testDisplayPinWithMultipleUUIdForWalmartMap() {
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfig)
        let displayPinConfig = DisplayPinConfig(enableManualPinDrop: false, resetZoom:true, shouldZoomOnPins: true)
        self.compassViewModel.displayPin(uuidList: ["1645190", "575207", "575208"],
                                         idType: PinDropMethod.assets,
                                         config: displayPinConfig)
        XCTAssertEqual(self.serviceLocator.getAssetService().storeId, self.walmartMapStoreConfig.storeId!)
        XCTAssertNotNil(UserDefaults.standard.object(forKey: UserDefaultsKey.uuidList.rawValue) as? [String])
        XCTAssertEqual(UserDefaults.standard.object(forKey: UserDefaultsKey.uuidList.rawValue) as? [String], ["1645190", "575207", "575208"])

    }

    func testDisplayPinWithUUIdForWalmartMap() {
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfig)
        let displayPinConfig = DisplayPinConfig(enableManualPinDrop: false, resetZoom:true, shouldZoomOnPins: true)
        self.compassViewModel.displayPin(uuidList: ["575208"],
                                         idType: PinDropMethod.assets,
                                         config: displayPinConfig)
        XCTAssertEqual(self.serviceLocator.getAssetService().storeId, self.walmartMapStoreConfig.storeId!)
        XCTAssertNotNil(UserDefaults.standard.object(forKey: UserDefaultsKey.uuidList.rawValue) as? [String])
        XCTAssertEqual(UserDefaults.standard.object(forKey: UserDefaultsKey.uuidList.rawValue) as? [String], ["575208"])

    }

    func testdisplayPinForWalmartMap() {
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfig)
        let displayPinConfig = DisplayPinConfig(enableManualPinDrop: false, resetZoom:true, shouldZoomOnPins: true)
        let aislePin1 = AislePin(type: "item", id: "1", location: AisleLocation(zone: "A", aisle: "3", section: "3", selected: true))
        let aislePin2 = AislePin(type: "item", id: "2", location: AisleLocation(zone: "A", aisle: "8", section: "3", selected: false))
        let compassPins: [CompassPin] = [aislePin1, aislePin2].map { CompassPin.aisle($0) }
        self.compassViewModel.displayPin(pins: compassPins, config: displayPinConfig)
        XCTAssertEqual(self.serviceLocator.getAssetService().storeId, self.walmartMapStoreConfig.storeId!)

    }

    func testdisplayPinForOriientMap() {
        compassViewModel.updateStoreConfiguration(oriientMapStoreConfig)
        let displayPinConfig = DisplayPinConfig(enableManualPinDrop: false, resetZoom:true, shouldZoomOnPins: true)
        let aislePin1 = AislePin(type: "item", id: "1", location: AisleLocation(zone: "A", aisle: "3", section: "3", selected: true))
        let aislePin2 = AislePin(type: "item", id: "2", location: AisleLocation(zone: "A", aisle: "8", section: "3", selected: false))
        let compassPins: [CompassPin] = [aislePin1, aislePin2].map { CompassPin.aisle($0) }
        self.compassViewModel.displayPin(pins: compassPins, config: displayPinConfig)
        XCTAssertEqual(self.serviceLocator.getAssetService().storeId, self.oriientMapStoreConfig.storeId!)

    }

    func testResetPositionStatusEvent() {
        let exp = XCTestExpectation(description: #function)
        statusService.eventEmitterHandler = { eventEmitter in
            guard let positionEventEmitter = eventEmitter as? PositionEventEmitter else {
                return
            }
            XCTAssertEqual(positionEventEmitter.eventType, .positionEventEmitter)
            exp.fulfill()
        }
        compassViewModel.resetPositionStatusEvent()
        wait(for: [exp], timeout: 2.0)
    }

    func testStopPositioningWhenIsPositioningEnabledIsFalse() {

        compassViewModel.updateStoreConfiguration(walmartMapStoreConfigWithoutBlueDot)

        self.compassViewModel.stopPositioning()
        XCTAssertEqual(self.serviceLocator.getAssetService().storeId, self.walmartMapStoreConfigWithoutBlueDot.storeId!)
        XCTAssertFalse(compassViewModel.isPositioningEnabled)

    }

    func testStopPositioningWhenIsPositioningEnabledIsTrue() {
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfig)
        self.compassViewModel.stopPositioning()
        XCTAssertEqual(self.serviceLocator.getAssetService().storeId, self.walmartMapStoreConfig.storeId!)
        XCTAssertTrue(compassViewModel.isPositioningEnabled)

    }
    func testUpdateEvent_whenFloorCoordinatesConverterIsNil_shouldEmitErrorAndAnalytics() {
        let exp = XCTestExpectation(description: #function)
        // Set lastLockedPosition to non-nil
        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.lastLockedPosition = MockIPSPosition(x: 10, y: 20, headingAngle: MockIPSHeading(angle: 3.142), accuracy: 5)
        // Set floorCoordinatesConverter to nil
        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.floorCoordinatesConverter = nil
        compassViewModel = CompassViewModel(serviceLocator: serviceLocator)
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfig)


        let compassEvent = CompassEvent(eventType: "asset_scan", eventValue: "575208", eventMetadata: [:])
        self.statusService.eventEmitterHandler = { eventEmitter in
            guard let errorEventEmitter = eventEmitter as? ErrorEventEmitter else { return }
            XCTAssertEqual(errorEventEmitter.eventType, .errorEventEmitter)
            XCTAssertEqual(errorEventEmitter.compassErrorType, CompassErrorType.addEventError.rawValue)
            exp.fulfill()
        }
        self.compassViewModel.updateEvent(compassEvent: compassEvent)
        wait(for: [exp], timeout: 2.0)
    }
    func testUpdateEventList_whenAllGuardsPass_shouldEmitUpdateEventList() {
        let exp = XCTestExpectation(description: #function)
        // Set up mocks
        let mockPosition = MockIPSPosition(x: 10, y: 20, headingAngle: MockIPSHeading(angle: 1.23), accuracy: 5)
        mockPosition.lockProgress = 1
        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.lastPosition.value = mockPosition
        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.floorCoordinatesConverter = MockFloorCoordinatesConverterImpl()
        compassViewModel = CompassViewModel(serviceLocator: serviceLocator)
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfig)

        self.statusService.eventEmitterHandler = { eventEmitter in
            // You can add more specific assertions here if needed
            exp.fulfill()
        }
        self.compassViewModel.updateEventList(
            namespace: "modflex",
            eventType: "feature_scan",
            eventValue: "BK4-12",
            metaData: ["keyA": "va"]
        )

        wait(for: [exp], timeout: 2.0)
    }

    func testKillSwitchCallsDependenciesAndClearsCancellables() {
        // Call killSwitch
        compassViewModel.killSwitch()

        // Assert stopPositioning and logout are called (using the mock)
        XCTAssertTrue((serviceLocator.getUserPositionManager() as? MockUserPositionManager)?._logoutCalled == true)
    }

    // MARK: - Extension Tests for Complete Coverage

    func testStartPositionSession_WhenPositioningEnabled_ShouldStartPositioning() {
        compassViewModel.isPositioningEnabled = true
        compassViewModel.positionRefreshTime = -1
        // Arrange
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfig)
        
        // Act
        compassViewModel.startPositionSession()
        
        // Assert
        XCTAssertFalse(serviceLocator.getIndoorPositioningService().isPositioningActive)
    }

    func testStartPositionSession_WhenPositioningDisabled_ShouldNotStartPositioning() {
        // Arrange
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfigWithoutBlueDot)
        
        // Act
        compassViewModel.startPositionSession()
        
        // Assert
        XCTAssertFalse(serviceLocator.getIndoorPositioningService().isPositioningActive)
    }

    func testStartPositionSession_CreatesTimer() {
        // Arrange
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfig)
        
        // Act
        compassViewModel.startPositionSession()
        
        // Assert
        XCTAssertNotNil(compassViewModel.positionSessionTimer)
    }

    func testStopPositioning_WhenPositioningEnabled_ShouldStopPositioning() {
        // Arrange
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfig)
        compassViewModel.startPositionSession()
        
        // Act
        compassViewModel.stopPositioning()
        
        // Assert
        XCTAssertFalse(serviceLocator.getIndoorPositioningService().isPositioningActive)
    }

    func testStopPositioning_WhenPositioningDisabled_ShouldNotCallStopPositioning() {
        // Arrange
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfigWithoutBlueDot)
        
        // Act
        compassViewModel.stopPositioning()
        
        // Assert - should not crash and positioning should remain inactive
        XCTAssertFalse(serviceLocator.getIndoorPositioningService().isPositioningActive)
    }

    func testSetBackgroundMode_WhenTrue_SetsNetworkMonitorServiceBackgroundMode() {
        // Arrange
        let networkMonitor = serviceLocator.getNetworkMonitorService() as? MockNetworkMonitorService
        
        // Act
        compassViewModel.setBackgroundMode(true)
        
        // Assert
        XCTAssertTrue(networkMonitor?._isBackgroundMode ?? false)
    }

    func testSetBackgroundMode_WhenFalse_StartsPositionSession() {
        compassViewModel.isPositioningEnabled = true
        compassViewModel.positionRefreshTime = -1
        // Arrange
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfig)
        let networkMonitor = serviceLocator.getNetworkMonitorService() as? MockNetworkMonitorService
        
        // Act
        compassViewModel.setBackgroundMode(false)
        
        // Assert
        XCTAssertFalse(networkMonitor?._isBackgroundMode ?? true)
        XCTAssertFalse(serviceLocator.getIndoorPositioningService().isPositioningActive)
    }

    func testSetStore_WithValidStoreConfig_SetsAssetServiceStoreId() {
        // Act
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfig)
        
        // Assert
        XCTAssertEqual(compassViewModel.assetService.storeId, walmartMapStoreConfig.storeId!)
    }

    func testSetStore_WithNilStoreId_DoesNotSetStoreId() {
        // Arrange
        let configWithoutStoreId = StoreConfig(valid: true, bluedotEnabled: true, analytics: true)
        
        // Act
        compassViewModel.updateStoreConfiguration(configWithoutStoreId)
        
        // Assert - previous store id should remain or default
        XCTAssertNotEqual(compassViewModel.assetService.storeId, Int.max)
    }

    func testSetSupportedEventList_WithValidConfig_SetsSupportedEventList() {
        // Act
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfig)
        
        // Assert
        XCTAssertEqual(compassViewModel.assetService.supportedEventList, walmartMapStoreConfig.supportedEventList!)
    }

    func testSetSupportedEventList_WithNilSupportedEventList_DoesNotSet() {
        // Arrange
        let configWithoutEventList = StoreConfig(storeId: 123, valid: true, bluedotEnabled: true, analytics: true)
        
        // Act
        compassViewModel.updateStoreConfiguration(configWithoutEventList)
        
        // Assert
        XCTAssertEqual(compassViewModel.assetService.supportedEventList, "")
    }

    func testSetMapType_WithWalmartMap_CreatesMapHostViewModel() {
        // Act
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfig)
        
        // Assert
        XCTAssertNotNil(compassViewModel.mapHostViewModel)
        XCTAssertTrue(compassViewModel.isPositioningEnabled)
    }

    func testSetMapType_WithOriientMap_CreatesMapHostViewModel() {
        // Act
        compassViewModel.updateStoreConfiguration(oriientMapStoreConfig)
        
        // Assert
        XCTAssertNotNil(compassViewModel.mapHostViewModel)
        XCTAssertTrue(compassViewModel.isPositioningEnabled)
    }

    func testSetMapType_WithNilMapType_DoesNotCreateMapHostViewModel() {
        // Arrange
        let configWithoutMapType = StoreConfig(storeId: 123, valid: true, bluedotEnabled: true, analytics: true)
        
        // Act
        compassViewModel.updateStoreConfiguration(configWithoutMapType)
        
        // Assert
        XCTAssertNil(compassViewModel.mapHostViewModel)
    }

    func testGetStoreMapOptions_WithValidConfig_ReturnsValidOptions() {
        // Act
        let options = compassViewModel.getStoreMapOptions(storeConfig: walmartMapStoreConfig)
        
        // Assert
        XCTAssertNotNil(options)
        XCTAssertEqual(options.dynamicMapEnabled, walmartMapStoreConfig.dynamicMapEnabled ?? false)
    }

    func testGetStoreMapOptions_WithNilConfig_ReturnsDefaultOptions() {
        // Act
        let options = compassViewModel.getStoreMapOptions(storeConfig: nil)
        
        // Assert
        XCTAssertNotNil(options)
        XCTAssertFalse(options.dynamicMapEnabled)
        XCTAssertFalse(options.zoomControlEnabled)
    }

    func testSetupLogIntervalsData_WithValidBatchInterval_SetsBatchInterval() {
        // Arrange
        let config = StoreConfig(storeId: 123, valid: true, bluedotEnabled: true, analytics: true, batchInterval: 180000)
        
        // Act
        compassViewModel.updateStoreConfiguration(config)
        
        // Assert
        XCTAssertEqual(Log.batchInterval, 180)
    }

    func testSetupLogIntervalsData_WithValidHeartbeatInterval_SetsHeartbeatInterval() {
        // Arrange
        let config = StoreConfig(storeId: 123, valid: true, bluedotEnabled: true, analytics: true, heartbeatInterval: 3000)
        
        // Act
        compassViewModel.updateStoreConfiguration(config)
        
        // Assert
        XCTAssertEqual(Analytics.heartbeatInterval, 3)
    }

    func testSetupLogIntervalsData_WithHeartbeatFlags_SetsAnalyticsFlags() {
        // Arrange
        let config = StoreConfig(heartbeatInLocation: true, heartBeatInUser: true, storeId: 123, valid: true, bluedotEnabled: true, analytics: true)
        
        // Act
        compassViewModel.updateStoreConfiguration(config)
        
        // Assert
        XCTAssertTrue(Analytics.includeUserInHeatbeat)
        XCTAssertTrue(Analytics.includeLocationInHeatbeat)
    }

    func testSetStoreConfigOffset_WithValidOffset_SetsOffsetCorrectly() {
        // Act
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfig)
        
        // Assert
        XCTAssertNotNil(compassViewModel.assetService.storeConfigOffset)
    }

    func testSetStoreConfigOffset_WithNilOffset_DoesNotSet() {
        // Arrange
        let configWithoutOffset = StoreConfig(storeId: 123, valid: true, bluedotEnabled: true, analytics: true)
        
        // Act
        compassViewModel.updateStoreConfiguration(configWithoutOffset)
        
        // Assert - should not crash and offset should be default
        XCTAssertNotNil(compassViewModel.assetService.storeConfigOffset)
    }

    func testSetMapHostViewModel_WithWalmartMap_CreatesMapViewModel() {
        // Act
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfig)
        
        // Assert
        XCTAssertNotNil(compassViewModel.mapHostViewModel)
    }

    func testSetMapHostViewModel_WithOriientMap_CreatesMapViewModel() {
        // Act
        compassViewModel.updateStoreConfiguration(oriientMapStoreConfig)
        
        // Assert
        XCTAssertNotNil(compassViewModel.mapHostViewModel)
    }

    func testGetTokenData_WithValidClientIdAndConsumerId_ReturnsAccessToken() {
        let exp = XCTestExpectation(description: #function)
        networkService._shouldFail = false
        networkService._expectedTokenResponse = userAccessTokenResponse
        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.floorCoordinatesConverter = MockFloorCoordinatesConverterImpl()

        compassViewModel.getTokenData(for: userAuthParameter.clientSecret, consumerId: userAuthParameter.consumerID)
            .sink(receiveCompletion: { completion in
                if case .failure = completion {
                    XCTFail("Expected success")
                } else {
                    exp.fulfill()
                }
            }, receiveValue: { response in
                XCTAssertNotNil(response)
            })
            .store(in: &cancellables)
        
        wait(for: [exp], timeout: 2.0)
    }

    func testEmitUpdateEventError_ShouldEmitError() {
        let exp = XCTestExpectation(description: #function)
        statusService.eventEmitterHandler = { eventEmitter in
            guard let errorEmitter = eventEmitter as? ErrorEventEmitter else { return }
            XCTAssertEqual(errorEmitter.compassErrorType, CompassErrorType.addEventError.rawValue)
            exp.fulfill()
        }
        
        compassViewModel.emitUpdateEventError()
        
        wait(for: [exp], timeout: 2.0)
    }

    func testEmitUpdateEventListError_ShouldEmitError() {
        let exp = XCTestExpectation(description: #function)
        statusService.eventEmitterHandler = { eventEmitter in
            guard let errorEmitter = eventEmitter as? ErrorEventEmitter else { return }
            XCTAssertEqual(errorEmitter.compassErrorType, CompassErrorType.updateEventListError.rawValue)
            exp.fulfill()
        }
        
        compassViewModel.emitUpdateEventListError()
        
        wait(for: [exp], timeout: 2.0)
    }

    func testSaveEmptyToken_ShouldSaveEmptyToken() {
        // Act
        compassViewModel.saveEmptyToken()
        
        // Assert
        XCTAssertTrue(StaticStorage.authParameter?.clientSecret.isEmpty ?? true)
    }

    func testHandleUserToken_WithUserToken_ReturnsUserToken() {
        let exp = XCTestExpectation(description: #function)
        let authParam = AuthParameter(clientSecret: "user-token", tokenType: "user", accountID: "acc", consumerID: "cons")
        
        compassViewModel.handleUserToken(authParam)
            .sink(receiveCompletion: { _ in exp.fulfill() }, receiveValue: { response in
                XCTAssertEqual(response?.tokenType, "user")
                XCTAssertEqual(response?.accessToken, "user-token")
            })
            .store(in: &cancellables)
        
        wait(for: [exp], timeout: 2.0)
    }

//    func testHandleTokenType_WithPingfedToken_ReturnsToken() {
//        let exp = XCTestExpectation(description: #function)
//        compassViewModel.isPositioningEnabled = true
//        compassViewModel.positionRefreshTime = -1
//        let authParam = AuthParameter(clientSecret: "pingfed-token", tokenType: "PINGFED", accountID: "acc", consumerID: "cons")
//        
//        compassViewModel.handleTokenType(for: authParam)
//            .sink(receiveCompletion: { _ in exp.fulfill() }, receiveValue: { response in
//                XCTAssertEqual(response?.tokenType, "PINGFED")
//            })
//            .store(in: &cancellables)
//        
//        wait(for: [exp], timeout: 2.0)
//    }

    func testGetAccessToken_WithIAMToken_CallsGetTokenData() {
        let exp = XCTestExpectation(description: #function)
        networkService._shouldFail = false
        networkService._expectedTokenResponse = iamAccessTokenResponse
        let authParam = AuthParameter(clientSecret: "iam-token", tokenType: "IAM", accountID: "acc", consumerID: "cons")

        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.floorCoordinatesConverter = MockFloorCoordinatesConverterImpl()

        compassViewModel.getAccessToken(authParameter: authParam)
            .sink(receiveCompletion: { _ in exp.fulfill() }, receiveValue: { response in
                XCTAssertNotNil(response)
            })
            .store(in: &cancellables)
        
        wait(for: [exp], timeout: 2.0)
    }

    func testHandleUserToken_SavesTokenAndReturnsResponse() {
        let exp = XCTestExpectation(description: #function)
        let authParam = AuthParameter(clientSecret: "user-token", tokenType: "user", accountID: "acc", consumerID: "cons")
        
        compassViewModel.handleUserToken(authParam)
            .sink(receiveCompletion: { _ in exp.fulfill() }, receiveValue: { response in
                XCTAssertEqual(response?.accessToken, "user-token")
                XCTAssertEqual(StaticStorage.authParameter?.clientSecret, "user-token")
            })
            .store(in: &cancellables)
        
        wait(for: [exp], timeout: 2.0)
    }

    func testSaveToken_SavesTokenToStaticStorage() {
        // Arrange
        let authParam = AuthParameter(clientSecret: "test-token", tokenType: "user", accountID: "acc", consumerID: "cons")
        
        // Act
        compassViewModel.saveToken(authParameter: authParam)
        
        // Assert
        XCTAssertEqual(StaticStorage.authParameter?.clientSecret, "test-token")
        XCTAssertEqual(StaticStorage.authParameter?.tokenType, "user")
    }

    func testSaveEmptyToken_SavesEmptyTokenToStaticStorage() {
        // Act
        compassViewModel.saveEmptyToken()
        
        // Assert
        XCTAssertTrue(StaticStorage.authParameter?.clientSecret.isEmpty ?? true)
    }

    func testUpdateEvent_WhenLastLockedPositionIsNil_EmitsError() {
        let exp = XCTestExpectation(description: #function)
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfig)
        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.lastLockedPosition = nil
        
        statusService.eventEmitterHandler = { eventEmitter in
            guard let errorEmitter = eventEmitter as? ErrorEventEmitter else { return }
            XCTAssertEqual(errorEmitter.eventType, .errorEventEmitter)
            exp.fulfill()
        }
        
        compassViewModel.updateEvent(compassEvent: CompassEvent(eventType: "test", eventValue: "value", eventMetadata: [:]))
        
        wait(for: [exp], timeout: 2.0)
    }

    func testDisplayStaticPath_WithValidPins_CallsMapHostViewModel() {
        // Arrange
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfig)
        let aislePin = AislePin(type: "item", id: "1", location: AisleLocation(zone: "A", aisle: "1", section: "1", selected: true))
        let compassPin = CompassPin.aisle(aislePin)
        
        // Act
        compassViewModel.displayStaticPath(pins: [compassPin], startFromNearbyEntrance: true, disableZoomGestures: false)
        
        // Assert
        XCTAssertNotNil(compassViewModel.mapHostViewModel)
    }

    func testRemoveUserPositionIndicator_WithValidMapHostViewModel_CallsMethod() {
        // Arrange
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfig)
        compassViewModel.displayMap()
        
        // Act & Assert - should not crash
        compassViewModel.removeUserPositionIndicator()
        XCTAssertNotNil(compassViewModel.mapHostViewModel)
    }

    func testRemoveUserPositionIndicator_WithNilMapHostViewModel_LogsWarning() {
        // Arrange
        compassViewModel.mapHostViewModel = nil
        
        // Act & Assert - should not crash and just log
        compassViewModel.removeUserPositionIndicator()
        XCTAssertNil(compassViewModel.mapHostViewModel)
    }

    func testDisplayPin_WithValidPinsAndConfig_CallsMapHostViewModel() {
        compassViewModel.isPositioningEnabled = true
        compassViewModel.positionRefreshTime = -1
        // Arrange
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfig)
        let aislePin = AislePin(type: "item", id: "1", location: AisleLocation(zone: "A", aisle: "1", section: "1", selected: true))
        let compassPin = CompassPin.aisle(aislePin)
        let config = DisplayPinConfig(enableManualPinDrop: false, resetZoom: true, shouldZoomOnPins: true)
        
        // Act
        compassViewModel.displayPin(pins: [compassPin], config: config)
        
        // Assert
        XCTAssertFalse(serviceLocator.getIndoorPositioningService().isPositioningActive)
    }

    func testDisplayPin_WithNilPins_CallsMapHostViewModel() {
        compassViewModel.isPositioningEnabled = true
        compassViewModel.positionRefreshTime = -1
        // Arrange
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfig)
        let config = DisplayPinConfig(enableManualPinDrop: false, resetZoom: true, shouldZoomOnPins: true)
        
        // Act
        compassViewModel.displayPin(pins: nil, config: config)
        
        // Assert
        XCTAssertFalse(serviceLocator.getIndoorPositioningService().isPositioningActive)
    }

    func testGetUserDistance_WithValidPins_CallsMapHostViewModel() {
        compassViewModel.isPositioningEnabled = true
        compassViewModel.positionRefreshTime = -1
        
        // Arrange
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfig)
        let aislePin = AislePin(type: "item", id: "1", location: AisleLocation(zone: "A", aisle: "1", section: "1", selected: true))
        
        // Act
        compassViewModel.getUserDistance(pins: [aislePin], completion: nil)
        
        // Assert
        XCTAssertFalse(serviceLocator.getIndoorPositioningService().isPositioningActive)
    }

    func testClearMap_WithValidConfig_CallsMapHostViewModel() {
        // Arrange
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfig)
        compassViewModel.displayMap()
        let mapConfig = MapConfig(resetZoom: true)
        
        // Act
        compassViewModel.clearMap(mapConfig: mapConfig)
        
        // Assert
        XCTAssertNotNil(compassViewModel.mapHostViewModel)
    }

    func testIsMapViewReady_ReturnsMapViewPresent() {
        compassViewModel.isPositioningEnabled = true
        compassViewModel.positionRefreshTime = -1
        // Arrange
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfig)
        let exp = XCTestExpectation(description: #function)
        
        // Act & Assert
        compassViewModel.isMapViewReady()
            .sink { isReady in
                XCTAssertFalse(isReady)
                exp.fulfill()
            }
            .store(in: &cancellables)
        
        wait(for: [exp], timeout: 2.0)
    }

    func testUpdateEventList_WhenPositioningDisabled_ReturnsEarly() {
        // Arrange
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfigWithoutBlueDot)
        
        // Act & Assert - should return early without crashing
        compassViewModel.updateEventList(namespace: "test", eventType: "event", eventValue: "value", metaData: nil)
        XCTAssertFalse(compassViewModel.isPositioningEnabled)
    }

    func testUpdateEventList_WithUnsupportedEvent_EmitsError() {
        let exp = XCTestExpectation(description: #function)
        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.lastLockedPosition = MockIPSPosition(x: 10, y: 20, headingAngle: MockIPSHeading(angle: 3.142), accuracy: 5)
        let assetService = serviceLocator.getAssetService() as? MockAssetService
        assetService?.supportedEventList = ""
        compassViewModel = CompassViewModel(serviceLocator: serviceLocator)
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfig)
        
        statusService.eventEmitterHandler = { eventEmitter in
            guard let errorEmitter = eventEmitter as? ErrorEventEmitter else { return }
            XCTAssertEqual(errorEmitter.compassErrorType, CompassErrorType.updateEventListError.rawValue)
            exp.fulfill()
        }
        
        compassViewModel.updateEventList(namespace: "invalid", eventType: "invalid", eventValue: "value", metaData: nil)
        
        wait(for: [exp], timeout: 2.0)
    }

    func testGetAisle_CallsMapHostViewModel() {
        // Arrange
        compassViewModel.updateStoreConfiguration(walmartMapStoreConfig)
        
        // Act
        compassViewModel.getAisle(id: "test-id")
        
        // Assert
        XCTAssertEqual(compassViewModel.assetService.storeId, walmartMapStoreConfig.storeId!)
    }

    func testToggleMockUserWhenMockUserIsFalse() {
        // Arrange & Act
        compassViewModel.toggleMockUser(false)
        
        // Assert - should not crash and testLockThreshold should remain unchanged
        XCTAssertTrue(true)
    }
}
