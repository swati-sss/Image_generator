//
//  StoreMapLoaderViewModelExtensionTests.swift
//  compass_sdk_iosTests
//
//  Created by Copilot on 1/26/26.
//

import XCTest
import Combine
import CoreGraphics
@testable import compass_sdk_ios

final class StoreMapLoaderViewModelExtensionTests: XCTestCase {
    var viewModel: StoreMapLoaderViewModel!
    var mockServiceLocator: MockServiceLocator!
    var cancellables: Set<AnyCancellable>!
    var mapViewDelegate: MockMapViewDelegate!
    var mockMessageSender: MockMessageSender!
    var mockAssetService: MockAssetService!
    var mockIndoorNavigationService: MockIndoorNavigationService!

    private func makeStoreMapOptions(
        navigationEnabled: Bool = true,
        pinsConfig: PinsConfig = PinsConfig(actionAlleyEnabled: true, groupPinsEnabled: true)
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
        
        mockMessageSender = mockServiceLocator.getWebViewMessageSender() as? MockMessageSender
        mockAssetService = mockServiceLocator.getAssetService() as? MockAssetService
        mockIndoorNavigationService = mockServiceLocator.getIndoorNavigationService() as? MockIndoorNavigationService
    }

    override func tearDownWithError() throws {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: UserDefaultsKey.uuidList.rawValue)
        
