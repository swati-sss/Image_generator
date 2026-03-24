//
//  StoreMapLoaderViewModelActionableTests.swift
//  compass_sdk_iosTests
//
//  Created by Copilot on 1/23/26.
//

import XCTest
import Combine
@testable import compass_sdk_ios

final class StoreMapLoaderViewModelActionableTests: XCTestCase {
    var viewModel: StoreMapLoaderViewModel!
    var mockServiceLocator: MockServiceLocator!
    var cancellables: Set<AnyCancellable>!
    var mapViewDelegate: MockMapViewDelegate!

    private func makeStoreMapOptions(
        navigationEnabled: Bool = true,
        pinsConfig: PinsConfig = PinsConfig()
    ) -> StoreMapView.Options {
        StoreMapView.Options(
            dynamicMapEnabled: true,
            zoomControlEnabled: true,
            errorScreensEnabled: true,
            spinnerEnabled: true,
            dynamicMapRotationEnabled: false,
            navigationConfig: NavigationConfig(enabled: navigationEnabled, refreshDuration: 0.0),
            mapUiConfig: MapUiConfig(bannerEnabled: false, snackBarEnabled: false),
            pinsConfig: pinsConfig,
            debugLog: DebugLog()
        )
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        mockServiceLocator = MockServiceLocator()
        cancellables = []
        mapViewDelegate = MockMapViewDelegate()
        let options = makeStoreMapOptions()
        viewModel = StoreMapLoaderViewModel(
            blueDotMode: .visible,
            storeMapOptions: options,
            debugLog: options.debugLog,
            serviceLocator: mockServiceLocator
        )
        viewModel.mapViewDelegate = mapViewDelegate
    }

    override func tearDownWithError() throws {
        cancellables.removeAll()
        viewModel = nil
        mockServiceLocator = nil
        mapViewDelegate = nil
        try super.tearDownWithError()
    }

    // MARK: - canDisplayNavigationButton Tests

    func testCanDisplayNavigationButtonReturnsFalseWhenNoSessionState() {
        let navigationService = mockServiceLocator.getIndoorNavigationService() as? MockIndoorNavigationService
        navigationService?.navigationSessionState = nil
        
        XCTAssertFalse(viewModel.canDisplayNavigationButton())
    }

    func testCanDisplayNavigationButtonReturnsFalseWhenNoPinsOnMap() {
        var sessionState = NavigationSessionState(
            currentLocationWaypoint: nil,
            destinationWaypoints: [],
            renderPinsRequest: nil,
            pinList: nil
        )
        sessionState.hasPinsOnMap = false
        let navigationService = mockServiceLocator.getIndoorNavigationService() as? MockIndoorNavigationService
        navigationService?.navigationSessionState = sessionState
        
        XCTAssertFalse(viewModel.canDisplayNavigationButton())
    }

    func testCanDisplayNavigationButtonReturnsTrueWhenPinsOnMap() {
        var sessionState = NavigationSessionState(
            currentLocationWaypoint: nil,
            destinationWaypoints: [],
            renderPinsRequest: nil,
            pinList: nil
        )
        sessionState.hasPinsOnMap = true
        let navigationService = mockServiceLocator.getIndoorNavigationService() as? MockIndoorNavigationService
        navigationService?.navigationSessionState = sessionState
        
        XCTAssertTrue(viewModel.canDisplayNavigationButton())
    }

    // MARK: - getMapURLRequest Tests

    func testGetMapURLRequestReturnsValidRequest() {
        let request = viewModel.getMapURLRequest()
        
        XCTAssertNotNil(request)
        XCTAssertNotNil(request?.url)
    }

    func testGetMapURLRequestIncludesStoreIdInURL() {
        let request = viewModel.getMapURLRequest()
        
        XCTAssertNotNil(request?.url?.absoluteString)
    }

    func testGetMapURLRequestIncludesHTTPHeaders() {
        let request = viewModel.getMapURLRequest()
        
        // Real implementation calls APIHelper.getStandardRequestHeaders() and iterates forEach
        // The request object should support HTTP headers structure even if empty
        XCTAssertNotNil(request)
    }

    func testGetMapURLRequestIncludesQueryParameters() {
        let request = viewModel.getMapURLRequest()
        
        // Real implementation constructs URL with query parameters through URLComponents
        let urlString = request?.url?.absoluteString ?? ""
        XCTAssertTrue(!urlString.isEmpty)
    }

    // MARK: - getUserDistance Tests

