//
//  MockServiceLocator.swift
//  compass_sdk_iosTests
//
//  Created by Young Jin Ju on 11/15/23.
//

import CoreData
import Combine
@testable import compass_sdk_ios
import IPSFramework

class MockServiceLocator: ServiceLocatorType, TestMockable {
    var _shouldFail: Bool = false
    var locationPermissionService: MockLocationPermissionService?
    var networkMonitorService: MockNetworkMonitorService?
    var indoorPositioningService: MockIndoorPositioningService?
    var indoorNavigationService: MockIndoorNavigationService?
    var mapFocusManager: MockMapFocusManager?
    var statusService: StatusService?
    var eventService: MockEventService?
    var assetService: MockAssetService?
    var eventStoreService: MockEventStoreService?
    var configurationStoreService: MockConfigurationStoreService?
    var configurationService: MockConfigurationService?
    var logEventStoreService: MockLogEventStoreService?
    var logDefault: MockLogDefaultImpl?
    var userPositionManager: MockUserPositionManager?
    var networkService: MockNetworkService?
    var storeMapViewModel: MockStoreMapLoaderViewModel?
    var compassViewModel: MockCompassViewModel?
    var messageSender: MockMessageSender?
    var messageParser: MockMessageParser?
    var staticPathPreviewService: StaticPathPreviewService?

    func _resetMock() {
        assetService?._resetMock()
        networkService?._resetMock()
        indoorNavigationService?._resetMock()
        indoorPositioningService?._resetMock()
        locationPermissionService?._resetMock()
        configurationService?._resetMock()
        eventService?._resetMock()
        logEventStoreService?._resetMock()
        eventStoreService?._resetMock()
        storeMapViewModel?._resetMock()
//        indoorMapViewModel?._resetMock()
        networkMonitorService?._resetMock()
        messageParser?._resetMock()
        messageSender?._resetMock()
        mapFocusManager?._resetMock()
        configurationStoreService?._resetMock()
        userPositionManager?._resetMock()
        (staticPathPreviewService as? MockStaticPathPreviewService)?._resetMock()
        _shouldFail = false
        MockIPSPositioning._resetMock()
        MockPositioningCore._resetMock()
    }
    
    var context: NSManagedObjectContext
    var _getStatusServiceCalled = false
    
    internal static var _shared: ServiceLocatorType = MockServiceLocator()
    static var shared: ServiceLocatorType {
        get { return _shared }
    }

    init() {
        let description = NSPersistentStoreDescription(
            url: URL(fileURLWithPath: "/dev/null")
        )
        description.type = NSSQLiteStoreType
        let container = NSPersistentContainer(
            name: "unite_test_container",
            managedObjectModel: NSManagedObjectModel.mergedModel(
                from: [Bundle(identifier: BundleIds.compassSDK)!]
            )!
        )
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        context = container.viewContext
    }

    func getLocationPermissionService() -> LocationPermissionService {
        guard let locationPermissionService = self.locationPermissionService else {
            self.locationPermissionService = MockLocationPermissionService()
            return getLocationPermissionService()
        }

        return locationPermissionService
    }

    func getNetworkMonitorService() -> NetworkMonitorService {
        guard let networkMonitorService = self.networkMonitorService else {
            self.networkMonitorService = MockNetworkMonitorService()
            return getNetworkMonitorService()
        }

        return networkMonitorService
    }
    
    func getIndoorPositioningService() -> IndoorPositioningService {
        guard let indoorPositioningService = self.indoorPositioningService else {
            self.indoorPositioningService = MockIndoorPositioningService()
            return getIndoorPositioningService()
        }

        return indoorPositioningService
    }

    func getIndoorNavigationService() -> IndoorNavigationService {
        guard let indoorNavigationService = self.indoorNavigationService else {
            self.indoorNavigationService = MockIndoorNavigationService()
            return getIndoorNavigationService()
        }
        return indoorNavigationService
    }

    func getStaticPathPreviewService() -> StaticPathPreviewService {
        guard let staticPathPreviewService = self.staticPathPreviewService else {
            self.staticPathPreviewService = MockStaticPathPreviewService()
            return getStaticPathPreviewService()
        }
        return staticPathPreviewService
    }
    
    func getMapFocusManager() -> MapFocusManager {
        guard let mapFocusManager = self.mapFocusManager else {
            self.mapFocusManager = MockMapFocusManager()
            return getMapFocusManager()
        }

        return mapFocusManager
    }

    func getStatusService() -> StatusService {
        _getStatusServiceCalled = true
        guard let statusService = self.statusService else {
            self.statusService = StatusServiceImpl()
            return getStatusService()
        }

        return statusService
    }

    func getEventService() -> EventService {
        guard let eventService = self.eventService else {
            self.eventService = MockEventService()
            return getEventService()
        }

        return eventService
    }

    func getAssetService() -> AssetService {
        guard let assetService = self.assetService else {
            self.assetService = MockAssetService()
            return getAssetService()
        }

        return assetService
    }

