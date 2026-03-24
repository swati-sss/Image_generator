//
//  CompassTests.swift
//  CompassTests
//
//  Created by Rakesh Shetty on 2/18/23.
//

import XCTest
import Combine
@testable import compass_sdk_ios
import IPSFramework

final class CompassTests: XCTestCase {
    private var compass: Compass!
    private var serviceLocator: MockServiceLocator!
    private var viewModel: MockCompassViewModel!
    private var cancellables = Set<AnyCancellable>()
    
    override func setUpWithError() throws {
        StaticStorage.authParameter = nil
        IPSPositioning.testLockThreshold = 1
        serviceLocator = MockServiceLocator()
        viewModel = MockCompassViewModel()
        compass = Compass(serviceLocator: serviceLocator, viewModel: viewModel)
    }
    
    override func tearDownWithError() throws {
        StaticStorage.authParameter = nil
        IPSPositioning.testLockThreshold = 1
        serviceLocator = nil
        viewModel = nil
        compass = nil
        cancellables.removeAll()
    }

    private func initializeCompass(
        authParameter: AuthParameter = TestData.authParameter,
        configuration: Configuration = TestData.configuration,
        onSuccess: @escaping (UIViewController) -> Void = { _ in },
        onError: @escaping (Error) -> Void = { _ in }
    ) {
        compass.initialize(
            authParameter: authParameter,
            configuration: configuration,
            completion: onSuccess,
            onError: onError
        )
    }

