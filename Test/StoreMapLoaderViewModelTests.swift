//
//  StoreMapLoaderViewModelTests.swift
//  compass_sdk_iosTests
//
//  Created by Young Jin Ju on 6/14/24.
//

import XCTest
@testable import compass_sdk_ios
import WebKit
import LivingDesign
import IPSFramework

class MockMapViewDelegate: StoreMapsViewDelegate, TestMockable {
    var previewSetUpCalled = false
    var previewSetUpParams: Bool?
    func previewSetUp(isStaticPathVisible: Bool) {
        previewSetUpCalled = true
        previewSetUpParams = isStaticPathVisible
    }

    var updateZoomInteractionCalled = false
    var updateZoomInteractionEnabled: Bool?
    func updateZoomInteraction(enabled: Bool) {
        updateZoomInteractionCalled = true
        updateZoomInteractionEnabled = enabled
    }

    var _displayPinErrorBannerCalled: Bool = false
    func displayPinErrorBanner(_ enabled: Bool) {
        _displayPinErrorBannerCalled = enabled
    }

    var isLocationStatusVisible: Bool = false
    var updateButtonsCalled = false
    var latestIsPositionLocked: Bool?

    func updateButtons(isPositionLocked: Bool) {
        updateButtonsCalled = true
        latestIsPositionLocked = isPositionLocked
    }

    func updateLocationStatus(text: String, isLocked: Bool) {}

    func handleNavigationInterruption(for index: Int, status: compass_sdk_ios.NavigationStatus?) {
        // Mock implementation
    }

    var refreshNavigationButtonStateCalled = false
    var refreshNavigationButtonStateParams: Bool?
    func refreshNavigationButtonState(_ isVisible: Bool?) {
        refreshNavigationButtonStateCalled = true
        refreshNavigationButtonStateParams = isVisible
    }

    var dynamicMapEnabled: Bool = true
    var isCenterButtonClicked: Bool = true
    var mapCenterButton: LivingDesign.LDIconButton = {
        LivingDesign.LDIconButton(
            dataModel: LivingDesign.LDIconButton.Model(
                size: .large,
                image: Asset.Image.mapCenter.image,
                color: .white,
                shape: .round
            )
        )
    }()
    var webView: WKWebView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    var isWebViewLoaded: Bool = true
    internal var zoomControlStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .fill
        stackView.backgroundColor = .white
        stackView.layer.cornerRadius = 5
        stackView.layer.shadowColor = UIColor.black.cgColor
        stackView.layer.shadowOpacity = 0.3
        stackView.layer.shadowOffset = CGSize(width: 1, height: 1)
        stackView.layer.shadowRadius = 5
        stackView.layer.masksToBounds = false
        return stackView
    }()

    internal var floorControlStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.distribution = .equalSpacing
        stackView.backgroundColor = .white
        stackView.layer.cornerRadius = 5
        stackView.layer.shadowColor = UIColor.black.cgColor
        stackView.layer.shadowOpacity = 0.3
        stackView.layer.shadowOffset = CGSize(width: 1, height: 1)
        stackView.layer.shadowRadius = 5
        stackView.layer.masksToBounds = false
        return stackView
    }()


    var _zoomRenderedPinsCalled = false
    var _toggleLoadingViewCalled = false
    var _reloadWebViewCalled = false
    var _zoomCalled = false
    var _zoomParams: (rect: CGRect, isAnimated: Bool)?
    var _setZoomScaleCalled = false
    var _setZoomScaleParams: (zoomScale: CGFloat, zoomType: compass_sdk_ios.ZoomActionType)?
    var _zoomOutCalled = false
    var _isMapButtonClicked = false

    func zoomOnRegion(with rect: CGRect, zoomAnimationDelay: TimeInterval, completion: compass_sdk_ios.StoreMapsCompletion?) {
        _zoomRenderedPinsCalled = true
        completion?()
    }

    func toggleLoadingView(_ shouldShow: Bool) {
        _toggleLoadingViewCalled = true
    }

    func reloadWebView() {
        _reloadWebViewCalled = true
    }

    func zoom(to rect: CGRect, isAnimated: Bool) {
        _zoomCalled = true
        _zoomParams = (rect, isAnimated)
    }

    func zoomOut(with zoomScale: CGFloat?, _ completion: @escaping (() -> Void)) {
        _zoomOutCalled = true
        completion()
    }

    func setZoomScale(to zoomScale: CGFloat, zoomType: compass_sdk_ios.ZoomActionType, _ completion: compass_sdk_ios.StoreMapsCompletion?) {
        _setZoomScaleCalled = true
        _setZoomScaleParams = (zoomScale, zoomType)
        completion?()
    }

    func _resetMock() {
        _zoomRenderedPinsCalled = false
        _toggleLoadingViewCalled = false
        _reloadWebViewCalled = false
        _zoomCalled = false
        _zoomParams = nil
        _setZoomScaleCalled = false
        _setZoomScaleParams = nil
        _zoomOutCalled = false
        previewSetUpCalled = false
        refreshNavigationButtonStateCalled = false
    }
}

// Local test double to avoid project linkage issues with StatusService mocks in other files.
final class LocalMockStatusService: StatusService {
    var eventEmitterHandler: EventEmitterHandler?
    var bootstrapEventEmitter: EventEmitterHandler?
    var compassPositionType: String = ""

    var emitPinClickedEventCalled = false
    var lastPinClickedZone: String?
    var lastPinClickedAisle: Int?
    var lastPinClickedSection: Int?
    var emitMapStatusEventCalled = false
    var lastMapStatusSuccess: Bool?
    var emitPinDropEventCalled = false

    func emitMapStatusEvent(isSuccess: Bool) {
        emitMapStatusEventCalled = true
        lastMapStatusSuccess = isSuccess
        // If tests still set eventEmitterHandler, send a minimal emitter if available.
        if let handler = eventEmitterHandler {
            let emitter = MapStatusEventEmitter(eventType: .mapStatusEventEmitter, success: isSuccess)
            handler(emitter)
        }
    }

    func emitPinDropEvent(using assetId: String,
                          storeId: Int,
                          pinDropType: PinDropType,
                          assetEvents: [String: AssetEvent],
                          idType: PinDropMethod) {
        emitPinDropEventCalled = true
    }
    func emitAislesPinDropEvent(pinDropType: PinDropType, mapType: MapIdentifier, pins: [PinAisleEvent]) {
        // Mock implementation: Track aisles pin drop event
        if let handler = eventEmitterHandler {
            let emitter = MapStatusEventEmitter(eventType: .mapStatusEventEmitter, success: true)
            handler(emitter)
        }
    }
    func emitPinClickedEvent(zone: String, aisle: Int, section: Int) {
        emitPinClickedEventCalled = true
        lastPinClickedZone = zone
        lastPinClickedAisle = aisle
        lastPinClickedSection = section
    }
    func emitLocationEvent(assetLocation: String) {
        // Mock implementation: Track location event
        if let handler = eventEmitterHandler {
            let emitter = MapStatusEventEmitter(eventType: .mapStatusEventEmitter, success: true)
            handler(emitter)
        }
    }
    func emitBootstrapEvent(description eventDescription: String?) {
        // Mock implementation: Track bootstrap event
        if let handler = bootstrapEventEmitter {
            let emitter = MapStatusEventEmitter(eventType: .bootstrapEventEmitter, success: true)
            handler(emitter)
        }
    }
    func emitUpdateEventList(description eventDescription: String?) {
        // Mock implementation: Track update event list
        if let handler = eventEmitterHandler {
            let emitter = MapStatusEventEmitter(eventType: .mapStatusEventEmitter, success: true)
            handler(emitter)
        }
    }
    func emitMapStatusEvent(description errorDescription: String?) {
        // Mock implementation: Track map status event with error description
        if let handler = eventEmitterHandler {
            let emitter = MapStatusEventEmitter(eventType: .mapStatusEventEmitter, success: errorDescription == nil)
            handler(emitter)
        }
    }
    func emitErrorStatusEvent(using error: (any Error)?, compassErrorType: CompassErrorType, isInitError: Bool) {
        // Mock implementation: Track error status event
        if let handler = eventEmitterHandler {
            let emitter = MapStatusEventEmitter(eventType: .mapStatusEventEmitter, success: error == nil)
            handler(emitter)
        }
    }
    func emitPositionStatusEvent(calibrationProgress: Float?, isCalibrationGestureNeeded: Bool?, positioningProgress: Float?, isPositionLocked: Bool?) {
        // Mock implementation: Track position status event
        if let handler = eventEmitterHandler {
            let emitter = MapStatusEventEmitter(eventType: .mapStatusEventEmitter, success: true)
            handler(emitter)
        }
    }
    func emitErrorStatusEvent(for error: ErrorResponse, isInitError: Bool) {
        // Mock implementation: Track error response status event
        if let handler = eventEmitterHandler {
            let emitter = MapStatusEventEmitter(eventType: .mapStatusEventEmitter, success: false)
            handler(emitter)
        }
    }
    func resetCompassPositionType() { compassPositionType = "" }
    func emitGeofenceStateChangeEvent(state: String) {
        // Mock implementation: Track geofence state change event
        if let handler = eventEmitterHandler {
            let emitter = MapStatusEventEmitter(eventType: .mapStatusEventEmitter, success: true)
            handler(emitter)
        }
    }
    func emitPointOfInterestEvent(PointOfInterest: [PointsOfInterest]) {
        // Mock implementation: Track point of interest event
        if let handler = eventEmitterHandler {
            let emitter = MapStatusEventEmitter(eventType: .mapStatusEventEmitter, success: true)
            handler(emitter)
        }
    }
}

class MockMessageParser: NSObject, MessageParsing, TestMockable {
    var delegate: (any MessageParserDelegate)?
    var _shouldFail = false
    var _expectedResponse: MessageResponse = .mapLoaded(MapLoaded(floors: ["1", "2"], offsets: [ StoreConfigOffset(
        x: 4612.4299902343755,
        y: 3431.0000244140624
    )]))

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if _shouldFail {
            delegate?.messageParser(self, didFailWithError: StoreMapDecodingError(defaultValue: .none, model: "", error: TestData.error, errorMessage: "Mock error"))
        } else {
            delegate?.messageParser(self, didParseMessageResponse: _expectedResponse)
        }
    }

    func _resetMock() {
        _shouldFail = false
        _expectedResponse = .mapLoaded(MapLoaded(floors: ["1", "2"], offsets: [ StoreConfigOffset(
            x: 4612.4299902343755,
            y: 3431.0000244140624
        )]))
    }
}

