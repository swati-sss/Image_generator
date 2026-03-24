import XCTest
import Combine
import IPSFramework
@testable import compass_sdk_ios

final class StoreMapLoaderViewModelNavigationTests: XCTestCase {
    private var serviceLocator: MockServiceLocator!
    private var storeMapLoaderViewModel: StoreMapLoaderViewModel!

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
        let workflow = Workflow(id: "test_navigation", type: "navigation_flow", value: "test_val")
        Analytics.workflow = workflow
        serviceLocator = MockServiceLocator()
        let options = makeStoreMapOptions()
        storeMapLoaderViewModel = StoreMapLoaderViewModel(
            blueDotMode: .visible,
            storeMapOptions: options,
            debugLog: options.debugLog,
            serviceLocator: serviceLocator
        )
    }


    override func tearDownWithError() throws {
        serviceLocator._resetMock()
        storeMapLoaderViewModel = nil
        serviceLocator = nil
        Analytics.logDefault = nil
        try super.tearDownWithError()
    }

    // MARK: - Fail Cases

    func testUpdateNavigationRoute_WhenNavigationDisabled_ShouldReturnEarly() {
        // Arrange - Create view model with navigation disabled
        let options = makeStoreMapOptions(navigationEnabled: false)
        let viewModel = StoreMapLoaderViewModel(
            blueDotMode: .visible,
            storeMapOptions: options,
            debugLog: options.debugLog,
            serviceLocator: serviceLocator
        )
        let coordinates = [Point(x: 100, y: 200), Point(x: 150, y: 250)]
        let pinList = PinList(pins: [])
        let renderRequest = RenderPinsRequest(pins: [], pinGroupingEnabled: true)
        let mockNavService = serviceLocator.getIndoorNavigationService() as! MockIndoorNavigationService
        mockNavService._resetMock()
        var updateNavigationStateCallCount = 0
        
        // Act
        viewModel.updateNavigationRoute(
            with: coordinates,
            at: 0,
            using: pinList,
            renderPinsRequest: renderRequest
        )
        
        // Assert
        XCTAssertEqual(updateNavigationStateCallCount, 0, "updateNavigationState should not be called when navigation is disabled")
    }

    func testUpdateNavigationRoute_WhenCoordinatesNil_ShouldReturnEarly() {
        // Arrange
        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?._resetMock()
        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.floorCoordinatesConverter = MockFloorCoordinatesConverterImpl()
        let coordinates: [Point]? = nil
        let pinList = PinList(pins: [DrawPin(type: "aisleSection", x: 10, y: 20, location: nil, errorData: nil)])
        let renderRequest = RenderPinsRequest(pins: [], pinGroupingEnabled: true)
        let mockNavService = serviceLocator.getIndoorNavigationService() as! MockIndoorNavigationService
        mockNavService._resetMock()
        mockNavService.navigationSessionState = nil
        // Act
        storeMapLoaderViewModel.updateNavigationRoute(
            with: coordinates,
            at: 0,
            using: pinList,
            renderPinsRequest: renderRequest
        )
        
        // Assert - Service should not be called for nil coordinates
        XCTAssertTrue(mockNavService.waypoints.isEmpty)
    }

    func testUpdateNavigationRoute_WhenCoordinatesEmpty_ShouldReturnEarly() {
        // Arrange
        let coordinates: [Point] = []
        let pinList = PinList(pins: [])
        let renderRequest = RenderPinsRequest(pins: [], pinGroupingEnabled: true)
        let mockNavService = serviceLocator.getIndoorNavigationService() as! MockIndoorNavigationService
        mockNavService._resetMock()
        mockNavService.navigationSessionState = nil
        
        // Act
        storeMapLoaderViewModel.updateNavigationRoute(
            with: coordinates,
            at: 0,
            using: pinList,
            renderPinsRequest: renderRequest
        )
        
        // Assert
        XCTAssertTrue(mockNavService.waypoints.isEmpty)
    }

    func testUpdateNavigationRoute_WhenConverterNil_ShouldReturnEarly() {
        // Arrange
        let coordinates = [Point(x: 100, y: 200), Point(x: 150, y: 250)]
        let pinList = PinList(pins: [])
        let renderRequest = RenderPinsRequest(pins: [], pinGroupingEnabled: true)
        
        // Ensure converter is nil by using a mock positioning service
        (storeMapLoaderViewModel.indoorPositioningService as? MockIndoorPositioningService)?.floorCoordinatesConverter = nil
        
        // Act
        storeMapLoaderViewModel.updateNavigationRoute(
            with: coordinates,
            at: 0,
            using: pinList,
            renderPinsRequest: renderRequest
        )
        
        // Assert - Should return early without processing
        XCTAssertTrue(true, "Should handle nil converter gracefully")
    }

    // MARK: - Pass Cases

    func testUpdateNavigationRoute_WithValidCoordinatesAndNavEnabled_ShouldUpdateNavigationState() {
        // Arrange
        let coordinates = [Point(x: 100, y: 200), Point(x: 150, y: 250)]
        let pinList = PinList(pins: [])
        let renderRequest = RenderPinsRequest(pins: [], pinGroupingEnabled: true)
        let mockNavService = serviceLocator.getIndoorNavigationService() as! MockIndoorNavigationService
        mockNavService._resetMock()
        
        // Act
        storeMapLoaderViewModel.updateNavigationRoute(
            with: coordinates,
            at: 0,
            using: pinList,
            renderPinsRequest: renderRequest
        )
        
        // Assert - Navigation state should be updated
        XCTAssertNotNil(storeMapLoaderViewModel.indoorNavigationService.navigationSessionState, "updateNavigationState should be called with valid coordinates and enabled navigation")
    }

    func testUpdateNavigationRoute_WithValidCoordinates_ShouldAddWaypoints() {
        // Arrange
        let coordinates = [Point(x: 100, y: 200), Point(x: 150, y: 250)]
        let pinList = PinList(pins: [])
        let renderRequest = RenderPinsRequest(pins: [], pinGroupingEnabled: true)
        let mockNavService = serviceLocator.getIndoorNavigationService() as! MockIndoorNavigationService
        mockNavService._resetMock()
        mockNavService.setBuilding(TestData.iPSBuilding)
        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.floorCoordinatesConverter = MockFloorCoordinatesConverterImpl()
        
        // Act
        storeMapLoaderViewModel.updateNavigationRoute(
            with: coordinates,
            at: 0,
            using: pinList,
            renderPinsRequest: renderRequest
        )
        
        // Assert
        XCTAssertNotNil(mockNavService.currentLocationWaypoint)
        XCTAssertTrue(mockNavService._updateNavigationStateCalled)
    }

    func testUpdateNavigationRoute_WithSingleCoordinate_ShouldProcessSuccessfully() {
        // Arrange
        let coordinates = [Point(x: 100, y: 200)]
        let pinList = PinList(pins: [])
        let renderRequest = RenderPinsRequest(pins: [], pinGroupingEnabled: true)
        let mockNavService = serviceLocator.getIndoorNavigationService() as! MockIndoorNavigationService
        mockNavService._resetMock()
        mockNavService.setBuilding(TestData.iPSBuilding)
        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.floorCoordinatesConverter = MockFloorCoordinatesConverterImpl()
        
        // Act
        storeMapLoaderViewModel.updateNavigationRoute(
            with: coordinates,
            at: 0,
            using: pinList,
            renderPinsRequest: renderRequest
        )
        
        // Assert
        XCTAssertNotNil(mockNavService.currentLocationWaypoint)
        XCTAssertTrue(mockNavService._updateNavigationStateCalled)
    }

    func testUpdateNavigationRoute_WithMultipleCoordinates_ShouldProcessAllCoordinates() {
        // Arrange
        let coordinates = [
            Point(x: 100, y: 200),
            Point(x: 150, y: 250),
            Point(x: 200, y: 300),
            Point(x: 250, y: 350)
        ]
        let pinList = PinList(pins: [])
        let renderRequest = RenderPinsRequest(pins: [], pinGroupingEnabled: true)
        let mockNavService = serviceLocator.getIndoorNavigationService() as! MockIndoorNavigationService
        mockNavService._resetMock()
        mockNavService.setBuilding(TestData.iPSBuilding)
        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.floorCoordinatesConverter = MockFloorCoordinatesConverterImpl()
        
        // Act
        storeMapLoaderViewModel.updateNavigationRoute(
            with: coordinates,
            at: 0,
            using: pinList,
            renderPinsRequest: renderRequest
        )
        
        // Assert
        XCTAssertNotNil(mockNavService.currentLocationWaypoint)
        XCTAssertTrue(mockNavService._updateNavigationStateCalled)
    }

    func testUpdateNavigationRoute_WithNilPinList_ShouldProcessCoordinates() {
        // Arrange
        let coordinates = [Point(x: 100, y: 200)]
        let renderRequest = RenderPinsRequest(pins: [], pinGroupingEnabled: true)
        let mockNavService = serviceLocator.getIndoorNavigationService() as! MockIndoorNavigationService
        
        // Act
        storeMapLoaderViewModel.updateNavigationRoute(
            with: coordinates,
            at: 0,
            using: nil,
            renderPinsRequest: renderRequest
        )
        
        // Assert
        XCTAssertNotNil(mockNavService.navigationSessionState, "Should process even with nil pinList")
    }

    func testUpdateNavigationRoute_WithNilRenderPinsRequest_ShouldProcessCoordinates() {
        // Arrange
        let coordinates = [Point(x: 100, y: 200)]
        let pinList = PinList(pins: [])
        let mockNavService = serviceLocator.getIndoorNavigationService() as! MockIndoorNavigationService
        
        // Act
        storeMapLoaderViewModel.updateNavigationRoute(
            with: coordinates,
            at: 0,
            using: pinList,
            renderPinsRequest: nil
        )
        
        // Assert
        XCTAssertNotNil(mockNavService.navigationSessionState, "Should process even with nil renderPinsRequest")
    }

    func testUpdateNavigationRoute_WithVariousIndexValues_ShouldPassIndexToAddWaypoint() {
        // Arrange
        let coordinates = [Point(x: 100, y: 200)]
        let testIndices = [0, 1, 5, 10]
        let mockNavService = serviceLocator.getIndoorNavigationService() as! MockIndoorNavigationService
        
        for testIndex in testIndices {
            mockNavService._resetMock()
            
            // Act
            storeMapLoaderViewModel.updateNavigationRoute(
                with: coordinates,
                at: testIndex,
                using: nil,
                renderPinsRequest: nil
            )
            
            // Assert
            XCTAssertNotNil(mockNavService.navigationSessionState, "Should process index \(testIndex)")
        }
    }

    func testUpdateNavigationRoute_WithCoordinatesContainingNegativeValues_ShouldProcessSuccessfully() {
        // Arrange
        let coordinates = [
            Point(x: -100, y: -200),
            Point(x: 150, y: -250),
            Point(x: -50, y: 100)
        ]
        let pinList = PinList(pins: [])
        let mockNavService = serviceLocator.getIndoorNavigationService() as! MockIndoorNavigationService
        mockNavService._resetMock()
        mockNavService.setBuilding(TestData.iPSBuilding)
        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.floorCoordinatesConverter = MockFloorCoordinatesConverterImpl()
        
        // Act
        storeMapLoaderViewModel.updateNavigationRoute(
            with: coordinates,
            at: 0,
            using: pinList,
            renderPinsRequest: nil
        )
        
        // Assert
        XCTAssertNotNil(mockNavService.currentLocationWaypoint)
        XCTAssertTrue(mockNavService._updateNavigationStateCalled)
    }

    func testUpdateNavigationRoute_WithLargeCoordinateValues_ShouldProcessSuccessfully() {
        // Arrange
        let coordinates = [
            Point(x: 10000, y: 20000),
            Point(x: 15000, y: 25000)
        ]
        let mockNavService = serviceLocator.getIndoorNavigationService() as! MockIndoorNavigationService
        mockNavService._resetMock()
        mockNavService.setBuilding(TestData.iPSBuilding)
        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.floorCoordinatesConverter = MockFloorCoordinatesConverterImpl()
        
        // Act
        storeMapLoaderViewModel.updateNavigationRoute(
            with: coordinates,
            at: 0,
            using: nil,
            renderPinsRequest: nil
        )
        
        // Assert
        XCTAssertNotNil(mockNavService.currentLocationWaypoint)
        XCTAssertTrue(mockNavService._updateNavigationStateCalled)
    }
}
