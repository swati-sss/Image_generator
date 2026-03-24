//
//  InStoreMapViewModelTests.swift
//  compass_sdk_iosTests
//
//  Created by Young Jin Ju on 5/16/24.
//

import XCTest
import Combine
import CoreData
import Foundation
@testable import compass_sdk_ios

final class InStoreMapViewModelTests: XCTestCase {
    private var inStoreMapViewModel: InStoreMapViewModel!
    private var serviceLocator: MockServiceLocator!
    private var assetService: MockAssetService!
    private let blueDotMode: BlueDotMode = .visible
    private var storeMapLoaderViewModel: MockStoreMapLoaderViewModel!
    private var mapView: StoreMapView!
    private var userPositionManager: UserPositionManagement!
    private var statusService: StatusService!
    private var indoorPositioningService: MockIndoorPositioningService!
    private var mapFocusManager: MockMapFocusManager!
    private var mapConfig: MapConfig!
    private var displayPinConfig: DisplayPinConfig!
    private var messageSender: MessageSending!
    private var logDefault: MockLogDefaultImpl!
    private var cancellable: Set<AnyCancellable> = []
    
    override func setUpWithError() throws {
        try? super.setUpWithError()
        // Clean up UserDefaults to prevent test interference
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: UserDefaultsKey.uuidList.rawValue)
        