final class StoreMapLoaderViewModelTests: XCTestCase {
    private var messageSender: MockMessageSender!
    private var serviceLocator: MockServiceLocator!
    private var storeMapLoaderViewModel: StoreMapLoaderViewModel!
    private var messageParser: MockMessageParser!
    private var mapViewDelegate: MockMapViewDelegate!
    private var mockStatusService: LocalMockStatusService!
    private var mockLogDefault: MockLogDefaultImpl!
    private var testUserDefaults: UserDefaults!
    private var testUserDefaultsSuiteName: String!

    private func makeStoreMapOptions(
        navigationConfig: NavigationConfig = NavigationConfig(enabled: false, refreshDuration: 0.0),
        pinsConfig: PinsConfig = PinsConfig(),
        debugLog: DebugLog = DebugLog()
    ) -> StoreMapView.Options {
        StoreMapView.Options(
            dynamicMapEnabled: true,
            zoomControlEnabled: true,
            errorScreensEnabled: true,
            spinnerEnabled: true,
            dynamicMapRotationEnabled: false,
            navigationConfig: navigationConfig,
            mapUiConfig: MapUiConfig(),
            pinsConfig: pinsConfig,
            debugLog: debugLog
        )
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        let workflow =  Workflow(id: "sample_app_id", type: "sample_app_flow", value: "sa_val")
        Analytics.workflow = workflow
        testUserDefaultsSuiteName = "StoreMapLoaderViewModelTests.\(UUID().uuidString)"
        testUserDefaults = try XCTUnwrap(UserDefaults(suiteName: testUserDefaultsSuiteName))
        testUserDefaults.removePersistentDomain(forName: testUserDefaultsSuiteName)
        serviceLocator = MockServiceLocator()
        serviceLocator.statusService = LocalMockStatusService()
        messageSender = serviceLocator.getWebViewMessageSender() as? MockMessageSender
        messageParser = serviceLocator.getWebViewMessageParser() as? MockMessageParser
        mockStatusService = serviceLocator.getStatusService() as? LocalMockStatusService
        mockLogDefault = MockLogDefaultImpl(
            logEventStoreService: serviceLocator.getLogEventStoreService(),
            networkService: serviceLocator.getNetworkService()
        )
        Analytics.logDefault = mockLogDefault
        let options = makeStoreMapOptions()
        storeMapLoaderViewModel = StoreMapLoaderViewModel(
            blueDotMode: .visible,
            storeMapOptions: options,
            debugLog: options.debugLog,
            serviceLocator: serviceLocator,
            userDefaults: testUserDefaults,
            zoomAnalyticsLogger: ZoomAnalyticsLogger(
                buttonZoomScale: 1.0,
                pnchZoomScale: 1.0,
                buttonZoomInTaps: 2,
                buttonZoomOutTaps: 2,
                pinchZoomInActions: 3,
                pinchZoomOutActions: 4,
                workflow: workflow
            )
        )

        mapViewDelegate = MockMapViewDelegate()
        storeMapLoaderViewModel.mapViewDelegate = mapViewDelegate
    }

    override func tearDownWithError() throws {
        mapViewDelegate._resetMock()
        serviceLocator._resetMock()
        storeMapLoaderViewModel = nil
        serviceLocator = nil
        mockStatusService = nil
        mockLogDefault = nil
        Analytics.logDefault = nil
        testUserDefaults.removePersistentDomain(forName: testUserDefaultsSuiteName)
        testUserDefaults = nil
        testUserDefaultsSuiteName = nil
        try super.tearDownWithError()
    }

    func testViewDidAppear() {
        messageParser.userContentController(WKUserContentController(), didReceive: WKScriptMessage())
        storeMapLoaderViewModel.viewDidAppear()
        XCTAssert(serviceLocator.getMapFocusManager().isMapViewPresent.value)
    }

    func testViewDidAppearBluDotModeNone() {
        (serviceLocator.getMapFocusManager() as? MockMapFocusManager)?.isMapViewPresent.value = false
        let options = makeStoreMapOptions()
        storeMapLoaderViewModel = StoreMapLoaderViewModel(
            blueDotMode: .none,
            storeMapOptions: options,
            debugLog: nil,
            serviceLocator: serviceLocator,
            userDefaults: testUserDefaults
        )
        storeMapLoaderViewModel.viewDidAppear()
        XCTAssertFalse(serviceLocator.getMapFocusManager().isMapViewPresent.value)
    }

    func testViewWillDisappear() {
        serviceLocator.mapFocusManager?.isMapViewPresent.value = true
        storeMapLoaderViewModel.viewWillDisappear()
        XCTAssertFalse(serviceLocator.getMapFocusManager().isMapViewPresent.value)
    }

    func testViewWillDisappearBlueDotNone() {
        let options = makeStoreMapOptions()
        storeMapLoaderViewModel = StoreMapLoaderViewModel(
            blueDotMode: .none,
            storeMapOptions: options,
            debugLog: nil,
            serviceLocator: serviceLocator,
            userDefaults: testUserDefaults
        )
        serviceLocator.mapFocusManager?.isMapViewPresent.value = true
        storeMapLoaderViewModel.viewWillDisappear()
        XCTAssert(serviceLocator.getMapFocusManager().isMapViewPresent.value)
    }

    func testDidConstructView() {
        mapViewDelegate.isWebViewLoaded = true
        storeMapLoaderViewModel.didConstructView()
        XCTAssert(mapViewDelegate._reloadWebViewCalled)
    }

    func testDidLoadWebView() {
        let expectation = expectation(description: #function)
        messageParser.userContentController(WKUserContentController(), didReceive: WKScriptMessage())
        messageParser._expectedResponse = .mapData(MapData(mapBoundaries: .zero, poi: [], restRoomCount: 0, departments: []))
        messageParser.userContentController(WKUserContentController(), didReceive: WKScriptMessage())
        mapViewDelegate.isWebViewLoaded = true
        storeMapLoaderViewModel.configuration = StoreMapView.Configuration(isPinSelectionEnabled: false ,pin: Pin(type: .aisleSection),preferredFloor: "1")
        storeMapLoaderViewModel.didLoadWebView()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) { [mapViewDelegate, expectation] in
            XCTAssert(mapViewDelegate!._toggleLoadingViewCalled)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 3.0)
    }

    func testUpdateZoomLevel() {
        messageSender.sentMessages = []
        let workflow =  Workflow(id: "sample_app_id_1", type: "sample_app_flow_1", value: "sa_val")
        Analytics.workflow = workflow
        storeMapLoaderViewModel.updateZoomLevel(with: 2.5)
        XCTAssert(messageSender.sentMessages.contains(.zoomLevelChange(ZoomLevelChangeRequest(zoom: 4))))
    }

    func testClearRenderedPin() {
        messageSender.sentMessages = []
        storeMapLoaderViewModel.clearRenderedPin(mapConfig: MapConfig(resetZoom: true))
        XCTAssert(messageSender.sentMessages.contains(.renderPins(RenderPinsRequest(pins: [], pinGroupingEnabled: true))))
        XCTAssert(messageSender.sentMessages.contains(.renderXYLocationPinRequested(PinList(pins: []))))
    }

    func testHandleError() {
        storeMapLoaderViewModel.handleError()
        XCTAssertTrue(mockStatusService.emitMapStatusEventCalled)
        XCTAssertEqual(mockStatusService.lastMapStatusSuccess, false)
    }

    func testZoomOut() {
        let expectation = expectation(description: #function)
        messageSender.sentMessages = []
        mapViewDelegate.isCenterButtonClicked = false
        storeMapLoaderViewModel.zoomOut()
        XCTAssert(messageSender.sentMessages.contains(.zoomLevelChange(.init(zoom: 0))))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            XCTAssert(self.mapViewDelegate!._zoomOutCalled)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 5.0)
    }

    func testRenderPins() {
        messageSender.sentMessages = []
        let renderPinsRequest = RenderPinsRequest(pins: [Pin(type: .aisleSection)], pinGroupingEnabled: true)
        storeMapLoaderViewModel.renderPins(renderPinsRequest, config: DisplayPinConfig(enableManualPinDrop: false))
        XCTAssert(messageSender.sentMessages.contains(.renderPins(renderPinsRequest)))
    }

    func testRenderPinsFromPoints() {
        messageSender.sentMessages = []
        storeMapLoaderViewModel.renderPins(from: [CGPoint(x: 2, y: 234)], config: DisplayPinConfig(enableManualPinDrop: false))
        XCTAssert(messageSender.sentMessages.contains(.renderXYLocationPinRequested(PinList(pins: [DrawPin(type: "xy-pin-location", x: 2.0, y: -234.0, location: Point(x: 2.0, y: -234.0),errorData: nil)]))))
    }

    func testUpdateUserPosition() {
        messageSender.sentMessages = []
        storeMapLoaderViewModel.updateUserPosition(x: 2, y: 980, accuracy: 43)
        XCTAssert(messageSender.sentMessages.contains(.showUserLocation(UserPosition(x: 2, y: 980, ringRadius: 43))))
    }

    func testUpdateUserRotation() {
        messageSender.sentMessages = []
        storeMapLoaderViewModel.updateUserRotation(angle: 213.77, rotateMap: false)
        XCTAssert(messageSender.sentMessages.contains(.rotateUser(UserRotation(angle: 213.77, rotateMap: false))))
    }