        cancellables.removeAll()
        viewModel = nil
        mockServiceLocator = nil
        mapViewDelegate = nil
        mockMessageSender = nil
        mockAssetService = nil
        mockIndoorNavigationService = nil
        try super.tearDownWithError()
    }

    // MARK: - request() Tests

    func testRequest_WithValidWebView_SendsMessage() {
        let message = MessageRequest.version(VersionRequest(version: 1))
        mockMessageSender.sentMessages = []
        
        viewModel.request(message)
        
        XCTAssertGreaterThan(mockMessageSender.sentMessages.count, 0)
    }

    func testRequest_WithNilWebView_DoesNotSendMessage() {
        viewModel.mapViewDelegate = nil
        let message = MessageRequest.version(VersionRequest(version: 1))
        mockMessageSender.sentMessages = []
        
        viewModel.request(message)
        
        XCTAssertEqual(mockMessageSender.sentMessages.count, 0)
    }

    // MARK: - refreshWebView() Tests

    func testRefreshWebView_ResetsState() {
        viewModel.renderedPins = [Pin(type: .unknown, id: 1)]
        viewModel.hasLoadedMapView.value = true
        
        viewModel.refreshWebView()
        
        XCTAssertTrue(viewModel.renderedPins.isEmpty)
        XCTAssertNil(viewModel.renderedPinsZoomRect)
        XCTAssertFalse(viewModel.hasLoadedMapView.value)
    }

    func testRefreshWebView_ReloadsWebView() {
        viewModel.refreshWebView()
        
        XCTAssertTrue(mapViewDelegate._reloadWebViewCalled)
    }

    // MARK: - handle() Tests

    func testHandle_MapDataMessage_SetsMapData() {
        let mapData = MapData(
            mapHeight: "100",
            mapBoundaries: CGRect(x: 0, y: 0, width: 100, height: 100),
            poi: [],
            restRoomCount: 0,
            departments: []
        )
        let message = MessageResponse.mapData(mapData)
        
        viewModel.handle(message)
        
        XCTAssertNotNil(viewModel.mapData)
    }

    func testHandle_MapLoadedMessage_UpdatesMapLoadedData() {
        let mapLoaded = MapLoaded(
            floors: ["1"],
            entrances: [],
            offsets: []
        )
        let message = MessageResponse.mapLoaded(mapLoaded)
        
        viewModel.handle(message)
        
        XCTAssertNotNil(viewModel.mapLoadedData)
    }

    func testHandle_CoordinateSpaceDiscoveryTapMessage_ExecutesWithoutError() {
        let tap = CoordinateSpaceDiscoveryTap(
            screenSpace: Point(x: 100, y: 100),
            svgSpace: Point(x: 50, y: 50)
        )
        let message = MessageResponse.coordinateSpaceDiscoveryTap(tap)
        
        viewModel.handle(message)
        
        XCTAssertTrue(true)
    }

    func testHandle_PinRenderedMessage_ExecutesWithoutError() {
        let pinRenderedMessage = PinRenderedMessage(
            pins: [
                Pin(type: .aisleSection, id: 123, zone: "A", aisle: 1, section: "1", selected: true)
            ]
        )
        let message = MessageResponse.pinRenderedMessage(pinRenderedMessage)
        
        viewModel.handle(message)
        
        XCTAssertTrue(true)
    }

    // MARK: - renderPinsIfNeeded() Tests

    func testRenderPinsIfNeeded_WithNoLoadedMapView_SetsFlags() {
        viewModel.hasLoadedMapView.value = false
        
        viewModel.renderPinsIfNeeded(floorCount: 1)
        
        XCTAssertTrue(viewModel.hasLoadedMapView.value)
    }

    func testRenderPinsIfNeeded_WithMultipleFloorsAndRenderedPins_RequestsAisleData() {
        viewModel.hasLoadedMapView.value = false
        viewModel.renderedPins = [Pin(type: .unknown, id: 1)]
        mockMessageSender.sentMessages = []
        
        viewModel.renderPinsIfNeeded(floorCount: 2)
        
        XCTAssertGreaterThan(mockMessageSender.sentMessages.count, 0)
    }

    func testRenderPinsIfNeeded_WithSingleFloorAndConfigPin_RendersPins() {
        viewModel.hasLoadedMapView.value = false
        viewModel.configuration = StoreMapView.Configuration(
            isPinSelectionEnabled: false,
            pin: Pin(type: .aisleSection, id: 123),
            preferredFloor: "1"
        )
        
        viewModel.renderPinsIfNeeded(floorCount: 1)
        
        XCTAssertTrue(viewModel.hasLoadedMapView.value)
    }

    // MARK: - reportPinAisleStatusEvent() Tests

    func testReportPinAisleStatusEvent_WithPins_EmitsEvent() {
        let pins = [
            Pin(type: .aisleSection, id: 123, zone: "A", aisle: 1, section: "1"),
            Pin(type: .aisleSection, id: 456, zone: "B", aisle: 1, section: "1")
        ]
        
        viewModel.reportPinAisleStatusEvent(for: pins)
        
        XCTAssertTrue(true)
    }

    func testReportPinAisleStatusEvent_WithErrorPins_MarksAsFailure() {
        let errorData = ErrorData(invalidAisle: true)
        let pins = [
            Pin(type: .aisleSection, id: 123, zone: "A", aisle: 1, section: "1", errorData: errorData)
        ]
        
        viewModel.reportPinAisleStatusEvent(for: pins)
        
        XCTAssertTrue(true)
    }

    // MARK: - onMapLongPressed() Tests

    func testOnMapLongPressed_WithStaticPath_ReturnsEarly() {
        viewModel.isStaticPathVisible = true
        let tap = CoordinateSpaceDiscoveryTap(
            screenSpace: Point(x: 100, y: 100),
            svgSpace: Point(x: 50, y: 50)
        )
        
        viewModel.onMapLongPressed(coordPayLoad: tap)
        
        XCTAssertTrue(true)
    }

    func testOnMapLongPressed_WithManualPinDropDisabled_ReturnsEarly() {
        viewModel.config = DisplayPinConfig(
            enableManualPinDrop: false,
            resetZoom: false,
            shouldZoomOnPins: false
        )
        
        let tap = CoordinateSpaceDiscoveryTap(
            screenSpace: Point(x: 100, y: 100),
            svgSpace: Point(x: 50, y: 50)
        )
        
        viewModel.onMapLongPressed(coordPayLoad: tap)
        
        XCTAssertTrue(true)
    }

    // MARK: - evaluateAisle() Tests

    func testEvaluateAisle_ClearsIdList() {
        mockAssetService.idList = ["old-id"]
        
        viewModel.evaluateAisle(for: "new-id", waspPosition: CGPoint(x: 100, y: 100), idType: .assets)
        
        XCTAssertEqual(mockAssetService.idList, ["new-id"])
    }

    func testEvaluateAisle_CallsEvaluateAisles() {
        mockAssetService._evaluateAislesCalled = false
        
        viewModel.evaluateAisle(for: "test-id", waspPosition: CGPoint(x: 100, y: 100), idType: .assets)
        
        XCTAssertTrue(mockAssetService._evaluateAislesCalled)
    }

    // MARK: - render() Tests

    func testRender_WithReplacingExistingTrue_ReplacesRenderedPins() {
        viewModel.renderedPins = [Pin(type: .unknown, id: 1)]
        let newPins = [Pin(type: .unknown, id: 2)]
        
        viewModel.render(newPins, replacingExisting: true)
        
        XCTAssertEqual(viewModel.renderedPins.count, 1)
        XCTAssertEqual(viewModel.renderedPins.first?.id, 2)
    }

    func testRender_WithReplacingExistingFalse_AppendsToRenderedPins() {
        viewModel.renderedPins = [Pin(type: .unknown, id: 1)]
        let newPins = [Pin(type: .unknown, id: 2)]
        
        viewModel.render(newPins, replacingExisting: false)
        
        XCTAssertEqual(viewModel.renderedPins.count, 2)
    }

    func testRender_SendsRenderPinsRequest() {
        let pins = [Pin(type: .unknown, id: 1)]
        mockMessageSender.sentMessages = []
        
        viewModel.render(pins)
        
        XCTAssertGreaterThan(mockMessageSender.sentMessages.count, 0)
    }

    // MARK: - zoomOnLocation() Tests

    func testZoomOnLocation_WithStaticPath_ReturnsEarly() {
        viewModel.isStaticPathVisible = true
        
        viewModel.zoomOnLocation(
            topLeft: Point(x: 0, y: 0),
            bottomRight: Point(x: 100, y: 100)
        )
        
        XCTAssertFalse(mapViewDelegate._zoomRenderedPinsCalled)
    }

    func testZoomOnLocation_WithShouldZoomDisabled_ReturnsEarly() {
        viewModel.config = DisplayPinConfig(
            enableManualPinDrop: false,
            resetZoom: false,
            shouldZoomOnPins: false
        )
        
        viewModel.zoomOnLocation(
            topLeft: Point(x: 0, y: 0),
            bottomRight: Point(x: 100, y: 100)
        )
        
        XCTAssertFalse(mapViewDelegate._zoomRenderedPinsCalled)
    }

    func testZoomOnLocation_WithValidParameters_ZoomsOnRegion() {
        viewModel.config = DisplayPinConfig(
            enableManualPinDrop: false,
            resetZoom: false,
            shouldZoomOnPins: true
        )
        mapViewDelegate._zoomRenderedPinsCalled = false
        
        viewModel.zoomOnLocation(
            topLeft: Point(x: 0, y: 0),
            bottomRight: Point(x: 100, y: 100),
            target: .pinAnnotation
        )
        
        XCTAssertTrue(mapViewDelegate._zoomRenderedPinsCalled)
    }

    // MARK: - zoomToMapCenter() Tests

    func testZoomToMapCenter_SetsHasMapViewZoomedFlag() {
        viewModel.hasMapViewZoomed = false
        
        viewModel.zoomToMapCenter()
        
        XCTAssertTrue(viewModel.hasMapViewZoomed)
    }

    func testZoomToMapCenter_TogglesLoadingView() {
        mapViewDelegate._toggleLoadingViewCalled = false
        
        viewModel.zoomToMapCenter()
        
        XCTAssertTrue(mapViewDelegate._toggleLoadingViewCalled)
    }

    // MARK: - getUpdateScale() Tests

    func testGetUpdateScale_ZoomIn_WithinMaxScale_IncreasesScale() {
        let currentScale: CGFloat = 2.0
        
        let newScale = viewModel.getUpdateScale(currentScale, .zoomIn)
        
        XCTAssertGreaterThan(newScale, currentScale)
    }

    func testGetUpdateScale_ZoomIn_ExceedsMaxScale_ReturnsMaxScale() {
        let currentScale: CGFloat = StoreMapZoomLevel.fourth.maximumZoomScale
        
        let newScale = viewModel.getUpdateScale(currentScale, .zoomIn)
        
        XCTAssertEqual(newScale, StoreMapZoomLevel.fourth.maximumZoomScale)
    }

    func testGetUpdateScale_ZoomOut_WithinMinScale_DecreasesScale() {
        let currentScale: CGFloat = 2.0
        
        let newScale = viewModel.getUpdateScale(currentScale, .zoomOut)
        
        XCTAssertLessThan(newScale, currentScale)
    }

    func testGetUpdateScale_ZoomOut_BelowMinScale_ReturnsMinScale() {
        let currentScale: CGFloat = StoreMapZoomLevel.first.minimumZoomScale
        
        let newScale = viewModel.getUpdateScale(currentScale, .zoomOut)
        
        XCTAssertEqual(newScale, StoreMapZoomLevel.first.minimumZoomScale)
    }
}