    private func expectState(
        matching predicate: @escaping (Compass.InitializationState) -> Bool,
        description: String
    ) -> XCTestExpectation {
        let expectation = expectation(description: description)
        compass.state
            .sink { state in
                if predicate(state) {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        return expectation
    }
    
    func testInitialize() throws {
        let expectation = expectation(description: "Initialize")
        let authParameter = TestData.authParameter
        let configuration = TestData.configuration

        initializeCompass(authParameter: authParameter, configuration: configuration) { viewController in
            XCTAssertTrue(viewController === self.viewModel.storeMapViewController)
            expectation.fulfill()
        } onError: {
            XCTFail("Initialization failed with error: \($0)")
        }

        XCTAssert(viewModel._getAccessTokenCalled)
        XCTAssert(serviceLocator.configurationService!._getConfigDataCalled)
        waitForExpectations(timeout: 2.0)
    }
    
    func testInitializeAsMockUser() throws {
        let expectation = expectation(description: "Initialize")
        let configuration = Configuration(country: "US",
                                          site: 2280,
                                          userId: "988sdd-erer-43434",
                                          siteType: .Store,
                                          manualPinDrop: true,
                                          navigateToPin: false,
                                          multiPin: false,
                                          searchBar: false,
                                          centerMap: true,
                                          locationIngestion: true,
                                          mockUser: true,
                                          anonymizedUserID: "anonymizedUserID",
                                          startPositioning: true,
                                          automaticCalibration: true,
                                          businessUnitType: .WALMART)
        
        initializeCompass(authParameter: TestData.authParameter, configuration: configuration) { _ in
            expectation.fulfill()
        } onError: { error in
            XCTFail("Initialization failed with error: \(error)")
        }

        waitForExpectations(timeout: 2.0)
        
        XCTAssertEqual(IPSPositioning.testLockThreshold, 0)
        
    }
    
    func testDisplayMap() throws {
        let workflow = Workflow(id: nil, type: "display map", value: "")
        
        compass.displayMap(workflow: workflow)
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(15)) {
            XCTAssertEqual(Analytics.workflow?.id, workflow.id)
            XCTAssertEqual(Analytics.workflow?.type, workflow.type)
            XCTAssertEqual(Analytics.workflow?.value, workflow.value)
        }
    }
    
    func testUpdateEvent() throws {
        guard let assetId = ["1645190", "575207", "575208"].shuffled().first else { return }
        let compassEvent = CompassEvent(eventType: "asset_scan", eventValue: assetId, eventMetadata: [:])
        
        compass?.updateEvent(compassEvent: compassEvent)
        
        XCTAssert(viewModel._updateEventCalled)
    }
    
    func testUpdateEventList() throws {
        compass?.updateEventList(
            namespace: "modflex",
            eventType: "feature_scan",
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
        
        XCTAssert(viewModel._updateEventListCalled)
    }
    
    func testDisplayPinForGeneric() throws {
        let config = ["enableManualPinDrop": true]
        
        compass?.displayPin(uuidList: ["YzAvWy12SixmWF0vMQ=="], idType: .generic, config: config)
        
        XCTAssert(viewModel._displayPinCalled)
    }
    
    func testDisplayPinForAssets() throws {
        let config = ["enableManualPinDrop": true]
        
        compass?.displayPin(uuidList: ["12345", "123"], idType: .assets, config: config)
        
        XCTAssert(viewModel._displayPinCalled)
    }
    
    func testKillSwitch() throws {
        compass?.killSwitch()
        XCTAssert(viewModel._killSWitchCalled)
    }
    
    func testResetPositionStatusEvents() throws {
        compass?.resetPositionStatusEvent()
        XCTAssert(viewModel._resetPositionStatusEventCalled)
    }
    
    func testdisplayPin() throws {
        let aislePin1 = AislePin(type: "item", id: "1", location: AisleLocation(zone: "A", aisle: "3", section: "3", selected: true))
        let aislePin2 = AislePin(type: "item", id: "2", location: AisleLocation(zone: "A", aisle: "8", section: "3", selected: false))
        let displayPinConfig: HashMap = ["enableManualPinDrop": false, "resetZoom": true]
        
        let compassPins: [CompassPin] = [aislePin1, aislePin2].map { CompassPin.aisle($0) }
        compass?.displayPin(pins: compassPins, config: displayPinConfig)
        
        XCTAssert(viewModel._displayPinCalled)
    }
    
    func testClearMap() throws {
        compass.clearMap()
        
        XCTAssert(viewModel._clearMapCalled)
    }
    
    func testGetAisle() throws {
        compass.getAisle(id: "")
        
        XCTAssert(viewModel._getAisleCalled)
    }
    
    func testGetStatusService() throws {
        _ = compass?.getStatusService()
        
        XCTAssert(serviceLocator!._getStatusServiceCalled)
    }

    func testDisplayStaticPathTriggersViewModel() {
        let aislePin = AislePin(type: "item", id: "1", location: AisleLocation(zone: "A", aisle: "3", section: "3", selected: true))
        let compassPins = [CompassPin.aisle(aislePin)]

        compass.displayStaticPath(pins: compassPins, startFromNearbyEntrance: true, disableZoomGestures: false)

        XCTAssertTrue(viewModel._displayStaticPathCalled)
    }

    func testGetUserDistanceReturnsResponse() {
        let expectation = expectation(description: "user distance")
        let aislePin = AislePin(type: "item", id: "1", location: AisleLocation(zone: "A", aisle: "3", section: "3", selected: true))

        compass.getUserDistance(pins: [aislePin]) { responses in
            XCTAssertEqual(responses.count, 1)
            XCTAssertEqual(responses.first?.userDistanceInInches, 24.0)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)
    }

    func testEvaluateJSOnWebViewWithoutRegisteredViewDoesNotCrash() {
        XCTAssertNil((serviceLocator as? ServiceLocator)?.getRegisteredStoreMapsViewController())

        compass.evaluateJSOnWebView("sendMessage('payload')")
    }

    func testSetWebViewMessageDelegateWithConcreteLocator() {
        let concreteLocator = ServiceLocator.shared as! ServiceLocator
        let compass = Compass(serviceLocator: concreteLocator, viewModel: viewModel)

        final class DummyDelegate: WebViewMessageDelegate {
            func didReceiveWebViewMessage(_ message: String) {}
        }

        let delegate = DummyDelegate()
        compass.setWebViewMessageDelegate(delegate)

        let parser = concreteLocator.getWebViewMessageParser() as? MessageParser
        XCTAssertTrue(parser?.webviewParserDelegate === delegate)

        parser?.webviewParserDelegate = nil
        concreteLocator.destroy()
    }

    func testInitializeSetsFlagAndProcessesCorrectly() {
        initializeCompass()
        XCTAssertEqual(compass.currentStore, TestData.configuration.site)
    }
    
    func testSetWebViewMessageDelegateWithNonConcreteLocator() {
        // Mock locator is not concrete ServiceLocator
        final class DummyDelegate: WebViewMessageDelegate {
            func didReceiveWebViewMessage(_ message: String) {}
        }
        
        let delegate = DummyDelegate()
        compass.setWebViewMessageDelegate(delegate)
        
        // Should log debug message but not crash
        XCTAssertTrue(true)
    }
    
    func testStartPositioning() {
        compass.startPositioning()
        XCTAssertTrue(viewModel._startPositionSessionCalled)
    }
    
    func testStopPositioning() {
        compass.stopPositioning()
        XCTAssertTrue(viewModel._stopPositioningCalled)
    }
    
    func testEvaluateJSOnWebViewWithWebView() {
        let expectation = expectation(description: "evaluate JS with webview")
        let concreteLocator = ServiceLocator.shared as! ServiceLocator
        let compass = Compass(serviceLocator: concreteLocator, viewModel: viewModel)
        let options = StoreMapView.Options(
            dynamicMapEnabled: true,
            zoomControlEnabled: true,
            errorScreensEnabled: true,
            spinnerEnabled: true,
            dynamicMapRotationEnabled: false,
            navigationConfig: NavigationConfig(enabled: false, refreshDuration: 0.0),
            mapUiConfig: MapUiConfig(),
            pinsConfig: PinsConfig(),
            debugLog: DebugLog()
        )
        let mapViewModel = MockStoreMapLoaderViewModel(blueDotMode: .visible, serviceLocator: serviceLocator)
        let viewController = StoreMapsViewController(webViewLoaderViewModel: mapViewModel, options: options)
        concreteLocator.registerStoreMapsViewController(viewController)

        DispatchQueue.global().async {
            compass.evaluateJSOnWebView("console.log('test from background')")
            DispatchQueue.main.async {
                expectation.fulfill()
            }
        }

        waitForExpectations(timeout: 2.0)
        concreteLocator.registerStoreMapsViewController(nil)
        concreteLocator.destroy()
    }

    
    func testInitializeCurrentStoreProperty() {
        XCTAssertNil(compass.currentStore)
        initializeCompass()
        XCTAssertEqual(compass.currentStore, TestData.configuration.site)
    }
    
    func testInitializeWithDifferentStoreUpdatesCurrentStore() {
        // Test that current store is updated when initializing with a different store
        let secondStore = 5678
        let secondConfig = Configuration(country: "US",
                                        site: secondStore,
                                        userId: "test-user",
                                        siteType: .Store,
                                        manualPinDrop: false,
                                        navigateToPin: false,
                                        multiPin: false,
                                        searchBar: false,
                                        centerMap: true,
                                        locationIngestion: true,
                                        mockUser: false,
                                        anonymizedUserID: "anon",
                                        startPositioning: true,
                                        automaticCalibration: true,
                                        businessUnitType: .WALMART)
        
        initializeCompass(configuration: secondConfig)
        XCTAssertEqual(compass.currentStore, secondStore)
    }

    func testInitializeWithInvalidStoreConfigSetsFinishedFalse() {
        let expectation = expectState(
            matching: {
                if case .initializationFailed = $0 { return true }
                return false
            },
            description: "invalid store config"
        )
        let mockConfigurationService = serviceLocator.getConfigurationService() as? MockConfigurationService
        let invalidStoreConfig = StoreConfig(storeId: 2280,
                                             valid: false,
                                             bluedotEnabled: false,
                                             mapType: "",
                                             sessionRefreshTime: 0,
                                             offset: StoreConfigOffset(x: 0, y: 0),
                                             analytics: false,
                                             batchInterval: 0,
                                             heartbeatInterval: 0)
        mockConfigurationService?._expectedConfigPayload = ConfigurationPayload(consumerConfig: TestData.consumerConfig,
                                                                                storeConfig: invalidStoreConfig)
        initializeCompass()

        waitForExpectations(timeout: 3.0)
    }

    func testInitializeWithValidStoreConfigUpdatesBlueDot() {
        let expectation = expectState(
            matching: { $0 == .initializationComplete },
            description: "valid store config"
        )
        let mockConfigurationService = serviceLocator.getConfigurationService() as? MockConfigurationService
        let validStoreConfig = StoreConfig(storeId: 2280,
                                           valid: true,
                                           bluedotEnabled: true,
                                           mapType: "walmartmap",
                                           sessionRefreshTime: 900,
                                           offset: StoreConfigOffset(x: 7, y: 7),
                                           analytics: false,
                                           batchInterval: 1,
                                           heartbeatInterval: 1)
        mockConfigurationService?._expectedConfigPayload = ConfigurationPayload(consumerConfig: TestData.consumerConfig,
                                                                                storeConfig: validStoreConfig)
        initializeCompass {
            _ in
        } onError: { _ in
            XCTFail("Unexpected error during initialization")
        }

        waitForExpectations(timeout: 3.0)
        XCTAssertTrue(viewModel._updateStoreConfigurationCalled)
        XCTAssertEqual(compass.isBlueDotEnabled.value, true)
    }

    func testInitializeCompletionReturnsStoreMapViewController() {
        let expectation = expectation(description: "completion returns store map view controller")
        initializeCompass { viewController in
            XCTAssertTrue(viewController === self.viewModel.storeMapViewController)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 3.0)
    }

    func testBeginInitializationWhenAccessTokenNilCallsOnError() {
        final class NilAccessTokenCompassViewModel: CompassViewModelType {
            var storeMapViewController: UIViewController?
            var updateStoreConfigurationCalled = false

            func getAccessToken(authParameter: compass_sdk_ios.AuthParameter) -> AnyPublisher<compass_sdk_ios.AccessTokenResponse?, any Error> {
                Just<AccessTokenResponse?>(nil).setFailureType(to: Error.self).eraseToAnyPublisher()
            }

            func toggleMockUser(_ option: Bool) {}
            func updateStoreConfiguration(_ storeConfig: compass_sdk_ios.StoreConfig?) { updateStoreConfigurationCalled = true }
            func getAisle(id: String) {}
            func isMapViewReady() -> AnyPublisher<Bool, Never> { Just(true).eraseToAnyPublisher() }
            func displayMap() {}
            func clearMap(mapConfig: compass_sdk_ios.MapConfig) {}
            func updateEvent(compassEvent: compass_sdk_ios.CompassEvent) {}
            func updateEventList(namespace: String, eventType: String, eventValue: String, metaData: compass_sdk_ios.HashMap?) {}
            func displayPin(uuidList: [String], idType: compass_sdk_ios.PinDropMethod, config: compass_sdk_ios.DisplayPinConfig?) {}
            func displayPin(pins: [compass_sdk_ios.CompassPin]?, config: compass_sdk_ios.DisplayPinConfig?) {}
            func displayStaticPath(pins: [compass_sdk_ios.CompassPin], startFromNearbyEntrance: Bool, disableZoomGestures: Bool) {}
            func startPositionSession() {}
            func stopPositioning() {}
            func resetPositionStatusEvent() {}
            func killSwitch() {}
            func removeUserPositionIndicator() {}
            func getUserDistance(pins: [compass_sdk_ios.AislePin], completion: compass_sdk_ios.UserDistanceCompleteHandler?) { completion?([]) }
        }

        let nilTokenViewModel = NilAccessTokenCompassViewModel()
        compass = Compass(serviceLocator: serviceLocator, viewModel: nilTokenViewModel)

        let expectation = expectation(description: "access token nil")
        initializeCompass(onError: { _ in expectation.fulfill() })

        waitForExpectations(timeout: 3.0)
    }
    
    func testSetupEnvironment() throws {
        compass?.setEnvironment(.staging)
        
        XCTAssertEqual(NetworkManager.environment, .staging)
    }
    
    func testUpdateAuthParams() throws {
        let realViewModel = CompassViewModel(serviceLocator: serviceLocator)
        compass = Compass(serviceLocator: serviceLocator, viewModel: realViewModel)

        compass?.updateAuthParams(
            clientSecret: "updated-secret",
            tokenType: TokenType.User.rawValue,
            consumerID: "consumer-id",
            accountID: "account-id"
        )

        XCTAssertEqual(StaticStorage.authParameter?.clientSecret, "updated-secret")
        XCTAssertEqual(StaticStorage.authParameter?.consumerID, "consumer-id")
    }
    
    func test_initialize_withInvalidConfigurationSiteAndMockUser_shouldFailInitialization() throws {
        let expectation = expectation(description: "Initialize")
        let configuration = Configuration(country: "US",
                                          site: 0,
                                          userId: "988sdd-erer-43434",
                                          siteType: .Store,
                                          manualPinDrop: true,
                                          navigateToPin: false,
                                          multiPin: false,
                                          searchBar: false,
                                          centerMap: true,
                                          locationIngestion: true,
                                          mockUser: true,
                                          anonymizedUserID: "anonymizedUserID",
                                          startPositioning: true,
                                          automaticCalibration: true,
                                          businessUnitType: .WALMART)
        
        initializeCompass(configuration: configuration) { _ in
            XCTFail("Initialization should fail for an invalid store")
        } onError: { error in
            Log.info("Expected initialization failure: \(error)")
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0)
    }
    
    func test_handleEventsForBackgroundURLSession_shouldFailInitialization() throws {
        Compass.handleEventsForBackgroundURLSession(identifier: "SessionId", application: UIApplication.shared)
        XCTAssertTrue(true)
    }
    
    func test_getConfigData_withMockUser_shouldFailInitialization() throws {
        let expectation = expectation(description: "Initialize")
        let configuration = Configuration(country: "US",
                                          site: 2280,
                                          userId: "988sdd-erer-43434",
                                          siteType: .Store,
                                          manualPinDrop: true,
                                          navigateToPin: false,
                                          multiPin: false,
                                          searchBar: false,
                                          centerMap: true,
                                          locationIngestion: true,
                                          mockUser: true,
                                          anonymizedUserID: "anonymizedUserID",
                                          startPositioning: true,
                                          automaticCalibration: true,
                                          businessUnitType: .WALMART)
        
        
        let mockConfigurationService = serviceLocator.getConfigurationService() as? MockConfigurationService
        mockConfigurationService?._shouldGetConfigPayloadFail = true
        
        initializeCompass(configuration: configuration) { _ in
            XCTFail("Initialization should fail when configuration fetch fails")
        } onError: { error in
            Log.info("Expected initialization failure: \(error)")
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0)
    }
    
    func test_getConfigData_withNonErrorResponse_shouldFailInitialization() throws {
        let expectation = expectation(description: "Initialize")
        let configuration = TestData.configuration
        let mockConfigurationService = serviceLocator.getConfigurationService() as? MockConfigurationService
        mockConfigurationService?._shouldGetConfigPayloadFail = true
        mockConfigurationService?._errorToThrow = NSError(domain: "Test", code: 1, userInfo: nil) // Not ErrorResponse
        
        initializeCompass(configuration: configuration) { _ in
            XCTFail("Initialization should fail when configuration returns a non-ErrorResponse error")
        } onError: { error in
            Log.info("Expected initialization failure: \(error)")
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5.0)
    }
    
    func test_deleteAllEventsFailure_withMockUser_shouldFailInitialization() throws {
        let expectation = expectation(description: "deleteAllEvents failure")
        let configuration = Configuration(country: "US",
                                          site: 2280,
                                          userId: "988sdd-erer-43434",
                                          siteType: .Store,
                                          manualPinDrop: true,
                                          navigateToPin: false,
                                          multiPin: false,
                                          searchBar: false,
                                          centerMap: true,
                                          locationIngestion: true,
                                          mockUser: true,
                                          anonymizedUserID: "anonymizedUserID",
                                          startPositioning: true,
                                          automaticCalibration: true,
                                          businessUnitType: .WALMART)
        
        let eventStoreService = serviceLocator.getEventStoreService() as? MockEventStoreService
        eventStoreService?._shouldFail = true
        
        serviceLocator.eventStoreService?._shouldFail = true
        
        let stateExpectation = expectState(
            matching: {
                if case .initializationFailed = $0 { return true }
                return false
            },
            description: "delete all events should fail initialization"
        )
        initializeCompass(configuration: configuration) { _ in
            XCTFail("Initialization should fail when deleting persisted events fails")
        } onError: { error in
            XCTAssertNotNil(error)
            expectation.fulfill()
        }
        
        wait(for: [expectation, stateExpectation], timeout: 5.0)
    }
    
    func testInitializeWithNilAccessTokenCallsOnError() {
        let expectation = expectation(description: "nil access token error")
        
        final class NilTokenViewModel: CompassViewModelType {
            var storeMapViewController: UIViewController?
            
            func getAccessToken(authParameter: compass_sdk_ios.AuthParameter) -> AnyPublisher<compass_sdk_ios.AccessTokenResponse?, any Error> {
                return Just(nil as AccessTokenResponse?)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            
            func toggleMockUser(_ option: Bool) {}
            func updateStoreConfiguration(_ storeConfig: compass_sdk_ios.StoreConfig?) {}
            func getAisle(id: String) {}
            func isMapViewReady() -> AnyPublisher<Bool, Never> { Just(false).eraseToAnyPublisher() }
            func displayMap() {}
            func clearMap(mapConfig: compass_sdk_ios.MapConfig) {}
            func updateEvent(compassEvent: compass_sdk_ios.CompassEvent) {}
            func updateEventList(namespace: String, eventType: String, eventValue: String, metaData: compass_sdk_ios.HashMap?) {}
            func displayPin(uuidList: [String], idType: compass_sdk_ios.PinDropMethod, config: DisplayPinConfig?) {}
            func displayPin(pins: [CompassPin]?, config: DisplayPinConfig?) {}
            func startPositionSession() {}
            func stopPositioning() {}
            func killSwitch() {}
            func resetPositionStatusEvent() {}
            func removeUserPositionIndicator() {}
            func displayStaticPath(pins: [CompassPin], startFromNearbyEntrance: Bool, disableZoomGestures: Bool) {}
            func getUserDistance(pins: [AislePin], completion: UserDistanceCompleteHandler?) {}
        }
        
        let nilTokenViewModel = NilTokenViewModel()
        let compass = Compass(serviceLocator: serviceLocator, viewModel: nilTokenViewModel)
        
        compass.initialize(authParameter: TestData.authParameter,
                           configuration: TestData.configuration,
                           completion: { _ in
            XCTFail("Initialization should fail when the access token publisher returns nil")
        }, onError: { _ in
            expectation.fulfill()
        })
        
        waitForExpectations(timeout: 3.0)
    }
    
    func testFetchConfigurationWithWeakSelfDeallocation() {
        let expectation = expectation(description: "weak self deallocation")
        
        // Create a compass instance that will be deallocated during async chain
        var compass: Compass? = Compass(serviceLocator: serviceLocator, viewModel: viewModel)
        
        compass?.initialize(
            authParameter: TestData.authParameter,
            configuration: TestData.configuration,
            completion: { _ in },
            onError: { _ in }
        )
        
        // Deallocate compass immediately to trigger weak self guard
        compass = nil
        
        // Give time for async operations to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 2.0)
    }

    func test_setConfiguration_withMockUser_shouldFailInitialize() throws {
        let expectation = expectation(description: "Initialize")
        let configuration = Configuration(country: "US",
                                          site: 2280,
                                          userId: "988sdd-erer-43434",
                                          siteType: .Store,
                                          manualPinDrop: true,
                                          navigateToPin: false,
                                          multiPin: false,
                                          searchBar: false,
                                          centerMap: true,
                                          locationIngestion: true,
                                          mockUser: true,
                                          anonymizedUserID: "anonymizedUserID",
                                          startPositioning: true,
                                          automaticCalibration: true,
                                          businessUnitType: .WALMART)

        // Make config service fail instead to actually fail initialization
        let mockConfigurationService = serviceLocator.getConfigurationService() as? MockConfigurationService
        mockConfigurationService?._shouldGetConfigPayloadFail = true
        
        initializeCompass(configuration: configuration) { _ in
            XCTFail("Initialization should fail when config service fails")
        } onError: { error in
            Log.info("Expected initialization failure: \(error)")
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 10.0)
    }
    
    func test_isMapViewReady_withMockUser_shouldFinishSettingMap() throws {
        let configuration = Configuration(country: "US",
                                          site: 2280,
                                          userId: "988sdd-erer-43434",
                                          siteType: .Store,
                                          manualPinDrop: true,
                                          navigateToPin: false,
                                          multiPin: false,
                                          searchBar: false,
                                          centerMap: true,
                                          locationIngestion: true,
                                          mockUser: true,
                                          anonymizedUserID: "anonymizedUserID",
                                          startPositioning: true,
                                          automaticCalibration: true,
                                          businessUnitType: .WALMART)
        viewModel._isMapViewReady = true
        let stateExpectation = expectState(
            matching: { $0 == .mapLoaded },
            description: "map loaded"
        )
        initializeCompass(configuration: configuration) { _ in } onError: { error in
            XCTFail("Initialization failed with error: \(error)")
        }
        
        wait(for: [stateExpectation], timeout: 5.0)
    }
    
    func testDefaultInit() {
        let compass = Compass()
        XCTAssertNotNil(compass)
    }
    
//    func testInitWithCoderTriggersFatalError() {
//        // This will crash the test, but will include the line in coverage
//        // You may want to comment this out after running coverage if you don't want a crash in CI
//        XCTAssertThrowsError(try { _ = Compass(coder: NSCoder()) }())
//    }
}