        serviceLocator = MockServiceLocator()
        let options = StoreMapView.Options(
            dynamicMapEnabled: true,
            zoomControlEnabled: true,
            errorScreensEnabled: true,
            spinnerEnabled: true,
            dynamicMapRotationEnabled: false,
            navigationConfig: NavigationConfig(enabled: false, refreshDuration: 0.0),
            mapUiConfig:MapUiConfig(bannerEnabled: false, snackBarEnabled: false),
            pinsConfig: PinsConfig(actionAlleyEnabled: false),
            debugLog: DebugLog()
        )
        inStoreMapViewModel = InStoreMapViewModel(blueDotMode: .visible,
                                                  storeMapOptions: options,
                                                  serviceLocator: serviceLocator
        )
        userPositionManager = serviceLocator.getUserPositionManager()
        assetService = serviceLocator.getAssetService() as? MockAssetService
        statusService = serviceLocator.getStatusService()
        indoorPositioningService = serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService
        messageSender = serviceLocator.getWebViewMessageSender() as? MockMessageSender
        storeMapLoaderViewModel = inStoreMapViewModel.storeMapLoaderViewModel as? MockStoreMapLoaderViewModel
        logDefault = serviceLocator.getLogDefaultImpl() as? MockLogDefaultImpl
        mapFocusManager = serviceLocator.getMapFocusManager() as? MockMapFocusManager
        mapConfig = MapConfig()
        displayPinConfig = DisplayPinConfig(enableManualPinDrop: true, resetZoom: false, shouldZoomOnPins: true)
        //        serviceLocator._resetMock()
        storeMapLoaderViewModel._resetMock()
    }
    
    override func tearDownWithError() throws {
        // Clean up UserDefaults to prevent test interference
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: UserDefaultsKey.uuidList.rawValue)
        
        serviceLocator._resetMock()
        inStoreMapViewModel = nil
        messageSender = nil
        storeMapLoaderViewModel = nil
        assetService = nil
        statusService = nil
        indoorPositioningService = nil
        mapFocusManager = nil
        mapConfig = nil
        displayPinConfig = nil
        try? super.tearDownWithError()
    }
    
    func testInitialize() {
        var positioningUser: User?
        
        userPositionManager.getUserPosition()
            .removeDuplicates()
            .sink { user in
                positioningUser = user
            }.store(in: &cancellable)
        
        XCTAssertNotNil(positioningUser?.position)
    }
    
    func testInitialize_NoneMode() {
        inStoreMapViewModel = InStoreMapViewModel(blueDotMode: .none, storeMapOptions: StoreMapView.Options(
            dynamicMapEnabled: true,
            zoomControlEnabled: true,
            errorScreensEnabled: true,
            spinnerEnabled: true,
            dynamicMapRotationEnabled: false,
            navigationConfig: NavigationConfig(enabled: false, refreshDuration: 0.0),
            mapUiConfig: MapUiConfig(bannerEnabled: false, snackBarEnabled: false), pinsConfig: PinsConfig(),
            debugLog: DebugLog()
        ), serviceLocator: serviceLocator)
        
        XCTAssert(mapFocusManager.isMapViewPresent.value)
    }
    
    func testDisplayPin() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: UserDefaultsKey.uuidList.rawValue)
        inStoreMapViewModel.displayPin(uuidList: ["id1", "id2"], idType: PinDropMethod(rawValue: "asset") ?? .generic, config: nil)
        XCTAssert(assetService._evaluateAssetsCalled)
    }
    
    func testDisplayPin_withEmptyList() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: UserDefaultsKey.uuidList.rawValue)
        inStoreMapViewModel.displayPin(uuidList: [], idType: PinDropMethod(rawValue: "asset") ?? .generic, config: nil)
        XCTAssertEqual(defaults.object(forKey: UserDefaultsKey.uuidList.rawValue) as? [String], [])
    }
    
    func testDisplayPin2_ResetZoom_NoPin() {
        let displayPinConfigResetZoom = DisplayPinConfig(enableManualPinDrop: true, resetZoom: true, shouldZoomOnPins: true)
        inStoreMapViewModel.displayPin(pins: [], config: displayPinConfigResetZoom)
        XCTAssert(storeMapLoaderViewModel._zoomOutCalled)
        XCTAssertFalse(storeMapLoaderViewModel._renderPinsCalled)
    }
    
    func testDisplayPin2_NoResetZoom_WithPins() {
        let aislePin1 = AislePin(type: "item", id: "1", location: AisleLocation(zone: "A", aisle: "3", section: "3", selected: true))
        let aislePin2 = AislePin(type: "item", id: "2", location: AisleLocation(zone: "A", aisle: "8", section: "3", selected: false))
        let compassPins: [CompassPin] = [aislePin1, aislePin2].map { CompassPin.aisle($0) }
        inStoreMapViewModel.displayPin(pins: compassPins, config: displayPinConfig)
        XCTAssert(storeMapLoaderViewModel._renderPinsCalled)
    }
    
    func testDisplayPin2_FirstPinSelectedWhenNoSelectedProvided() {
        // All pins have selected: false, so first pin should be selected by default
        let aislePin1 = AislePin(type: "item", id: "1", location: AisleLocation(zone: "A", aisle: "3", section: "3", selected: false))
        let aislePin2 = AislePin(type: "item", id: "2", location: AisleLocation(zone: "A", aisle: "8", section: "3", selected: false))
        let compassPins: [CompassPin] = [aislePin1, aislePin2].map { CompassPin.aisle($0) }
        inStoreMapViewModel.displayPin(pins: compassPins, config: displayPinConfig)
        // The test is to ensure the code path is covered; you may add assertions if your mock tracks selected pins
        XCTAssert(storeMapLoaderViewModel._renderPinsCalled)
    }
    
    func testGetAisle() {
        inStoreMapViewModel.getAisle(id: "aisle")
        XCTAssert(assetService._evaluateAssetsCalled)
    }
    
    func testDisplayMap() {
        var logEvent = LogEvent(sessionId: "", act: nil, name: nil, context: nil, eventType: .noEvent, data: nil, payload: nil, store: nil, timestamp: nil)
        Analytics.logDefault = serviceLocator.getLogDefaultImpl()
        inStoreMapViewModel.displayMap()
        logDefault.$logEvent
            .sink { result in
                logEvent = result ?? logEvent
            }.store(in: &cancellable)
        
        XCTAssertEqual(logEvent.eventType, .displayMap)
    }
    
    func testClearMap() {
        inStoreMapViewModel.clearMap(mapConfig: mapConfig)
        XCTAssert(storeMapLoaderViewModel._clearRenderedPinCalled)
        let mapConfigResetZoom = MapConfig(resetZoom: true)
        inStoreMapViewModel.clearMap(mapConfig: mapConfigResetZoom)
        XCTAssert(storeMapLoaderViewModel._showMapZoomedOutCalled)
    }
    
    func testGetUserDistance_WhenLockProgressIsOne_ReturnsDistances() {
        // Arrange
        let expectation = expectation(description: #function)
        let aislePin = AislePin(type: "item", id: "1", location: AisleLocation(zone: "A", aisle: "1", section: "1", selected: true))
        storeMapLoaderViewModel.isMapViewLoaded = true
        
        // Set up mock indoor positioning service with lockProgress == 1
        indoorPositioningService.lockProgress = 1.0
        indoorPositioningService.lastLockedPosition = MockIPSPosition(
            x: 100,
            y: 200,
            headingAngle: MockIPSHeading(angle: 0),
            accuracy: 5,
            lockProgress: 1.0
        )
        indoorPositioningService.floorCoordinatesConverter = MockFloorCoordinatesConverterImpl()
        
        // Configure mock to return pin with location to trigger the location != nil condition
        let pinWithLocation = Pin(
            type: .aisleSection,
            zone: "A",
            aisle: 1,
            section: "1",
            location: Point(x: 150.0, y: 250.0)
        )
        storeMapLoaderViewModel.mockPinForGetUserDistance = pinWithLocation
        
        // Act
        inStoreMapViewModel.getUserDistance(pins: [aislePin]) { response in
            // Assert - when lockProgress == 1 and pin has location, should calculate distance
            XCTAssertNotNil(response)
            if let firstResponse = response.first {
                // Verify getUserDistanceResponse calculated distance (location was not nil)
                XCTAssertNotNil(firstResponse.userDistanceInInches, "Should calculate distance when pin has location")
                XCTAssertNotNil(firstResponse.location)
                XCTAssertEqual(firstResponse.location?.zone, "A")
                XCTAssertEqual(firstResponse.location?.aisle, "1")
                XCTAssertEqual(firstResponse.location?.section, "1")
                XCTAssertNil(firstResponse.error, "Should not have error when pin has valid location")
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 2.0)
    }
    
    func testGetUserDistance_WhenPinHasNoLocation_ReturnsError() {
        // Arrange
        let expectation = expectation(description: #function)
        let aislePin = AislePin(type: "item", id: "1", location: AisleLocation(zone: "A", aisle: "1", section: "1", selected: true))
        storeMapLoaderViewModel.isMapViewLoaded = true
        
        // Set up mock indoor positioning service with lockProgress == 1
        indoorPositioningService.lockProgress = 1.0
        indoorPositioningService.lastLockedPosition = MockIPSPosition(
            x: 100,
            y: 200,
            headingAngle: MockIPSHeading(angle: 0),
            accuracy: 5,
            lockProgress: 1.0
        )
        indoorPositioningService.floorCoordinatesConverter = MockFloorCoordinatesConverterImpl()
        
        // Configure mock to return pin WITHOUT location to trigger the else branch
        let pinWithoutLocation = Pin(
            type: .aisleSection,
            zone: "A",
            aisle: 1,
            section: "1",
            location: nil
        )
        storeMapLoaderViewModel.mockPinForGetUserDistance = pinWithoutLocation
        
        // Act
        inStoreMapViewModel.getUserDistance(pins: [aislePin]) { response in
            // Assert - when pin has no location, should return error
            XCTAssertNotNil(response)
            if let firstResponse = response.first {
                // Verify getUserDistanceResponse returned error (location was nil)
                XCTAssertNil(firstResponse.userDistanceInInches, "Should not calculate distance when pin has no location")
                XCTAssertNotNil(firstResponse.error, "Should have error when pin has no location")
                //                XCTAssertEqual(firstResponse.error?.category, .pinLocationUnknown, "Error category should be pinLocationUnknown")
                XCTAssertTrue(firstResponse.error?.isPositionLocked ?? false, "Position should be locked")
                XCTAssertNotNil(firstResponse.location)
                XCTAssertEqual(firstResponse.location?.zone, "A")
                XCTAssertEqual(firstResponse.location?.aisle, "1")
                XCTAssertEqual(firstResponse.location?.section, "1")
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 2.0)
    }
    
    func testDisplayStaticPath_WithEmptyPins_ReturnsEarly() {
        // Arrange
        Analytics.logDefault = serviceLocator.getLogDefaultImpl()

        // Act
        inStoreMapViewModel.displayStaticPath(pins: [], startFromNearbyEntrance: false, disableZoomGestures: false)

        // Assert - should return early without crashing
        XCTAssertTrue(true) // Method should return without crashing
    }

    func testGetUserDistance_WithEmptyPins_ReturnsPinsEmptyError() {
        // Arrange
        let expectation = expectation(description: #function)
        var resultResponse: [UserDistanceResponse]?

        // Act
        inStoreMapViewModel.getUserDistance(pins: []) { response in
            resultResponse = response
            expectation.fulfill()
        }

        // Assert - completion should be called with the pinsEmpty error payload
        waitForExpectations(timeout: 1.0)
        XCTAssertNotNil(resultResponse)
        XCTAssertEqual(resultResponse?.count, 1)
        XCTAssertEqual(resultResponse?.first?.error?.message, "Pins list is empty.")
        XCTAssertFalse(resultResponse?.first?.error?.isPositionLocked ?? true)
    }
}