    func getEventStoreService() -> EventStoreService {
        guard let eventStoreService = self.eventStoreService else {
            self.eventStoreService = MockEventStoreService()
            return getEventStoreService()
        }

        return eventStoreService
    }
    
    func getConfigurationStoreService() -> ConfigurationStoreService {
        guard let configurationStoreService = self.configurationStoreService else {
            self.configurationStoreService = MockConfigurationStoreService()
            return getConfigurationStoreService()
        }

        return configurationStoreService
    }

    func getConfigurationService() -> ConfigurationService {
        guard let configurationService = self.configurationService else {
            self.configurationService = MockConfigurationService()
            return getConfigurationService()
        }

        return configurationService
    }

    func getLogEventStoreService() -> LogEventStoreService {
        guard let logEventStoreService = self.logEventStoreService else {
            self.logEventStoreService = MockLogEventStoreService(context: context)
            return getLogEventStoreService()
        }

        return logEventStoreService
    }

    func getLogDefaultImpl() -> LogDefault {
        guard let logDefault = self.logDefault else {
            self.logDefault = MockLogDefaultImpl(logEventStoreService: getLogEventStoreService(),
                                                 networkService: MockNetworkService(urlSession: MockURLSession()))
            self.logDefault?.startTimer(coolOffPeriod: 1)
            return getLogDefaultImpl()
        }

        return logDefault
    }

    func getUserPositionManager() -> any UserPositionManagement {
        guard let userPositionManager else {
            self.userPositionManager = MockUserPositionManager(serviceLocator: self)
            return getUserPositionManager()
        }

        return userPositionManager
    }

    func getNetworkService() -> any NetworkServiceType {
        guard let networkService else {
            self.networkService = MockNetworkService(urlSession: MockURLSession())
            return getNetworkService()
        }

        return networkService
    }

    func getStoreMapViewModel(blueDotMode: BlueDotMode,
                              storeMapOptions: StoreMapView.Options,
                              debugLog: DebugLog?) -> StoreMapViewActionable {
        guard let storeMapViewModel = self.storeMapViewModel else {
            self.storeMapViewModel = MockStoreMapLoaderViewModel(
                blueDotMode: blueDotMode,
                serviceLocator: self
            )
            return getStoreMapViewModel(blueDotMode: blueDotMode, storeMapOptions: storeMapOptions, debugLog: debugLog)
        }
        return storeMapViewModel
    }

    func getWebViewMessageSender() -> any MessageSending {
        guard let messageSender else {
            self.messageSender = MockMessageSender()
            return getWebViewMessageSender()
        }

        return messageSender
    }

    func getWebViewMessageParser() -> any compass_sdk_ios.MessageParsing {
        guard let messageParser else {
            self.messageParser = MockMessageParser()
            return getWebViewMessageParser()
        }

        return messageParser
    }

    func getCompassViewModel() -> any CompassViewModelType {
        guard let compassViewModel else {
            self.compassViewModel = MockCompassViewModel()
            return getCompassViewModel()
        }

        return compassViewModel

    }

    func registerStoreMapsViewController(_ vc: StoreMapsViewController?) {}

    func getRegisteredStoreMapsViewController() -> StoreMapsViewController? {
        nil
    }

    func destroy() {
        locationPermissionService = nil
        networkMonitorService = nil
        indoorPositioningService = nil
        indoorNavigationService = nil
        mapFocusManager = nil
        statusService = nil
        eventService = nil
        assetService = nil
        eventStoreService = nil
        configurationStoreService = nil
        configurationService = nil
        logDefault = nil
        logEventStoreService = nil
        userPositionManager = nil
        networkService = nil
        storeMapViewModel = nil
        messageSender = nil
        Log.debug("CompassSDK: remove shared services instances")
    }
}

class MockStaticPathPreviewService: StaticPathPreviewService, TestMockable {
    var previewWaypoints: [Waypoint] = []
    var startFromNearbyEntrance: Bool = false
    var route = CurrentValueSubject<IPSRoute?, Never>(nil)
    var addWaypointCalled = false
    var handleRouteUpdateCalled = false

    func _resetMock() {
        previewWaypoints = []
        startFromNearbyEntrance = false
        route.send(nil)
        addWaypointCalled = false
        handleRouteUpdateCalled = false
    }

    func setBuilding(_ building: IPSBuilding?) {}
    func addWaypoint(coordinate: CGPoint, floorSelected floor: Int, shouldFetchRoute: Bool) {
        addWaypointCalled = true
        previewWaypoints.append(Waypoint(id: "test", coordinate: coordinate, buildingId: "test", floorOrder: floor))
    }
    func handleRouteUpdate(assetService: AssetService, indoorPositioningService: IndoorPositioningService, setPathfindingEnabled: @escaping (Bool) -> Void, updateCustomRoute: @escaping ([Coord]) -> Void) -> AnyCancellable {
        handleRouteUpdateCalled = true
        return AnyCancellable {}
    }
}
