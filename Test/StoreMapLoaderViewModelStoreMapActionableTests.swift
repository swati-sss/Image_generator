import XCTest
import Combine
import IPSFramework
@testable import compass_sdk_ios

final class StoreMapLoaderViewModelStoreMapActionableTests: XCTestCase {
    private var serviceLocator: MockServiceLocator!
    private var storeMapLoaderViewModel: StoreMapLoaderViewModel!
    private var mockMessageSender: MockMessageSender!
    private var mapViewDelegate: MockMapViewDelegate!

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
        let workflow = Workflow(id: "test_actionable", type: "actionable_flow", value: "test_val")
        Analytics.workflow = workflow
        serviceLocator = MockServiceLocator()
        mockMessageSender = serviceLocator.getWebViewMessageSender() as? MockMessageSender
        mapViewDelegate = MockMapViewDelegate()
        let options = makeStoreMapOptions()
        storeMapLoaderViewModel = StoreMapLoaderViewModel(
            blueDotMode: .visible,
            storeMapOptions: options,
            debugLog: options.debugLog,
            serviceLocator: serviceLocator
        )
        storeMapLoaderViewModel.mapViewDelegate = mapViewDelegate
    }

    override func tearDownWithError() throws {
        mockMessageSender.sentMessages = []
        serviceLocator._resetMock()
        storeMapLoaderViewModel = nil
        serviceLocator = nil
        mockMessageSender = nil
        mapViewDelegate = nil
        Analytics.logDefault = nil
        try super.tearDownWithError()
    }

    // MARK: - updateStaticPathRoute Tests

    func testUpdateStaticPathRoute_WhenCoordinatesNil_ShouldReturnEarly() {
        // Arrange
        let coordinates: [Point]? = nil
        let staticPathService = storeMapLoaderViewModel.staticPathPreviewService
        let initialWaypointCount = (staticPathService as? MockStaticPathPreviewService)?.previewWaypoints.count ?? 0
        
        // Act
        storeMapLoaderViewModel.updateStaticPathRoute(with: coordinates)
        
        // Assert
        let finalWaypointCount = (staticPathService as? MockStaticPathPreviewService)?.previewWaypoints.count ?? 0
        XCTAssertEqual(initialWaypointCount, finalWaypointCount, "Should not add waypoints when coordinates are nil")
    }

    func testUpdateStaticPathRoute_WhenCoordinatesEmpty_ShouldReturnEarly() {
        // Arrange
        let coordinates: [Point] = []
        let staticPathService = storeMapLoaderViewModel.staticPathPreviewService
        let initialWaypointCount = (staticPathService as? MockStaticPathPreviewService)?.previewWaypoints.count ?? 0
        
        // Act
        storeMapLoaderViewModel.updateStaticPathRoute(with: coordinates)
        
        // Assert
        let finalWaypointCount = (staticPathService as? MockStaticPathPreviewService)?.previewWaypoints.count ?? 0
        XCTAssertEqual(initialWaypointCount, finalWaypointCount, "Should not add waypoints when coordinates are empty")
    }

    func testUpdateStaticPathRoute_WhenConverterNil_ShouldReturnEarly() {
        // Arrange
        let coordinates = [Point(x: 100, y: 200), Point(x: 150, y: 250)]
        (storeMapLoaderViewModel.indoorPositioningService as? MockIndoorPositioningService)?.floorCoordinatesConverter = nil
        let staticPathService = storeMapLoaderViewModel.staticPathPreviewService
        let initialWaypointCount = (staticPathService as? MockStaticPathPreviewService)?.previewWaypoints.count ?? 0
        
        // Act
        storeMapLoaderViewModel.updateStaticPathRoute(with: coordinates)
        
        // Assert
        let finalWaypointCount = (staticPathService as? MockStaticPathPreviewService)?.previewWaypoints.count ?? 0
        XCTAssertEqual(initialWaypointCount, finalWaypointCount, "Should not add waypoints when converter is nil")
    }

    func testUpdateStaticPathRoute_WithValidCoordinates_ShouldAddWaypoints() {
        // Arrange
        let coordinates = [Point(x: 100, y: 200), Point(x: 150, y: 250)]
        let staticPathService = storeMapLoaderViewModel.staticPathPreviewService as! MockStaticPathPreviewService
        staticPathService._resetMock()

        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.floorCoordinatesConverter = MockFloorCoordinatesConverterImpl()


        // Act
        storeMapLoaderViewModel.updateStaticPathRoute(with: coordinates)
        
        // Assert
        XCTAssertEqual(staticPathService.previewWaypoints.count, coordinates.count, "Should add waypoints for each coordinate")
    }

    func testUpdateStaticPathRoute_WithSingleCoordinate_ShouldProcessSuccessfully() {
        // Arrange
        let coordinates = [Point(x: 100, y: 200)]
        let staticPathService = storeMapLoaderViewModel.staticPathPreviewService as! MockStaticPathPreviewService
        staticPathService._resetMock()
        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.floorCoordinatesConverter = MockFloorCoordinatesConverterImpl()
        
        // Act
        storeMapLoaderViewModel.updateStaticPathRoute(with: coordinates)
        
        // Assert
        XCTAssertEqual(staticPathService.previewWaypoints.count, 1, "Should process single coordinate")
    }

    func testUpdateStaticPathRoute_WithMultipleCoordinates_ShouldProcessAllCoordinates() {
        // Arrange
        let coordinates = [
            Point(x: 100, y: 200),
            Point(x: 150, y: 250),
            Point(x: 200, y: 300),
            Point(x: 250, y: 350)
        ]
        let staticPathService = storeMapLoaderViewModel.staticPathPreviewService as! MockStaticPathPreviewService
        staticPathService._resetMock()
        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.floorCoordinatesConverter = MockFloorCoordinatesConverterImpl()
        
        // Act
        storeMapLoaderViewModel.updateStaticPathRoute(with: coordinates)
        
        // Assert
        XCTAssertEqual(staticPathService.previewWaypoints.count, 4, "Should process all coordinates")
    }

    func testUpdateStaticPathRoute_WithNegativeCoordinates_ShouldProcessSuccessfully() {
        // Arrange
        let coordinates = [
            Point(x: -100, y: -200),
            Point(x: 150, y: -250),
            Point(x: -50, y: 100)
        ]
        let staticPathService = storeMapLoaderViewModel.staticPathPreviewService as! MockStaticPathPreviewService
        staticPathService._resetMock()
        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.floorCoordinatesConverter = MockFloorCoordinatesConverterImpl()
        
        // Act
        storeMapLoaderViewModel.updateStaticPathRoute(with: coordinates)
        
        // Assert
        XCTAssertEqual(staticPathService.previewWaypoints.count, 3, "Should handle negative coordinate values")
    }

    func testUpdateStaticPathRoute_WithLargeCoordinates_ShouldProcessSuccessfully() {
        // Arrange
        let coordinates = [
            Point(x: 10000, y: 20000),
            Point(x: 15000, y: 25000)
        ]
        let staticPathService = storeMapLoaderViewModel.staticPathPreviewService as! MockStaticPathPreviewService
        staticPathService._resetMock()

        (serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService)?.floorCoordinatesConverter = MockFloorCoordinatesConverterImpl()

        // Act
        storeMapLoaderViewModel.updateStaticPathRoute(with: coordinates)
        
        // Assert
        XCTAssertEqual(staticPathService.previewWaypoints.count, 2, "Should handle large coordinate values")
    }


    // MARK: - updateCustomRoute Tests

    func testUpdateCustomRoute_WhenDistanceIsNaN_ShouldSendRequest() {
        // Arrange
        let coords = [Coord(x: 100, y: 200), Coord(x: 150, y: 250)]
        let distance = Double.nan
        mockMessageSender.sentMessages = []
        
        // Act
        storeMapLoaderViewModel.updateCustomRoute(coords: coords, distance: distance)
        
        // Assert
        XCTAssertTrue(mockMessageSender.sentMessages.contains { message in
            if case .customRoute = message {
                return true
            }
            return false
        }, "Should send custom route request when distance is NaN")
    }

    func testUpdateCustomRoute_WhenNavigationEnabledAndValidDistance_ShouldSendRequest() {
        // Arrange
        let coords = [Coord(x: 100, y: 200), Coord(x: 150, y: 250)]
        let distance = 50.0
        mockMessageSender.sentMessages = []
        
        // Act
        storeMapLoaderViewModel.updateCustomRoute(coords: coords, distance: distance)
        
        // Assert
        XCTAssertTrue(mockMessageSender.sentMessages.contains { message in
            if case .customRoute = message {
                return true
            }
            return false
        }, "Should send custom route request when navigation is enabled")
    }

    func testUpdateCustomRoute_WhenNavigationDisabledAndDistanceNotNaN_ShouldNotSendRequest() {
        // Arrange
        let options = makeStoreMapOptions(navigationEnabled: false)
        let viewModel = StoreMapLoaderViewModel(
            blueDotMode: .visible,
            storeMapOptions: options,
            debugLog: options.debugLog,
            serviceLocator: serviceLocator
        )
        let coords = [Coord(x: 100, y: 200)]
        let distance = 50.0
        mockMessageSender.sentMessages = []
        
        // Act
        viewModel.updateCustomRoute(coords: coords, distance: distance)
        
        // Assert
        let customRouteMessages = mockMessageSender.sentMessages.filter { message in
            if case .customRoute = message {
                return true
            }
            return false
        }
        XCTAssertEqual(customRouteMessages.count, 0, "Should not send request when navigation disabled and distance valid")
    }

    func testUpdateCustomRoute_WithSingleCoordinate_ShouldSendRequest() {
        // Arrange
        let coords = [Coord(x: 100, y: 200)]
        let distance = 25.0
        mockMessageSender.sentMessages = []
        
        // Act
        storeMapLoaderViewModel.updateCustomRoute(coords: coords, distance: distance)
        
        // Assert
        XCTAssertTrue(mockMessageSender.sentMessages.contains { message in
            if case .customRoute = message {
                return true
            }
            return false
        }, "Should send request with single coordinate")
    }

    func testUpdateCustomRoute_WithMultipleCoordinates_ShouldSendRequest() {
        // Arrange
        let coords = [
            Coord(x: 100, y: 200),
            Coord(x: 150, y: 250),
            Coord(x: 200, y: 300)
        ]
        let distance = 100.0
        mockMessageSender.sentMessages = []
        
        // Act
        storeMapLoaderViewModel.updateCustomRoute(coords: coords, distance: distance)
        
        // Assert
        XCTAssertTrue(mockMessageSender.sentMessages.contains { message in
            if case .customRoute = message {
                return true
            }
            return false
        }, "Should send request with multiple coordinates")
    }

    func testUpdateCustomRoute_WithZeroDistance_ShouldSendRequest() {
        // Arrange
        let coords = [Coord(x: 100, y: 200)]
        let distance = 0.0
        mockMessageSender.sentMessages = []
        
        // Act
        storeMapLoaderViewModel.updateCustomRoute(coords: coords, distance: distance)
        
        // Assert
        XCTAssertTrue(mockMessageSender.sentMessages.contains { message in
            if case .customRoute = message {
                return true
            }
            return false
        }, "Should send request with zero distance")
    }

    func testUpdateCustomRoute_WithNegativeDistance_ShouldSendRequest() {
        // Arrange
        let coords = [Coord(x: 100, y: 200)]
        let distance = -50.0
        mockMessageSender.sentMessages = []
        
        // Act
        storeMapLoaderViewModel.updateCustomRoute(coords: coords, distance: distance)
        
        // Assert
        XCTAssertTrue(mockMessageSender.sentMessages.contains { message in
            if case .customRoute = message {
                return true
            }
            return false
        }, "Should send request with negative distance")
    }

    func testUpdateCustomRoute_WhenStaticPathVisibleUseBluedotFalse() {
        // Arrange
        storeMapLoaderViewModel.isStaticPathVisible = true
        let coords = [Coord(x: 100, y: 200)]
        let distance = Double.nan
        mockMessageSender.sentMessages = []
        
        // Act
        storeMapLoaderViewModel.updateCustomRoute(coords: coords, distance: distance)
        
        // Assert
        XCTAssertTrue(mockMessageSender.sentMessages.contains { message in
            if case .customRoute(let request) = message {
                return request.useBluedot == false
            }
            return false
        }, "Should have useBluedot=false when static path visible")
    }

    func testUpdateCustomRoute_WhenStaticPathNotVisibleUseBluedotTrue() {
        // Arrange
        storeMapLoaderViewModel.isStaticPathVisible = false
        let coords = [Coord(x: 100, y: 200)]
        let distance = Double.nan
        mockMessageSender.sentMessages = []
        
        // Act
        storeMapLoaderViewModel.updateCustomRoute(coords: coords, distance: distance)
        
        // Assert
        XCTAssertTrue(mockMessageSender.sentMessages.contains { message in
            if case .customRoute(let request) = message {
                return request.useBluedot == true
            }
            return false
        }, "Should have useBluedot=true when static path not visible")
    }

}