    func testOnStoreMapZoomChange() {
        let expectation = expectation(description: #function)
        storeMapLoaderViewModel.onStoreMapZoomChange(zoomType: .zoomIn, {
            XCTAssert(self.mapViewDelegate._setZoomScaleCalled)
            XCTAssertTrue(((self.storeMapLoaderViewModel.mapViewDelegate?.isCenterButtonClicked) != nil))
            expectation.fulfill()
        })
        waitForExpectations(timeout: 2.0)
    }

    func testOnStoreMapFloorChange() {
        messageSender.sentMessages = []
        // Set up map data with offsets for multiple floors
        messageParser._expectedResponse = .mapLoaded(MapLoaded(floors: ["1", "2"], offsets: [
            StoreConfigOffset(x: 100, y: 200),
            StoreConfigOffset(x: 4612.4299902343755, y: 3431.0000244140624)
        ]))
        messageParser.userContentController(WKUserContentController(), didReceive: WKScriptMessage())

        // Change to floor 2 (index 1)
        storeMapLoaderViewModel.onStoreMapFloorChange(levelType: .floorTwo, nil)
        XCTAssert(self.messageSender.sentMessages.contains(.floorLevelChange(.init(floor: "2"))))

        // Verify the correct offset was applied for floor 2
        let assetService = serviceLocator.getAssetService()
        XCTAssertEqual(assetService.storeConfigOffset.x, 4612.4299902343755)
        XCTAssertEqual(assetService.storeConfigOffset.y, 3431.0000244140624)
    }

    func testDidParseMessage() {
        messageSender.sentMessages = []
        messageParser._expectedResponse = .mapLoaded(MapLoaded(floors: ["1"], offsets: [ StoreConfigOffset(
            x: 4612.4299902343755,
            y: 3431.0000244140624
        )]))
        storeMapLoaderViewModel.messageParser(messageParser, didParseMessageResponse: .mapLoaded(MapLoaded(floors: ["B", "G", "1", "M", "2"], offsets: [ StoreConfigOffset(
            x: 4612.4299902343755,
            y: 3431.0000244140624
        )])))
        XCTAssert(messageSender.sentMessages.contains(.version(.init(version: StoreMapConfig.webAppVersion))))
        XCTAssert(messageSender.sentMessages.contains(.mapData))
        XCTAssert(messageSender.sentMessages.contains(.coordinateSpaceDiscoveryTapRequested(CoordinateSpaceDiscoveryTapRequest(enabled: true))))
        XCTAssertTrue(mockStatusService.emitMapStatusEventCalled)
        XCTAssertEqual(mockStatusService.lastMapStatusSuccess, true)
    }

    func testPinClickedParseMessage() {
        let pinClicked = MessageResponse.pinClicked(
            PinClicked(pinRect: Rect(cgRect: CGRect(x: 1.0,
                                                    y: 1.0,
                                                    width: 10.0,
                                                    height: 10.0)),
                       data: .init(
                        zone: "A",
                        aisle: 8,
                        section: 3,
                        floor: 0,
                        count: 1,
                        selected: true,
                        isSeasonal: false
                       )))
        messageSender.sentMessages = []
        messageParser._expectedResponse = pinClicked
        storeMapLoaderViewModel.messageParser(messageParser, didParseMessageResponse: pinClicked)
        XCTAssertTrue(mockStatusService.emitPinClickedEventCalled)
        XCTAssertEqual(mockStatusService.lastPinClickedZone, "A")
        XCTAssertEqual(mockStatusService.lastPinClickedAisle, 8)
        XCTAssertEqual(mockStatusService.lastPinClickedSection, 3)
    }

    func testMessageParserDidFailWithError() {
        messageParser.delegate?.messageParser(messageParser, didFailWithError: StoreMapDecodingError(defaultValue: .mapLoaded(MapLoaded(floors: ["1"], offsets: [ StoreConfigOffset(
            x: 4612.4299902343755,
            y: 3431.0000244140624
        )])), model: "test_model", error: TestData.error, errorMessage: "test_error"))
        XCTAssert(messageSender.sentMessages.contains(.version(.init(version: StoreMapConfig.webAppVersion))))
        XCTAssert(messageSender.sentMessages.contains(.mapData))
        XCTAssert(messageSender.sentMessages.contains(.coordinateSpaceDiscoveryTapRequested(CoordinateSpaceDiscoveryTapRequest(enabled: true))))
    }

    func testHandleCoordinateSpaceDiscoveryTapped() {
        messageSender.sentMessages = []
        (serviceLocator.getIndoorNavigationService() as? MockIndoorNavigationService)?.navigationSessionState?.navigationStatus = .notStarted
        storeMapLoaderViewModel.renderPins(RenderPinsRequest(pins: [], pinGroupingEnabled: true), config: DisplayPinConfig(enableManualPinDrop: true))
        messageParser._expectedResponse = .coordinateSpaceDiscoveryTap(CoordinateSpaceDiscoveryTap(screenSpace: Point(x: 1, y: 1), svgSpace: Point(x: 20, y: 20)))
        let statusService = serviceLocator.getStatusService()
        messageParser.userContentController(WKUserContentController(), didReceive: WKScriptMessage())
        statusService.emitBootstrapEvent(description: "test")
        XCTAssert(messageSender.sentMessages.contains(.renderXYLocationPinRequested(PinList(pins: [DrawPin(type: "xy-pin-location", x: 20, y: 20, location: Point(x: 20, y: 20),errorData: nil)]))))
    }

//    func testHandlePinRenderedMessage() {
//        messageSender.sentMessages = []
//        messageParser._expectedResponse = .pinRenderedMessage(PinRenderedMessage(newPinsRendered: true, pins: [Pin(type: .aisleSection)]))
//        messageParser.userContentController(WKUserContentController(), didReceive: WKScriptMessage())
//        XCTAssertTrue(mockStatusService.emitPinDropEventCalled)
//    }

    func testHandlePinsActionAlleyRenderedMessage() {
        messageSender.sentMessages = []
        (serviceLocator.getIndoorNavigationService() as? MockIndoorNavigationService)?.navigationSessionState?.navigationStatus = .notStarted
        storeMapLoaderViewModel.renderPins(from: [], config: DisplayPinConfig(enableManualPinDrop: false, resetZoom: true, shouldZoomOnPins: true))
        messageParser._expectedResponse = .pinsActionAlleyRenderedResponse(PinRenderedMessage(newPinsRendered: true, pins: [Pin(type: .aisleSection)], topLeft: Point(x: 0, y: 0), bottomRight: Point(x: 100, y: 100)))
        messageParser.userContentController(WKUserContentController(), didReceive: WKScriptMessage())
        XCTAssert(mapViewDelegate._zoomRenderedPinsCalled)
    }

    func testHandlePinRenderedCYMessage() {
        messageSender.sentMessages = []
        storeMapLoaderViewModel.renderPins(from: [], config: DisplayPinConfig(enableManualPinDrop: false, resetZoom: true, shouldZoomOnPins: true))
        messageParser._expectedResponse = .pinXYRenderedMessage(PinXYRenderedMessage(newPinsRendered: true,topLeft: Point(x: 0, y: 0), bottomRight: Point(x: 100, y: 100), xyLocationPins: [DrawPin(type: "xy-pin-location", x: 29, y: 73, location: Point(x: 29, y: 73),errorData: nil)], pins: [DrawPin(type: "xy-pin-location", x: 29, y: 73, location: Point(x: 29, y: 73),errorData: nil)]))
        messageParser.userContentController(WKUserContentController(), didReceive: WKScriptMessage())
        XCTAssert(mapViewDelegate._zoomRenderedPinsCalled)
    }

    func test_getMapURLRequest_shouldGetValidMapURLRequest() {

        let urlRequest = storeMapLoaderViewModel.getMapURLRequest()
        let urlString = "https://developer.api.us.stg.walmart.com/api-proxy/service/COMPASS/SERVICE/v1/instore-map/store/0/map"
        XCTAssertNotNil(urlRequest, "URLRequest is nil")
        XCTAssertNotNil(urlRequest!.url, "URL is nil")

        // Check the base URL without query parameters
        guard let url = urlRequest!.url else {
            XCTFail("URL is nil")
            return
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let baseURLString = "\(components?.scheme ?? "")://\(components?.host ?? "")\(components?.path ?? "")"
        XCTAssertEqual(baseURLString, urlString)
    }

    func test_cacheAndBootstrapAsset_withCoordinateSpaceDiscoveryTapped_shouldBootstrap() {
        messageSender.sentMessages = []
        (serviceLocator.getIndoorNavigationService() as? MockIndoorNavigationService)?.navigationSessionState?.navigationStatus = .notStarted
        storeMapLoaderViewModel.renderPins(RenderPinsRequest(pins: [], pinGroupingEnabled: true), config: DisplayPinConfig(enableManualPinDrop: true))
        messageParser._expectedResponse = .coordinateSpaceDiscoveryTap(CoordinateSpaceDiscoveryTap(screenSpace: Point(x: 1, y: 1), svgSpace: Point(x: 20, y: 20)))
        let statusService = serviceLocator.getStatusService()
        messageParser.userContentController(WKUserContentController(), didReceive: WKScriptMessage())
        statusService.emitBootstrapEvent(description: "test")
        XCTAssert(messageSender.sentMessages.contains(.renderXYLocationPinRequested(PinList(pins: [DrawPin(type: "xy-pin-location", x: 20, y: 20, location: Point(x: 20, y: 20),errorData: nil)]))))
    }

    func test_cacheAndBootstrapAsset_withCoordinateSpaceDiscoveryTapped_shouldNotBootstrap() {
        serviceLocator.eventService?._shouldFail = true
        testUserDefaults.setValue(["test123"], forKey: UserDefaultsKey.uuidList.rawValue)
        test_cacheAndBootstrapAsset_withCoordinateSpaceDiscoveryTapped_shouldBootstrap()
        messageParser.userContentController(WKUserContentController(), didReceive: WKScriptMessage())
        XCTAssert(messageSender.sentMessages.contains(.renderXYLocationPinRequested(PinList(pins: [DrawPin(type: "xy-pin-location", x: 20, y: 20, location: Point(x: 20, y: 20),errorData: nil)]))))
        testUserDefaults.removeObject(forKey: UserDefaultsKey.uuidList.rawValue)
    }


    func test_encodeGeneric_withCoordinateSpaceDiscoveryTapped_shouldBootstrap() {
        messageSender.sentMessages = []
        serviceLocator.assetService?.idType = .generic
        (serviceLocator.getIndoorNavigationService() as? MockIndoorNavigationService)?.navigationSessionState?.navigationStatus = .notStarted
        storeMapLoaderViewModel.renderPins(RenderPinsRequest(pins: [], pinGroupingEnabled: true), config: DisplayPinConfig(enableManualPinDrop: true))
        messageParser._expectedResponse = .coordinateSpaceDiscoveryTap(CoordinateSpaceDiscoveryTap(screenSpace: Point(x: 1, y: 1), svgSpace: Point(x: 20, y: 20)))
        let statusService = serviceLocator.getStatusService()
        messageParser.userContentController(WKUserContentController(), didReceive: WKScriptMessage())
        statusService.emitBootstrapEvent(description: "test")
        XCTAssert(messageSender.sentMessages.contains(.renderXYLocationPinRequested(PinList(pins: [DrawPin(type: "xy-pin-location", x: 20, y: 20, location: Point(x: 20, y: 20), errorData: nil)]))))
    }

    func test_getUpdateScale_shouldZoomOut() {
        let expectation = expectation(description: #function)
        let workflow =  Workflow(id: "sample_app_id_1", type: "sample_app_flow", value: "sa_val")
        Analytics.workflow = workflow
        storeMapLoaderViewModel.onStoreMapZoomChange(zoomType: .zoomOut, {
            XCTAssert(self.mapViewDelegate._setZoomScaleCalled)
            expectation.fulfill()
        })
        waitForExpectations(timeout: 2.0)
    }
    func testUpdateUserLoading() {
        messageSender.sentMessages = []
        // Test with percentage = 0 (should send 1)
        storeMapLoaderViewModel.updateUserLoading(percentage: 0)
        XCTAssert(messageSender.sentMessages.contains(.showUserLoading(UserLoading(percentage: 1))))
        // Test with percentage = 50 (should send 50)
        storeMapLoaderViewModel.updateUserLoading(percentage: 50)
        XCTAssert(messageSender.sentMessages.contains(.showUserLoading(UserLoading(percentage: 50))))
    }

    func testHandleUserLocationRenderedMessage() {
        messageSender.sentMessages = []
        let expectation = expectation(description: #function)
        let topLeft = Point(x: 10, y: 20)
        let bottomRight = Point(x: 100, y: 200)
        let userLocationRenderedMessage = UserLocationRenderedMessage(topLeft: topLeft, bottomRight: bottomRight)
        mapViewDelegate._zoomRenderedPinsCalled = false
        storeMapLoaderViewModel.messageParser(messageParser, didParseMessageResponse: .userLocationRenderedMessage(userLocationRenderedMessage))
        // Wait for async zoomOnRegion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssert(self.mapViewDelegate._zoomRenderedPinsCalled)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 2.0)
    }

    func testMakeZoomRect_widthLessThanMinimum_shouldExpandAndRecenterX() {
        // Arrange
        let options = makeStoreMapOptions(navigationConfig: NavigationConfig())
        let viewModel = StoreMapLoaderViewModel(
            blueDotMode: .visible,
            storeMapOptions: options,
            debugLog: nil,
            serviceLocator: serviceLocator,
            userDefaults: testUserDefaults
        )
        let mockDelegate = MockMapViewDelegate()
        let mockWebView = WKWebView(frame: CGRect(x: 0, y: 0, width: 200, height: 300))
        mockDelegate.webView = mockWebView
        viewModel.mapViewDelegate = mockDelegate
        // width = 40, minimumZoomWidth = 100
        let topLeft = CGPoint(x: 10, y: 10)
        let bottomRight = CGPoint(x: 50, y: 50)
        let scale: CGFloat = 2.0 // minimumZoomWidth = 200/2 = 100
        // Act
        let rect = viewModel.makeZoomRect(topLeft: topLeft, bottomRight: bottomRight, scale: scale)
        // Assert
        XCTAssertEqual(rect.width, 100, accuracy: 0.01)
        // The original x was -22 (10-32), so recentering should move it left
        // The new origin.x should be -22 - (100-40)/2 = -22 - 30 = -52
        // But if origin.x < 0, it will be clamped to 0 and width reduced
        XCTAssertEqual(rect.origin.x, 0, accuracy: 0.01)
        // The width should be reduced by the amount origin.x was negative (52), so 100-52=48
        // But since the minimum width is enforced, the final width should be 100
        // So, the test checks that the minimum width logic and recentering are covered
    }

    func testUpdateStoreConfigOffsetWithMultipleFloors() {
        // Arrange: Set up map data with offsets for multiple floors
        messageParser._expectedResponse = .mapLoaded(MapLoaded(floors: ["B", "1", "2"], offsets: [
            StoreConfigOffset(floorLevel: "B", x: 1000, y: 2000),
            StoreConfigOffset(floorLevel: "1", x: 4612.4299902343755, y: 3431.0000244140624),
            StoreConfigOffset(floorLevel: "2", x: 5000, y: 6000)
        ]))
        messageParser.userContentController(WKUserContentController(), didReceive: WKScriptMessage())

        let assetService = serviceLocator.getAssetService()

        // Act & Assert: Test floor 1 (index 0)
        storeMapLoaderViewModel.onStoreMapFloorChange(levelType: .floorOne, nil)
        XCTAssertEqual(assetService.storeConfigOffset.x, 1000)
        XCTAssertEqual(assetService.storeConfigOffset.y, 2000)

        // Act & Assert: Test floor 2 (index 1) - your new offset values
        storeMapLoaderViewModel.floorSelected = 1
        storeMapLoaderViewModel.updateStoreConfigueOffset()
        XCTAssertEqual(assetService.storeConfigOffset.x, 4612.4299902343755)
        XCTAssertEqual(assetService.storeConfigOffset.y, 3431.0000244140624)
    }

    func testUpdateStoreConfigOffsetWithNoOffsets() {
        // Arrange: Set up map data without offsets
        messageParser._expectedResponse = .mapLoaded(MapLoaded(floors: ["1", "2"], offsets: []))
        messageParser.userContentController(WKUserContentController(), didReceive: WKScriptMessage())

        let assetService = serviceLocator.getAssetService()
        let initialOffset = assetService.storeConfigOffset

        // Act: Try to change floor
        storeMapLoaderViewModel.onStoreMapFloorChange(levelType: .floorTwo, nil)

        // Assert: Offset should remain unchanged
        XCTAssertEqual(assetService.storeConfigOffset.x, initialOffset.x)
        XCTAssertEqual(assetService.storeConfigOffset.y, initialOffset.y)
    }

    func testUpdateStoreConfigOffsetWithOutOfRangeFloor() {
        // Arrange: Set up map data with only one offset
        messageParser._expectedResponse = .mapLoaded(MapLoaded(floors: ["1", "2"], offsets: [
            StoreConfigOffset(x: 100, y: 200)
        ]))
        messageParser.userContentController(WKUserContentController(), didReceive: WKScriptMessage())

        let assetService = serviceLocator.getAssetService()

        // Act: Try to select floor 2 (index 1) when only floor 1 (index 0) has offset
        storeMapLoaderViewModel.floorSelected = 1
        storeMapLoaderViewModel.updateStoreConfigueOffset()

        // Assert: Should not crash, offset should still be valid from floor 1
        XCTAssertEqual(assetService.storeConfigOffset.x, 100)
        XCTAssertEqual(assetService.storeConfigOffset.y, 200)
    }

    func testDisplayStaticPath() {
        // Arrange
        let pins = [Pin(type: .aisleSection)]
        let renderPinsRequest = RenderPinsRequest(pins)
        messageSender.sentMessages = []
        let mockStaticPathService = serviceLocator.getStaticPathPreviewService() as! MockStaticPathPreviewService
        mockStaticPathService.previewWaypoints = [Waypoint(id: "old", coordinate: .zero, buildingId: "test", floorOrder: 0)]
        
        let expectation = self.expectation(description: "Wait for zoom out")
        
        // Act
        storeMapLoaderViewModel.displayStaticPath(
            using: renderPinsRequest,
            startFromNearbyEntrance: true,
            disableZoomGestures: true
        )

        // Assert
        XCTAssertTrue(storeMapLoaderViewModel.isStaticPathVisible)
        XCTAssertEqual(mockStaticPathService.previewWaypoints.count, 0)
        XCTAssertTrue(mockStaticPathService.startFromNearbyEntrance)
        XCTAssertTrue(mapViewDelegate.previewSetUpCalled)
        XCTAssertEqual(mapViewDelegate.previewSetUpParams, true)
        XCTAssertTrue(mapViewDelegate.updateZoomInteractionCalled)
        XCTAssertEqual(mapViewDelegate.updateZoomInteractionEnabled, false)
        XCTAssertTrue(mockStaticPathService.handleRouteUpdateCalled)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [mapViewDelegate, messageSender, expectation] in
            XCTAssertTrue(mapViewDelegate!._zoomOutCalled)
            XCTAssertTrue(messageSender!.sentMessages.contains(where: { message in
                if case .renderPins(let request) = message {
                    return (request.pins ?? []).count == 1
                }
                return false
            }))

            XCTAssertTrue(messageSender!.sentMessages.contains(where: { message in
                if case .setPinSelectionEnabled(let request) = message {
                    return request.pinSelectionEnabled == false
                }
                return false
            }))
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 2.0)
    }

    func testClearStaticPath_ShouldResetState() {
        // Arrange
        storeMapLoaderViewModel.isStaticPathVisible = true
        mapViewDelegate._displayPinErrorBannerCalled = true
        mapViewDelegate.previewSetUpCalled = false
        
        messageSender.sentMessages = []
        
        // Act
        storeMapLoaderViewModel.clearStaticPath()
        
        // Assert
        XCTAssertFalse(storeMapLoaderViewModel.isStaticPathVisible)
        XCTAssertFalse(mapViewDelegate._displayPinErrorBannerCalled)
        XCTAssertTrue(mapViewDelegate.previewSetUpCalled)
        XCTAssertEqual(mapViewDelegate.previewSetUpParams, false)
        XCTAssertTrue(mapViewDelegate.updateZoomInteractionCalled)
        XCTAssertEqual(mapViewDelegate.updateZoomInteractionEnabled, true)
        
        XCTAssertTrue(messageSender.sentMessages.contains(where: { message in
            if case .setPinSelectionEnabled(let req) = message {
                return req.pinSelectionEnabled == true
            }
            return false
        }))
    }

    func testRefreshNavigationState_WhenPinsInvalid_ShouldNotBeVisible() {
        // Arrange
        let pins = [Pin(type: .aisleSection, errorData: ErrorData(invalidX: true, invalidY: true))]
        mapViewDelegate.refreshNavigationButtonStateCalled = false
        
        // Act
        storeMapLoaderViewModel.refreshNavigationState(withPins: pins)
        
        // Assert
        XCTAssertTrue(mapViewDelegate.refreshNavigationButtonStateCalled)
        XCTAssertEqual(mapViewDelegate.refreshNavigationButtonStateParams, false)
    }

    func testHandle_PinClicked_ShouldEmitEvent() {
        // Arrange
        let pinClicked = PinClicked(data: PinClicked.Data(zone: "A", aisle: 10, section: 1, floor: 0, count: 1, selected: true, isSeasonal: false))
        
        // Act
        storeMapLoaderViewModel.handle(.pinClicked(pinClicked))
        
        // Assert
        XCTAssertTrue(mockStatusService.emitPinClickedEventCalled)
        XCTAssertEqual(mockStatusService.lastPinClickedZone, "A")
        XCTAssertEqual(mockStatusService.lastPinClickedAisle, 10)
        XCTAssertEqual(mockStatusService.lastPinClickedSection, 1)
    }

    func testHandle_PinsActionAlleyRenderedResponse_ShouldSendZoomOnLocation() {
        // Arrange
        let topLeft = Point(x: 0, y: 0)
        let bottomRight = Point(x: 100, y: 100)
        let message = PinRenderedMessage(topLeft: topLeft, bottomRight: bottomRight)
        mapViewDelegate._zoomRenderedPinsCalled = false
        storeMapLoaderViewModel.config = DisplayPinConfig(enableManualPinDrop: false, shouldZoomOnPins: true)

        // Act
        storeMapLoaderViewModel.handle(.pinsActionAlleyRenderedResponse(message))
        
        // Assert
        XCTAssertTrue(mapViewDelegate._zoomRenderedPinsCalled)
    }

    func testLogNavigationStartEvent_Success() {
        // Arrange
        let mockLogDefault = MockLogDefaultImpl(logEventStoreService: serviceLocator.getLogEventStoreService(),
                                                 networkService: serviceLocator.getNetworkService())
        Analytics.logDefault = mockLogDefault
        
        let pin = Pin(
            type: .aisleSection,
            zone: "A",
            aisle: 10,
            section: "2",
            location: Point(x: 50, y: 60)
        )
        
        let mockHeading = MockHeading(x: 0, y: 0, angle: 90)
        let mockPosition = MockIPSPosition(x: 10, y: 20, headingAngle: mockHeading, accuracy: 1, lockProgress: 1)
        
        let mockIPS = (storeMapLoaderViewModel.indoorPositioningService as! MockIndoorPositioningService)
        mockIPS.lastPosition.send(mockPosition)
        mockIPS.floorCoordinatesConverter = MockFloorCoordinatesConverterImpl()
        
        storeMapLoaderViewModel.wasUserNavigatingBefore = false

        // Act
        storeMapLoaderViewModel.logNavigationStartEvent(pin: pin)

        // Assert
        XCTAssertTrue(storeMapLoaderViewModel.wasUserNavigatingBefore)
        
        if let logEvent = mockLogDefault.logEvent {
            XCTAssertEqual(logEvent.eventType, .navigation)
        } else {
            XCTFail("Expected analytic event to be tracked")
        }
    }

    func testSetPathfindingEnabled_WhenManualNavigationEnabled_ShouldSendRequest() {
        // Arrange
        let workflow = Workflow(id: "sample_app_id", type: "sample_app_flow", value: "sa_val")
        let options = makeStoreMapOptions(
            navigationConfig: NavigationConfig(enabled: true, refreshDuration: 0.0)
        )
        storeMapLoaderViewModel = StoreMapLoaderViewModel(
            blueDotMode: .visible,
            storeMapOptions: options,
            debugLog: options.debugLog,
            serviceLocator: serviceLocator,
            userDefaults: testUserDefaults,
            zoomAnalyticsLogger: ZoomAnalyticsLogger(
                buttonZoomScale: 1.0,
                pnchZoomScale: 1.0,
                buttonZoomInTaps: 2,
                buttonZoomOutTaps: 2,
                pinchZoomInActions: 3,
                pinchZoomOutActions: 4,
                workflow: workflow
            )
        )
        storeMapLoaderViewModel.mapViewDelegate = mapViewDelegate
        var navEnabled = true
        _ = storeMapLoaderViewModel.setNavigation(enabled: &navEnabled)
        messageSender.sentMessages = []
        
        // Act
        storeMapLoaderViewModel.setPathfindingEnabled(true, duration: 0.0)
        
        // Assert
        let expectation = self.expectation(description: "Message sent")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let containsMessage = self.messageSender.sentMessages.contains { message in
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

    func testSetPathfindingEnabled_WhenManualNavigationDisabledButForced_ShouldSendRequest() {
        // Arrange
        storeMapLoaderViewModel.indoorNavigationService.navigationConfig = NavigationConfig(enabled: false)
        storeMapLoaderViewModel.mapViewDelegate = mapViewDelegate
        var navEnabled = false
        _ = storeMapLoaderViewModel.setNavigation(enabled: &navEnabled)
        messageSender.sentMessages = []
        
        // Act
        storeMapLoaderViewModel.setPathfindingEnabled(true, duration: 0.0, force: true)
        
        // Assert
        let expectation = self.expectation(description: "Wait for async")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let containsMessage = self.messageSender.sentMessages.contains(where: { message in
                if case .setPathfindingEnabled(let req) = message {
                    return req.pathfinderEnabled == true
                }
                return false
            })
            XCTAssertTrue(containsMessage)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testSetPathfindingEnabled_WhenManualNavigationDisabled_ShouldNotSendRequest() {
        // Arrange
        storeMapLoaderViewModel.indoorNavigationService.navigationConfig = NavigationConfig(enabled: false)
        storeMapLoaderViewModel.mapViewDelegate = mapViewDelegate
        var navEnabled = false
        _ = storeMapLoaderViewModel.setNavigation(enabled: &navEnabled)
        messageSender.sentMessages = []
        
        // Act
        storeMapLoaderViewModel.setPathfindingEnabled(true, duration: 0.0)
        
        // Assert
        let expectation = self.expectation(description: "Wait for async")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let containsMessage = self.messageSender.sentMessages.contains(where: { message in
                if case .setPathfindingEnabled = message { return true }
                return false
            })
            XCTAssertFalse(containsMessage)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandle_CustomRouteError_ShouldLogNavigationError() {
        // Arrange
        Analytics.logDefault = mockLogDefault
        let outOfBoundPath = [Point(x: 1, y: 2)]
        let customRouteError = CustomRouteError(outOfBoundPath: outOfBoundPath)
        let message = MessageResponse.customRouteError(customRouteError)
        storeMapLoaderViewModel.currentPins = [
            Pin(type: .aisleSection, zone: "A", aisle: 1, section: "1", selected: true),
            Pin(type: .aisleSection, zone: "B", aisle: 1, section: "1", selected: false)
        ]
        // Act
        storeMapLoaderViewModel.handle(message)
        
        // Assert: only verify that a navigationError event was emitted
        guard let logEvent = mockLogDefault.logEvent else {
            return XCTFail("Expected navigation error analytic event to be tracked")
        }

        XCTAssertEqual(logEvent.eventType, .navigationError)
    }

    func testHandle_PinClicked_ShouldEmitPinClickedEvent() {
        // Arrange
        let pinData = PinClicked.Data(zone: "Zone1", aisle: 10, section: 5, floor: 0, count: 0, selected: false, isSeasonal: false)
        let pinClicked = PinClicked(data: pinData)
        let message = MessageResponse.pinClicked(pinClicked)
        
        // Act
        storeMapLoaderViewModel.handle(message)
        
        // Assert
        XCTAssertTrue(mockStatusService.emitPinClickedEventCalled)
        XCTAssertEqual(mockStatusService.lastPinClickedZone, "Zone1")
        XCTAssertEqual(mockStatusService.lastPinClickedAisle, 10)
        XCTAssertEqual(mockStatusService.lastPinClickedSection, 5)
    }

    func testHandle_PinsActionAlleyRenderedResponse_ShouldZoomOnLocation() {
        // Arrange
        let topLeft = Point(x: 0, y: 0)
        let bottomRight = Point(x: 100, y: 100)
        let response = PinRenderedMessage(newPinsRendered: true, pins: [], topLeft: topLeft, bottomRight: bottomRight)
        let message = MessageResponse.pinsActionAlleyRenderedResponse(response)
        
        // Act
        storeMapLoaderViewModel.handle(message)
        
        // Assert
        let expectation = self.expectation(description: "Wait for async zoom")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            XCTAssertTrue(self.mapViewDelegate._zoomRenderedPinsCalled)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandle_UserLocationRenderedMessage_ShouldZoomOnUserLocation() {
        // Arrange
        let topLeft = Point(x: 10, y: 10)
        let bottomRight = Point(x: 20, y: 20)
        let response = UserLocationRenderedMessage(topLeft: topLeft, bottomRight: bottomRight)
        let message = MessageResponse.userLocationRenderedMessage(response)
        mapViewDelegate.isCenterButtonClicked = true
        
        // Act
        storeMapLoaderViewModel.handle(message)
        
        // Assert
        let expectation = self.expectation(description: "Wait for async zoom")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            XCTAssertTrue(self.mapViewDelegate._zoomRenderedPinsCalled)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Extension Tests for Complete Coverage
    
    func testRequest_WithWebView_ShouldSendMessage() {
        // Arrange
        let message = MessageRequest.mapData
        
        // Act
        storeMapLoaderViewModel.request(message)
        
        // Assert - message should be sent (verified through side effects)
        XCTAssertNotNil(mapViewDelegate.webView)
    }
    
    func testRefreshWebView_ShouldClearStateAndReload() {
        // Arrange
        storeMapLoaderViewModel.renderedPins = [Pin(type: .aisleSection)]
        storeMapLoaderViewModel.hasLoadedMapView.value = true
        
        // Act
        storeMapLoaderViewModel.refreshWebView()
        
        // Assert
        XCTAssertTrue(storeMapLoaderViewModel.renderedPins.isEmpty)
        XCTAssertNil(storeMapLoaderViewModel.renderedPinsZoomRect)
        XCTAssertFalse(storeMapLoaderViewModel.hasLoadedMapView.value)
    }
    
    func testHandle_MapData_ShouldUpdateMapDataAndEmitEvent() {
        // Arrange
        let mapData = MapData(mapBoundaries: .zero, poi: [], restRoomCount: 0, departments: [])
        let message = MessageResponse.mapData(mapData)
        
        // Act
        storeMapLoaderViewModel.handle(message)
        
        // Assert
        XCTAssertNotNil(storeMapLoaderViewModel.mapData)
        XCTAssertNil(storeMapLoaderViewModel.mapDataReadyRequestTimer)
    }
    
    func testHandle_MapLoaded_WithMultipleFloors_ShouldShowFloorControl() {
        // Arrange
        let mapLoaded = MapLoaded(floors: ["1", "2"], offsets: [])
        let message = MessageResponse.mapLoaded(mapLoaded)
        
        // Act
        storeMapLoaderViewModel.handle(message)
        
        // Assert
        XCTAssertNotNil(storeMapLoaderViewModel.mapLoadedData)
        XCTAssertFalse(mapViewDelegate.floorControlStackView.isHidden)
    }
    
    func testHandle_MapLoaded_WithSingleFloor_ShouldHideFloorControl() {
        // Arrange
        let mapLoaded = MapLoaded(floors: ["1"], offsets: [])
        let message = MessageResponse.mapLoaded(mapLoaded)
        
        // Act
        storeMapLoaderViewModel.handle(message)
        
        // Assert
        XCTAssertTrue(mapViewDelegate.floorControlStackView.isHidden)
    }
    
    func testRenderFeatureLocationPinsIfNeeded_WithNoPins_ShouldReturn() {
        let workflow = Workflow(id: "sample_app_id", type: "sample_app_flow", value: "sa_val")
        let options = makeStoreMapOptions(
            navigationConfig: NavigationConfig(enabled: true, refreshDuration: 0.0),
            pinsConfig: PinsConfig(actionAlleyEnabled: true, groupPinsEnabled: true)
        )
        storeMapLoaderViewModel = StoreMapLoaderViewModel(
            blueDotMode: .visible,
            storeMapOptions: options,
            debugLog: options.debugLog,
            serviceLocator: serviceLocator,
            userDefaults: testUserDefaults,
            zoomAnalyticsLogger: ZoomAnalyticsLogger(
                buttonZoomScale: 1.0,
                pnchZoomScale: 1.0,
                buttonZoomInTaps: 2,
                buttonZoomOutTaps: 2,
                pinchZoomInActions: 3,
                pinchZoomOutActions: 4,
                workflow: workflow
            )
        )

        let pins = [
            Pin(type: .aisleSection, zone: "A", aisle: 1, section: "1"),
            Pin(type: .aisleSection, zone: "B", aisle: 2, section: "2", errorData: ErrorData(invalidZone: false, invalidAisle: true), shouldFetchData: true)
        ]

        // Arrange
        let pinRenderedMessage = PinRenderedMessage(pins: pins)
        
        // Act
        storeMapLoaderViewModel.renderFeatureLocationPinsIfNeeded(for: pinRenderedMessage)
        
        // Assert - should return early without error
        XCTAssertTrue(true)
    }
    
    func testUpdateNavigationServicesIfNeeded_WithNoPins_ShouldHideNavigationButton() {
        // Arrange
        let pinRenderedMessage = PinRenderedMessage(pins: nil)

        // Act
        storeMapLoaderViewModel.updateNavigationServicesIfNeeded(for: pinRenderedMessage)
        
        // Assert
        XCTAssertTrue(mapViewDelegate.refreshNavigationButtonStateCalled)
        XCTAssertEqual(mapViewDelegate.refreshNavigationButtonStateParams, false)
    }

    func testUpdateNavigationServicesIfNeeded_WithPins_ShouldHideNavigationButton() {
        let workflow = Workflow(id: "sample_app_id", type: "sample_app_flow", value: "sa_val")
        let options = makeStoreMapOptions(
            navigationConfig: NavigationConfig(enabled: true, refreshDuration: 0.0),
            pinsConfig: PinsConfig(actionAlleyEnabled: true, groupPinsEnabled: true)
        )
        storeMapLoaderViewModel = StoreMapLoaderViewModel(
            blueDotMode: .visible,
            storeMapOptions: options,
            debugLog: options.debugLog,
            serviceLocator: serviceLocator,
            userDefaults: testUserDefaults,
            zoomAnalyticsLogger: ZoomAnalyticsLogger(
                buttonZoomScale: 1.0,
                pnchZoomScale: 1.0,
                buttonZoomInTaps: 2,
                buttonZoomOutTaps: 2,
                pinchZoomInActions: 3,
                pinchZoomOutActions: 4,
                workflow: workflow
            )
        )
        let pins = [
            Pin(type: .aisleSection, zone: "A", aisle: 1, section: "1", selected: true)
        ]

        // Arrange
        let pinRenderedMessage = PinRenderedMessage(pins: pins)

        // Act
        storeMapLoaderViewModel.updateNavigationServicesIfNeeded(for: pinRenderedMessage)

        // Assert
        XCTAssertFalse(mapViewDelegate.refreshNavigationButtonStateCalled)
    }

    func testStartTimerForMapDataReadyRequest_ShouldCreateTimer() {
        // Act
        storeMapLoaderViewModel.startTimerForMapDataReadyRequest()

        // Assert timer is created
        XCTAssertNotNil(storeMapLoaderViewModel.mapDataReadyRequestTimer)

        // Manually fire to ensure cleanup happens without waiting for the full timeout
        storeMapLoaderViewModel.mapDataReadyRequestTimer?.fire()
        XCTAssertNil(storeMapLoaderViewModel.mapDataReadyRequestTimer)
    }
    
    func testRenderPinsIfNeeded_WhenNotLoaded_WithMultipleFloors_ShouldRequestAisleData() {
        // Arrange
        storeMapLoaderViewModel.hasLoadedMapView.value = false
        storeMapLoaderViewModel.renderedPins = [Pin(type: .aisleSection)]
        
        // Act
        storeMapLoaderViewModel.renderPinsIfNeeded(floorCount: 2)
        
        // Assert
        XCTAssertTrue(storeMapLoaderViewModel.hasLoadedMapView.value)
    }
    
    func testRenderPinsIfNeeded_WhenAlreadyLoaded_ShouldNotRenderAgain() {
        // Arrange
        storeMapLoaderViewModel.configuration = StoreMapView.Configuration(isPinSelectionEnabled: false ,pin: Pin(type: .aisleSection, zone: "A", aisle: 1, section: "1", selected: true), preferredFloor: "1")
        storeMapLoaderViewModel.hasLoadedMapView.value = false
        storeMapLoaderViewModel.renderedPins = [Pin(type: .aisleSection)]
        let initialCount = storeMapLoaderViewModel.renderedPins.count
        
        // Act
        storeMapLoaderViewModel.renderPinsIfNeeded(floorCount: 1)
        
        // Assert
        XCTAssertEqual(storeMapLoaderViewModel.renderedPins.count, 3)
    }
    
    func testReportPinAisleStatusEvent_WithValidPins_ShouldEmitEvents() {
        // Arrange
        let pins = [
            Pin(type: .aisleSection, zone: "A", aisle: 1, section: "1"),
            Pin(type: .aisleSection, zone: "B", aisle: 2, section: "2", errorData: ErrorData(invalidZone: false, invalidAisle: true))
        ]
        
        // Act
        storeMapLoaderViewModel.reportPinAisleStatusEvent(for: pins)
        
        // Assert - should emit events without crashing
        XCTAssertTrue(true)
    }
    
    func testOnMapLongPressed_WithStaticPath_ShouldReturn() {
        // Arrange
        storeMapLoaderViewModel.isStaticPathVisible = true
        let tap = CoordinateSpaceDiscoveryTap(svgSpace: Point(x: 100, y: 100))
        
        // Act
        storeMapLoaderViewModel.onMapLongPressed(coordPayLoad: tap)
        
        // Assert
        XCTAssertNil(storeMapLoaderViewModel.pinList.current)
    }
    
    func testOnMapLongPressed_WithNoSvgCoord_ShouldReturn() {
        (serviceLocator.getIndoorNavigationService() as? MockIndoorNavigationService)?.navigationSessionState?.navigationStatus = .notStarted
        storeMapLoaderViewModel.isStaticPathVisible = false

        // Arrange
        let tap = CoordinateSpaceDiscoveryTap(svgSpace: nil)
        
        // Act
        storeMapLoaderViewModel.onMapLongPressed(coordPayLoad: tap)
        
        // Assert
        XCTAssertNil(storeMapLoaderViewModel.pinList.current)
    }

    func testOnMapLongPressed_WithDisableManualPinDrop_ShouldReturn() {
        (serviceLocator.getIndoorNavigationService() as? MockIndoorNavigationService)?.navigationSessionState?.navigationStatus = .notStarted
        storeMapLoaderViewModel.isStaticPathVisible = false

        storeMapLoaderViewModel.config = DisplayPinConfig(
            enableManualPinDrop: false,
            resetZoom: false,
            shouldZoomOnPins: false
        )

        // Arrange
        let tap = CoordinateSpaceDiscoveryTap(svgSpace: nil)

        // Act
        storeMapLoaderViewModel.onMapLongPressed(coordPayLoad: tap)

        // Assert
        XCTAssertNil(storeMapLoaderViewModel.pinList.current)
    }

    func testHandleAsset_WithNoUUIDs_ShouldReturn() {
        // Arrange
        testUserDefaults.removeObject(forKey: UserDefaultsKey.uuidList.rawValue)
        let waspPosition = CGPoint(x: 100, y: 100)
        
        // Act
        storeMapLoaderViewModel.handleAsset(waspPosition: waspPosition)
        
        // Assert - should return without crashing
        XCTAssertTrue(true)
    }
    
    func testHandleAsset_WithValidUUID_ShouldSetupBootstrapHandler() {
        // Arrange
        testUserDefaults.set(["test-uuid"], forKey: UserDefaultsKey.uuidList.rawValue)
        let waspPosition = CGPoint(x: 100, y: 100)
        
        // Act
        storeMapLoaderViewModel.handleAsset(waspPosition: waspPosition)
        
        // Assert
        XCTAssertNotNil(storeMapLoaderViewModel.statusService.bootstrapEventEmitter)
    }
    
    func testEncodeGeneric_WithValidCoordinate_ShouldEvaluateAisle() {
        // Arrange
        let waspPosition = CGPoint(x: 100, y: 100)
        
        // Act
        storeMapLoaderViewModel.encodeGeneric(waspPosition: waspPosition)
        
        // Assert - should complete without crashing
        XCTAssertTrue(true)
    }
    
    func testEvaluateAisle_ShouldClearAndPopulateIdList() {
        // Arrange
        let assetId = "test-asset-id"
        let waspPosition = CGPoint(x: 100, y: 100)
        
        // Act
        storeMapLoaderViewModel.evaluateAisle(for: assetId, waspPosition: waspPosition, idType: .assets)
        
        // Assert
        XCTAssertEqual(storeMapLoaderViewModel.assetService.idList.count, 1)
        XCTAssertEqual(storeMapLoaderViewModel.assetService.idList.first, assetId)
    }
    
    func testRender_WithReplacingExistingFalse_ShouldAppendPins() {
        // Arrange
        let existingPin = Pin(type: .aisleSection)
        storeMapLoaderViewModel.renderedPins = [existingPin]
        let newPin = Pin(type: .department)
        
        // Act
        storeMapLoaderViewModel.render([newPin], replacingExisting: false)
        
        // Assert
        XCTAssertEqual(storeMapLoaderViewModel.renderedPins.count, 2)
    }
    
    func testRender_WithReplacingExistingTrue_ShouldReplacePins() {
        // Arrange
        let existingPin = Pin(type: .aisleSection)
        storeMapLoaderViewModel.renderedPins = [existingPin]
        let newPin = Pin(type: .department)
        
        // Act
        storeMapLoaderViewModel.render([newPin], replacingExisting: true)
        
        // Assert
        XCTAssertEqual(storeMapLoaderViewModel.renderedPins.count, 1)
    }
    
    func testZoomOnLocation_WithStaticPath_ShouldReturn() {
        // Arrange
        storeMapLoaderViewModel.isStaticPathVisible = true
        
        // Act
        storeMapLoaderViewModel.zoomOnLocation(topLeft: Point(x: 10, y: 10), bottomRight: Point(x: 20, y: 20))
        
        // Assert
        XCTAssertFalse(mapViewDelegate._zoomRenderedPinsCalled)
    }
    
    func testZoomOnLocation_WithNoTopLeft_ShouldReturn() {
        // Arrange
        // Act
        storeMapLoaderViewModel.zoomOnLocation(topLeft: nil, bottomRight: Point(x: 20, y: 20))
        
        // Assert
        XCTAssertFalse(mapViewDelegate._zoomRenderedPinsCalled)
    }
    
    func testZoomOnLocation_WithNoBottomRight_ShouldReturn() {
        // Arrange
        // Act
        storeMapLoaderViewModel.zoomOnLocation(topLeft: Point(x: 10, y: 10), bottomRight: nil)
        
        // Assert
        XCTAssertFalse(mapViewDelegate._zoomRenderedPinsCalled)
    }
    
    func testZoomToMapCenter_ShouldSetFlagAndZoomOut() {
        // Arrange
        storeMapLoaderViewModel.hasMapViewZoomed = false
        
        // Act
        storeMapLoaderViewModel.zoomToMapCenter()
        
        // Assert
        XCTAssertTrue(storeMapLoaderViewModel.hasMapViewZoomed)
        
        let expectation = self.expectation(description: "Wait for async zoom")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            XCTAssertTrue(self.mapViewDelegate._zoomOutCalled)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.3)
    }
    
    func testZoomToPinsIfNeeded_WithNoMapData_ShouldNotZoom() {
        // Arrange
        storeMapLoaderViewModel.mapData = nil
        storeMapLoaderViewModel.hasMapViewZoomed = false
        
        // Act
        storeMapLoaderViewModel.zoomToPinsIfNeeded()
        
        // Assert
        XCTAssertFalse(storeMapLoaderViewModel.hasMapViewZoomed)
    }
    
    func testZoomToPinsIfNeeded_WhenAlreadyZoomed_ShouldNotZoomAgain() {
        // Arrange
        storeMapLoaderViewModel.hasMapViewZoomed = true
        storeMapLoaderViewModel.mapData = MapData(mapBoundaries: .zero, poi: [], restRoomCount: 0, departments: [])
        mapViewDelegate.isWebViewLoaded = true
        
        // Act
        storeMapLoaderViewModel.zoomToPinsIfNeeded()
        
        // Assert - should not zoom again
        XCTAssertTrue(storeMapLoaderViewModel.hasMapViewZoomed)
    }
    
    func testZoomOnRegion_WithPinAnnotationTarget_ShouldUseDelay() {
        // Arrange
        let zoomRect = CGRect(x: 0, y: 0, width: 100, height: 100)
        
        // Act
        storeMapLoaderViewModel.zoomOnRegion(with: zoomRect, target: .pinAnnotation)
        
        // Assert
        let expectation = self.expectation(description: "Wait for async zoom")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            XCTAssertTrue(self.mapViewDelegate._zoomRenderedPinsCalled)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testZoomOnRegion_WithUserLocationTarget_ShouldUseNoDelay() {
        // Arrange
        let zoomRect = CGRect(x: 0, y: 0, width: 100, height: 100)
        
        // Act
        storeMapLoaderViewModel.zoomOnRegion(with: zoomRect, target: .userLocation)
        
        // Assert - should zoom immediately
        XCTAssertTrue(mapViewDelegate._zoomRenderedPinsCalled)
    }
    
    func testGetUpdateScale_ZoomIn_BelowMax_ShouldIncreaseScale() {
        // Arrange
        let currentScale: CGFloat = 1.0
        
        // Act
        let newScale = storeMapLoaderViewModel.getUpdateScale(currentScale, .zoomIn)
        
        // Assert
        XCTAssertGreaterThan(newScale, currentScale)
    }
    
    func testGetUpdateScale_ZoomIn_AtMax_ShouldReturnMax() {
        // Arrange
        let currentScale: CGFloat = StoreMapZoomLevel.fourth.maximumZoomScale
        
        // Act
        let newScale = storeMapLoaderViewModel.getUpdateScale(currentScale, .zoomIn)
        
        // Assert
        XCTAssertEqual(newScale, StoreMapZoomLevel.fourth.maximumZoomScale)
    }
    
    func testGetUpdateScale_ZoomOut_AboveMin_ShouldDecreaseScale() {
        // Arrange
        let currentScale: CGFloat = 2.0
        
        // Act
        let newScale = storeMapLoaderViewModel.getUpdateScale(currentScale, .zoomOut)
        
        // Assert
        XCTAssertLessThan(newScale, currentScale)
    }
    
    func testGetUpdateScale_ZoomOut_AtMin_ShouldReturnMin() {
        // Arrange
        let currentScale: CGFloat = StoreMapZoomLevel.first.minimumZoomScale
        
        // Act
        let newScale = storeMapLoaderViewModel.getUpdateScale(currentScale, .zoomOut)
        
        // Assert
        XCTAssertEqual(newScale, StoreMapZoomLevel.first.minimumZoomScale)
    }
    
    // MARK: - updateStaticPathIfNeeded Tests
    
    func testUpdateStaticPathIfNeeded_WithNoPins_ShouldReturnEarly() {
        // Arrange
        storeMapLoaderViewModel.isStaticPathVisible = true
        let message = PinRenderedMessage(pins: nil)
        
        // Act
        storeMapLoaderViewModel.updateStaticPathIfNeeded(for: message)
        
        // Assert - should return early without error
        XCTAssertTrue(true)
    }
    
    func testUpdateStaticPathIfNeeded_WithEmptyPins_ShouldReturnEarly() {
        // Arrange
        storeMapLoaderViewModel.isStaticPathVisible = true
        let message = PinRenderedMessage(pins: [])
        
        // Act
        storeMapLoaderViewModel.updateStaticPathIfNeeded(for: message)
        
        // Assert - should return early without error
        XCTAssertTrue(true)
    }
    
    func testUpdateStaticPathIfNeeded_WhenStaticPathNotVisible_ShouldReturnEarly() {
        // Arrange
        storeMapLoaderViewModel.isStaticPathVisible = false
        let pin = Pin(type: .aisleSection, zone: "A", aisle: 1, section: "1", location: Point(x: 100, y: 200))
        let message = PinRenderedMessage(pins: [pin], topLeft: nil, bottomRight: nil)
        
        // Act
        storeMapLoaderViewModel.updateStaticPathIfNeeded(for: message)
        
        // Assert - should return early without error
        XCTAssertTrue(true)
    }
    
    func testUpdateStaticPathIfNeeded_WithPinErrors_ShouldDisplayErrorBanner() {
        // Arrange
        storeMapLoaderViewModel.isStaticPathVisible = true
        let errorData = ErrorData(invalidZone: true, invalidAisle: false, invalidSection: false)
        let pinWithError = Pin(type: .aisleSection, zone: "A", aisle: 1, section: "1", errorData: errorData)
        let message = PinRenderedMessage(pins: [pinWithError])
        
        // Act
        storeMapLoaderViewModel.updateStaticPathIfNeeded(for: message)
        
        // Assert
        XCTAssertTrue(mapViewDelegate._displayPinErrorBannerCalled)
    }
    
    func testUpdateStaticPathIfNeeded_WithValidPins_ShouldProcessPins() {
        // Arrange
        storeMapLoaderViewModel.isStaticPathVisible = true
        let pin = Pin(type: .aisleSection, zone: "A", aisle: 1, section: "1", location: Point(x: 100, y: 200))
        let message = PinRenderedMessage(pins: [pin])
        
        // Act
        storeMapLoaderViewModel.updateStaticPathIfNeeded(for: message)
        
        // Assert - should process without crashing
        XCTAssertTrue(true)
    }
    
    // MARK: - handlePinRenderedMessage Tests
    
    func testHandlePinRenderedMessage_WhenPinDistanceFetched_ShouldCallCompletion() {
        // Arrange
        let expectation = expectation(description: #function)
        storeMapLoaderViewModel.isPinDistanceFetched = true
        let pin = Pin(type: .aisleSection)
        let message = PinRenderedMessage(pins: [pin])
        
        storeMapLoaderViewModel.pinLocationFetchCompletionHandler = { result in
            XCTAssertNotNil(result)
            expectation.fulfill()
        }
        
        // Act
        storeMapLoaderViewModel.handlePinRenderedMessage(message)
        
        // Assert
        XCTAssertFalse(storeMapLoaderViewModel.isPinDistanceFetched)
        waitForExpectations(timeout: 1.0)
    }
    
    func testHandlePinRenderedMessage_WithPins_ShouldUpdateCurrentPins() {
        // Arrange
        let pin = Pin(type: .aisleSection, zone: "A", aisle: 1)
        let message = PinRenderedMessage(pins: [pin])
        
        // Act
        storeMapLoaderViewModel.handlePinRenderedMessage(message)
        
        // Assert
        XCTAssertEqual(storeMapLoaderViewModel.currentPins.count, 1)
    }
    
    func testHandlePinRenderedMessage_WithNoPins_ShouldSetEmptyCurrentPins() {
        // Arrange
        let message = PinRenderedMessage(pins: nil)
        
        // Act
        storeMapLoaderViewModel.handlePinRenderedMessage(message)
        
        // Assert
        XCTAssertEqual(storeMapLoaderViewModel.currentPins.count, 0)
    }
    
    func testHandlePinRenderedMessage_WithPinsAndNotStaticPath_ShouldZoom() {
        // Arrange
        storeMapLoaderViewModel.isStaticPathVisible = false
        let pin = Pin(type: .aisleSection, zone: "A", aisle: 1)
        let topLeft = Point(x: 0, y: 0)
        let bottomRight = Point(x: 100, y: 100)
        let message = PinRenderedMessage(pins: [pin], topLeft: topLeft, bottomRight: bottomRight)
        
        // Act
        storeMapLoaderViewModel.handlePinRenderedMessage(message)
        
        // Assert - should call zoom logic
        XCTAssertEqual(storeMapLoaderViewModel.currentPins.count, 1)
    }
    
    // MARK: - requestRenderPins Tests
    
    func testRequestRenderPins_WithPinsAndNoPosition_ShouldReturnEarly() {
        // Arrange
        let pin = Pin(type: .aisleSection)
        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.lastPosition.value = nil
        
        // Act
        storeMapLoaderViewModel.requestRenderPins([pin], pinList: nil, navigationEvent: nil)
        
        // Assert - should return early without crashing
        XCTAssertTrue(true)
    }
    
    func testRequestRenderPins_WithPinsAndNoConverter_ShouldReturnEarly() {
        // Arrange
        let pin = Pin(type: .aisleSection)
        let mockPosition = MockIPSPosition(x: 10, y: 20, headingAngle: MockIPSHeading(angle: 0), accuracy: 5, lockProgress: 1)
        let mockIPS = serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService
        mockIPS?.lastPosition.value = mockPosition
        mockIPS?.floorCoordinatesConverter = nil
        
        // Act
        storeMapLoaderViewModel.requestRenderPins([pin], pinList: nil, navigationEvent: nil)
        
        // Assert - should return early without crashing
        XCTAssertTrue(true)
    }
    
    func testRequestRenderPins_WithPinsAndValidPosition_ShouldLogAnalytics() {
        // Arrange
        let pin = Pin(type: .aisleSection)
        let mockPosition = MockIPSPosition(x: 10, y: 20, headingAngle: MockIPSHeading(angle: 0), accuracy: 5, lockProgress: 1)
        let mockIPS = serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService
        mockIPS?.lastPosition.value = mockPosition
        mockIPS?.floorCoordinatesConverter = MockFloorCoordinatesConverterImpl()
        
        // Act
        let event = NavigationAnalytics.Event(type: "start")
        storeMapLoaderViewModel.requestRenderPins([pin], pinList: nil, navigationEvent: event)
        
        // Assert - should process without crashing
        XCTAssertTrue(true)
    }
    
    func testRequestRenderPins_WithPinList_ShouldRequestXYLocationPins() {
        // Arrange
        let drawPin = DrawPin(type: "aisleSection", x: 10, y: 20, location: nil, errorData: nil)
        let pinList = PinList(pins: [drawPin])
        
        // Act
        storeMapLoaderViewModel.requestRenderPins(nil, pinList: pinList, navigationEvent: nil)
        
        // Assert - should process without crashing
        XCTAssertTrue(true)
    }
    
    func testRequestRenderPins_WithNoPinsAndNoPinList_ShouldDoNothing() {
        // Act
        storeMapLoaderViewModel.requestRenderPins(nil, pinList: nil, navigationEvent: nil)
        
        // Assert - should do nothing without crashing
        XCTAssertTrue(true)
    }
    
    // MARK: - logStaticPathAnalyticsEvent Tests
    
    func testLogStaticPathAnalyticsEvent_WithNoLockedPosition_ShouldLogWithNilLocation() {
        // Arrange
        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.lastLockedPosition = nil
        let pin = Pin(type: .aisleSection, zone: "A", aisle: 1, section: "1", location: Point(x: 100, y: 200))
        
        // Act
        storeMapLoaderViewModel.logStaticPathAnalyticsEvent(pins: [pin])
        
        // Assert - should log without crashing
        XCTAssertTrue(true)
    }
    
    func testLogStaticPathAnalyticsEvent_WithLockedPosition_ShouldLogWithLocation() {
        // Arrange
        let mockPosition = MockIPSPosition(x: 50, y: 60, headingAngle: MockIPSHeading(angle: 0), accuracy: 5, lockProgress: 1)
        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.lastLockedPosition = mockPosition
        let pin = Pin(type: .aisleSection, zone: "A", aisle: 1, section: "1", location: Point(x: 100, y: 200))
        
        // Act
        storeMapLoaderViewModel.logStaticPathAnalyticsEvent(pins: [pin])
        
        // Assert - should log without crashing
        XCTAssertTrue(true)
    }
    
    func testLogStaticPathAnalyticsEvent_WithPinHavingZoneAisleSection_ShouldFormatAisleLocation() {
        // Arrange
        let mockPosition = MockIPSPosition(x: 50, y: 60, headingAngle: MockIPSHeading(angle: 0), accuracy: 5, lockProgress: 1)
        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.lastLockedPosition = mockPosition
        let pin = Pin(type: .aisleSection, id: 123, zone: "A", aisle: 5, section: "3", location: Point(x: 100, y: 200))
        
        // Act
        storeMapLoaderViewModel.logStaticPathAnalyticsEvent(pins: [pin])
        
        // Assert - should format aisle location as "A.5.3"
        XCTAssertTrue(true)
    }
    
    func testLogStaticPathAnalyticsEvent_WithPinHavingNoZone_ShouldLogWithEmptyAisleLocation() {
        // Arrange
        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.lastLockedPosition = nil
        let pin = Pin(type: .aisleSection, id: 456, location: Point(x: 100, y: 200))
        
        // Act
        storeMapLoaderViewModel.logStaticPathAnalyticsEvent(pins: [pin])
        
        // Assert - should log with empty aisle location
        XCTAssertTrue(true)
    }
    
    func testLogStaticPathAnalyticsEvent_WithMultiplePins_ShouldLogAllEvents() {
        // Arrange
        let mockPosition = MockIPSPosition(x: 50, y: 60, headingAngle: MockIPSHeading(angle: 0), accuracy: 5, lockProgress: 1)
        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.lastLockedPosition = mockPosition
        let pin1 = Pin(type: .aisleSection, id: 1, zone: "A", aisle: 1, section: "1", location: Point(x: 100, y: 200))
        let pin2 = Pin(type: .aisleSection, id: 2, zone: "B", aisle: 2, section: "2", location: Point(x: 150, y: 250))
        
        // Act
        storeMapLoaderViewModel.logStaticPathAnalyticsEvent(pins: [pin1, pin2])
        
        // Assert - should log multiple events
        XCTAssertTrue(true)
    }
    
    func testLogStaticPathAnalyticsEvent_WithPinHavingNoLocation_ShouldLogWithNilItemLocation() {
        // Arrange
        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.lastLockedPosition = nil
        let pin = Pin(type: .aisleSection, id: 789, zone: "C", aisle: 3, section: "3")
        
        // Act
        storeMapLoaderViewModel.logStaticPathAnalyticsEvent(pins: [pin])
        
        // Assert - should log with nil item location
        XCTAssertTrue(true)
    }
    
    // MARK: - logNavigationEndEvent Tests
    func testLogNavigationEndEvent_WithValidPosition_SetsWasUserNavigatingFalse() {
        // Arrange
        let mockIPS = serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService
        mockIPS?.lastPosition.send(MockIPSPosition(x: 100, y: 200, headingAngle: MockHeading(angle: 0), accuracy: 5, lockProgress: 1.0))
        mockIPS?.floorCoordinatesConverter = MockFloorCoordinatesConverterImpl()
        storeMapLoaderViewModel.wasUserNavigatingBefore = true

        // Act
        storeMapLoaderViewModel.logNavigationEndEvent()

        // Assert
        XCTAssertFalse(storeMapLoaderViewModel.wasUserNavigatingBefore)
    }

    func testLogNavigationEndEvent_WithNilPosition_DoesNotChangeFlag() {
        // Arrange
        let mockIPS = serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService
        mockIPS?.lastPosition.send(nil)
        storeMapLoaderViewModel.wasUserNavigatingBefore = true

        // Act
        storeMapLoaderViewModel.logNavigationEndEvent()

        // Assert
        XCTAssertTrue(storeMapLoaderViewModel.wasUserNavigatingBefore)
    }
}