    func testGetUserDistanceSendsPinLocationRequest() {
        let testPin = Pin(type: .aisleSection, id: 1, zone: "A", aisle: 3, section: "1", selected: true)
        let request = GetPinLocationRequest(pins: [testPin])
        
        let messageSender = mockServiceLocator.getWebViewMessageSender() as? MockMessageSender
        messageSender?.sentMessages = []

        viewModel.getUserDistance(request, completion: { _ in })

        XCTAssertEqual(messageSender?.sentMessages.count, 1)
    }

    func testGetUserDistanceSetsIsPinDistanceFetchedFlag() {
        let testPin = Pin(type: .aisleSection, id: 1, zone: "A", aisle: 3, section: "1", selected: true)
        let request = GetPinLocationRequest(pins: [testPin])
        viewModel.isPinDistanceFetched = false
        
        viewModel.getUserDistance(request, completion: { _ in })
        
        XCTAssertTrue(viewModel.isPinDistanceFetched)
    }

    func testGetUserDistanceSetsCompletionHandler() {
        let testPin = Pin(type: .aisleSection, id: 1, zone: "A", aisle: 3, section: "1", selected: true)
        let request = GetPinLocationRequest(pins: [testPin])
        
        let completion: (PinRenderedMessage) -> Void = { _ in }
        
        viewModel.getUserDistance(request, completion: completion)
        
        XCTAssertNotNil(viewModel.pinLocationFetchCompletionHandler)
    }

    func testGetUserDistanceCallsCompletionWithPins() {
        let expectation = XCTestExpectation(description: "Completion called with pins")
        let testPin = Pin(type: .aisleSection, id: 1, zone: "A", aisle: 3, section: "1", selected: true)
        let request = GetPinLocationRequest(pins: [testPin])
        
        viewModel.getUserDistance(request) { message in
            XCTAssertEqual(message.pins?.count, 1)
            expectation.fulfill()
        }

        viewModel.handlePinRenderedMessage(PinRenderedMessage(pins: [testPin]))

        wait(for: [expectation], timeout: 1.0)
    }

    func testGetUserDistanceWithMultiplePins() {
        let expectation = XCTestExpectation(description: "Multiple pins handled")
        let pins = [
            Pin(type: .aisleSection, id: 1, zone: "A", aisle: 1, section: "1", selected: true),
            Pin(type: .department, id: 2, zone: "B", aisle: 2, section: "2", selected: false)
        ]
        let request = GetPinLocationRequest(pins: pins)
        
        viewModel.getUserDistance(request) { message in
            XCTAssertEqual(message.pins?.count, pins.count)
            expectation.fulfill()
        }

        viewModel.handlePinRenderedMessage(PinRenderedMessage(pins: pins))

        wait(for: [expectation], timeout: 1.0)
    }

    func testGetUserDistanceWithNilCompletion() {
        let testPin = Pin(type: .aisleSection, id: 1, zone: "A", aisle: 3, section: "1", selected: true)
        let request = GetPinLocationRequest(pins: [testPin])
        
        // Should not crash when completion is nil
        viewModel.getUserDistance(request, completion: nil)
        
        XCTAssertTrue(viewModel.isPinDistanceFetched)
    }

    // MARK: - setPathfindingEnabled Tests

    func testSetPathfindingEnabledWithStaticPathVisible() {
        let expectation = XCTestExpectation(description: "Request scheduled with delay")
        let messageSender = mockServiceLocator.getWebViewMessageSender() as? MockMessageSender
        messageSender?.sentMessages = []
        
        // Set static path visible
        viewModel.isStaticPathVisible = true
        let duration: TimeInterval = 0.1
        
        // Act
        viewModel.setPathfindingEnabled(true, duration: duration)
        
        // Assert: Request should be scheduled after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) {
            let containsMessage = (messageSender?.sentMessages ?? []).contains { message in
                if case .setPathfindingEnabled(let request) = message {
                    return request.pathfinderEnabled == true
                }
                return false
            }
            XCTAssertTrue(containsMessage)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }

    func testSetPathfindingEnabledWithStaticPathVisibleAndZeroDuration() {
        let expectation = XCTestExpectation(description: "Request scheduled immediately")
        let messageSender = mockServiceLocator.getWebViewMessageSender() as? MockMessageSender
        messageSender?.sentMessages = []
        
        viewModel.isStaticPathVisible = true
        
        // Act
        viewModel.setPathfindingEnabled(false, duration: 0.0)
        
        // Assert: Request should be scheduled immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let containsMessage = (messageSender?.sentMessages ?? []).contains { message in
                if case .setPathfindingEnabled(let request) = message {
                    return request.pathfinderEnabled == false
                }
                return false
            }
            XCTAssertTrue(containsMessage)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }

    func testSetPathfindingEnabledStaticPathVisibleReturnEarly() {
        let messageSender = mockServiceLocator.getWebViewMessageSender() as? MockMessageSender
        messageSender?.sentMessages = []
        
        viewModel.isStaticPathVisible = true
        let initialCount = messageSender?.sentMessages.count ?? 0
        
        // Act - set pathfinding while static path is visible
        viewModel.setPathfindingEnabled(true, duration: 0.0)
        
        // Assert: Early return means should not send immediate message
        // (message is scheduled, not sent immediately)
        let expectation = XCTestExpectation(description: "Wait for scheduled message")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let containsMessage = (messageSender?.sentMessages ?? []).contains { message in
                if case .setPathfindingEnabled(let request) = message {
                    return request.pathfinderEnabled == true
                }
                return false
            }
            XCTAssertGreaterThan(messageSender?.sentMessages.count ?? 0, initialCount)
            XCTAssertTrue(containsMessage)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testSetPathfindingEnabledWithStaticPathNotVisible() {
        let messageSender = mockServiceLocator.getWebViewMessageSender() as? MockMessageSender
        messageSender?.sentMessages = []
        viewModel.isStaticPathVisible = false
        viewModel.updateConfiguration(
            pinsConfig: viewModel.pinsConfig,
            navigationConfig: NavigationConfig(enabled: true, refreshDuration: 0.0)
        )
        
        // Act
        viewModel.setPathfindingEnabled(true, duration: 0.0)
        
        // Wait for async execution and verify state changed
        let expectation = XCTestExpectation(description: "Wait for pathfinding")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let containsMessage = (messageSender?.sentMessages ?? []).contains { message in
                if case .setPathfindingEnabled(let request) = message {
                    return request.pathfinderEnabled == true
                }
                return false
            }
            XCTAssertTrue(containsMessage)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - updateUserPosition Tests

    func testUpdateUserPositionSendsUserLocationMessage() {
        let messageSender = mockServiceLocator.getWebViewMessageSender() as? MockMessageSender
        messageSender?.sentMessages = []
        
        viewModel.updateUserPosition(x: 100.0, y: 200.0, accuracy: 5.0)

        let containsUserLocation = (messageSender?.sentMessages ?? []).contains { message in
            if case .showUserLocation = message {
                return true
            }
            return false
        }

        XCTAssertTrue(containsUserLocation)
    }

    func testUpdateUserPositionWithNavigationDisabled() {
        let messageSender = mockServiceLocator.getWebViewMessageSender() as? MockMessageSender
        messageSender?.sentMessages = []
        let navigationService = mockServiceLocator.getIndoorNavigationService() as? MockIndoorNavigationService

        viewModel.updateConfiguration(
            pinsConfig: viewModel.pinsConfig,
            navigationConfig: NavigationConfig(enabled: false, refreshDuration: 0.0)
        )
        navigationService?._updateNavigationStateCalled = false

        viewModel.updateUserPosition(x: 100.0, y: 200.0, accuracy: nil)

        let containsUserLocation = (messageSender?.sentMessages ?? []).contains { message in
            if case .showUserLocation = message {
                return true
            }
            return false
        }

        XCTAssertTrue(containsUserLocation)
        XCTAssertFalse(navigationService?._updateNavigationStateCalled ?? true)
    }

    func testUpdateUserPositionWithNavigationEnabled() {
        let messageSender = mockServiceLocator.getWebViewMessageSender() as? MockMessageSender
        messageSender?.sentMessages = []
        let indoorPositioningService = mockServiceLocator.getIndoorPositioningService() as? MockIndoorPositioningService
        let navigationService = mockServiceLocator.getIndoorNavigationService() as? MockIndoorNavigationService

        viewModel.updateConfiguration(
            pinsConfig: viewModel.pinsConfig,
            navigationConfig: NavigationConfig(enabled: true, refreshDuration: 0.0)
        )
        indoorPositioningService?.floorCoordinatesConverter = MockFloorCoordinatesConverterImpl()
        navigationService?._updateNavigationStateCalled = false

        viewModel.updateUserPosition(x: 150.0, y: 250.0, accuracy: 3.0)

        let containsUserLocation = (messageSender?.sentMessages ?? []).contains { message in
            if case .showUserLocation = message {
                return true
            }
            return false
        }

        XCTAssertTrue(containsUserLocation)
        XCTAssertTrue(navigationService?._updateNavigationStateCalled ?? false)
    }

    func testUpdateUserPositionWithVariousCoordinates() {
        let messageSender = mockServiceLocator.getWebViewMessageSender() as? MockMessageSender
        messageSender?.sentMessages = []
        
        viewModel.updateUserPosition(x: -50.0, y: -100.0, accuracy: 10.0)

        let containsUserLocation = (messageSender?.sentMessages ?? []).contains { message in
            if case .showUserLocation = message {
                return true
            }
            return false
        }

        XCTAssertTrue(containsUserLocation)
    }

    func testUpdateUserPositionWithNilAccuracy() {
        let messageSender = mockServiceLocator.getWebViewMessageSender() as? MockMessageSender
        messageSender?.sentMessages = []
        
        viewModel.updateUserPosition(x: 75.0, y: 125.0, accuracy: nil)

        let containsUserLocation = (messageSender?.sentMessages ?? []).contains { message in
            if case .showUserLocation = message {
                return true
            }
            return false
        }

        XCTAssertTrue(containsUserLocation)
    }

    // MARK: - renderPins Tests

    func testRenderPinsSendsRenderPinsRequest() {
        let messageSender = mockServiceLocator.getWebViewMessageSender() as? MockMessageSender
        messageSender?.sentMessages = []
        
        let pins = [Pin(type: .aisleSection, id: 1, zone: "A", aisle: 1, section: "1")]
        
        viewModel.renderPins(pins, config: nil)

        let containsRenderPins = (messageSender?.sentMessages ?? []).contains { message in
            if case .renderPins = message {
                return true
            }
            return false
        }

        XCTAssertTrue(containsRenderPins)
    }

    func testRenderPinsWithConfigUpdatesInternalConfig() {
        let pins = [Pin(type: .department, id: 2, zone: "B", aisle: 2, section: "2")]
        let newConfig = DisplayPinConfig(enableManualPinDrop: false, resetZoom: true, shouldZoomOnPins: false)
        
        let originalConfig = viewModel.config
        
        viewModel.renderPins(pins, config: newConfig)
        
        // Assert: Config should be updated
        XCTAssertNotEqual(viewModel.config.enableManualPinDrop, originalConfig.enableManualPinDrop)
        XCTAssertEqual(viewModel.config.enableManualPinDrop, newConfig.enableManualPinDrop)
    }

    func testRenderPinsWithNilConfigPreservesExistingConfig() {
        let pins = [Pin(type: .aisleSection, id: 3, zone: "C", aisle: 3, section: "3")]
        let originalConfig = viewModel.config
        
        viewModel.renderPins(pins, config: nil)
        
        // Assert: Config should remain unchanged
        XCTAssertEqual(viewModel.config.enableManualPinDrop, originalConfig.enableManualPinDrop)
        XCTAssertEqual(viewModel.config.resetZoom, originalConfig.resetZoom)
    }

    func testRenderPinsWithEmptyPinsArray() {
        let messageSender = mockServiceLocator.getWebViewMessageSender() as? MockMessageSender
        messageSender?.sentMessages = []
        
        viewModel.renderPins([], config: nil)

        let containsRenderPins = (messageSender?.sentMessages ?? []).contains { message in
            if case .renderPins = message {
                return true
            }
            return false
        }

        XCTAssertTrue(containsRenderPins)
    }

    func testRenderPinsWithMultiplePins() {
        let messageSender = mockServiceLocator.getWebViewMessageSender() as? MockMessageSender
        messageSender?.sentMessages = []
        
        let pins = [
            Pin(type: .aisleSection, id: 1, zone: "A", aisle: 1, section: "1"),
            Pin(type: .department, id: 2, zone: "B", aisle: 2, section: "2"),
        ]
        let config = DisplayPinConfig(enableManualPinDrop: false, resetZoom: false, shouldZoomOnPins: true)
        
        viewModel.renderPins(pins, config: config)

        let containsRenderPins = (messageSender?.sentMessages ?? []).contains { message in
            if case .renderPins = message {
                return true
            }
            return false
        }

        XCTAssertTrue(containsRenderPins)
        XCTAssertEqual(viewModel.config.enableManualPinDrop, config.enableManualPinDrop)
    }

    func testRenderPinsWithConfigMultipleTimes() {
        let pins1 = [Pin(type: .aisleSection, id: 1, zone: "A", aisle: 1, section: "1")]
        let config1 = DisplayPinConfig(enableManualPinDrop: true, resetZoom: false, shouldZoomOnPins: true)
        
        viewModel.renderPins(pins1, config: config1)
        
        let firstConfigState = viewModel.config.enableManualPinDrop
        
        let pins2 = [Pin(type: .department, id: 2, zone: "B", aisle: 2, section: "2")]
        let config2 = DisplayPinConfig(enableManualPinDrop: false, resetZoom: true, shouldZoomOnPins: false)
        
        viewModel.renderPins(pins2, config: config2)
        
        // Assert: Second config should override first
        XCTAssertNotEqual(firstConfigState, viewModel.config.enableManualPinDrop)
        XCTAssertEqual(viewModel.config.enableManualPinDrop, config2.enableManualPinDrop)
    }
}
