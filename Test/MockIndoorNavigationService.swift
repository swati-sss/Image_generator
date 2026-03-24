//
//  MockIndoorNavigationService.swift
//  compass_sdk_iosTests
//
//  Created by Young Jin Ju - Vendor on 5/27/23.
//

import Combine

@testable import compass_sdk_ios
import IPSFramework

class MockIPSRoute: NSObject, IPSRoute {
    var routeCoordinates: [any IPSFramework.IPSCoordinateInBuilding] = []
    var waypoints: [any IPSFramework.IPSWaypoint] = []
    var floorTransitions: [any IPSFramework.IPSRouteFloorTransition] = [MockIPSRouteFloorTransition(), MockIPSRouteFloorTransition(id: "2")]
    var nextTurn: (any IPSFramework.IPSTurn)?
    
    func distanceFromStart(to waypoint: any IPSFramework.IPSWaypoint) -> CGFloat {
        return 9
    }
    
    func isWaypointOnRoute(_ waypoint: any IPSFramework.IPSWaypoint) -> Bool {
        return false
    }
    
    func indexOnRoute(of waypoint: any IPSFramework.IPSWaypoint) -> Int {
        return 0
    }
    
    func distanceFromStartToFloorTransition(_ floorTransition: any IPSFramework.IPSRouteFloorTransition) -> CGFloat {
        return 8
    }
    
    func isFloorTransitionOnRoute(_ floorTransition: any IPSFramework.IPSRouteFloorTransition) -> Bool {
        return false
    }
}

class MockIPSWaypoint: IPSWaypoint {
    var id: String
    var buildingId: String
    var floorOrder: Int
    var x: CGFloat
    var y: CGFloat
    var z: CGFloat
    
    init(id: String = "7", buildingId: String = "buildingId of WayPoint", floorOrder: Int = 1, x: CGFloat = 100, y: CGFloat = 200, z: CGFloat = 300) {
        self.id = id
        self.buildingId = buildingId
        self.floorOrder = floorOrder
        self.x = x
        self.y = y
        self.z = z
    }
}

class MockIPSRouteFloorTransition: IPSFramework.IPSRouteFloorTransition {
    var type: IPSFramework.IPSFloorTransitionType
    var id: String
    var indexOnRoute: Int
    var destinationFloorOrder: Int
    var destinationCoordinate: any IPSFramework.IPSCoordinateInBuilding { self }
    var buildingId: String
    var floorOrder: Int
    var x: CGFloat
    var y: CGFloat
    var z: CGFloat
    
    init(type: IPSFramework.IPSFloorTransitionType = .escalator, id: String = "1", indexOnRoute: Int = 1, destinationFloorOrder: Int = 2, buildingId: String = "buildingId", floorOrder: Int = 1, x: CGFloat = 100, y: CGFloat = 200, z: CGFloat = 300) {
        self.type = type
        self.id = id
        self.indexOnRoute = indexOnRoute
        self.destinationFloorOrder = destinationFloorOrder
        self.buildingId = buildingId
        self.floorOrder = floorOrder
        self.x = x
        self.y = y
        self.z = z
    }
}

class MockIndoorNavigationService: IndoorNavigationService, TestMockable {
    func fetchRoute(_ isPinChanged: Bool) {
        
    }

    var navigationConfig: NavigationConfig?
    var delegate: IndoorNavigationServiceDelegate?
    var route = CurrentValueSubject<IPSFramework.IPSRoute?, Never>(MockIPSRoute())
    var waypoints: [Waypoint] = [
        Waypoint(id: "wp1", coordinate: CGPoint(x: 10, y: 20), buildingId: "building1", floorOrder: 1),
        Waypoint(id: "wp2", coordinate: CGPoint(x: 30, y: 40), buildingId: "building1", floorOrder: 1)
    ]
    var currentLocationWaypoint: Waypoint? = Waypoint(id: "current", coordinate: CGPoint(x: 0, y: 0), buildingId: "building1", floorOrder: 1)
    var navigationSessionState: NavigationSessionState? = NavigationSessionState(
        currentLocationWaypoint: Waypoint(id: "current", coordinate: CGPoint(x: 0, y: 0), buildingId: "building1", floorOrder: 1),
        destinationWaypoints: [
            Waypoint(id: "pin1", coordinate: CGPoint(x: 50, y: 60), buildingId: "building1", floorOrder: 1)
        ],
        pinList: PinList(pins: [
            DrawPin(
                type: PinIdentifier.xyPinLocation.rawValue,
                x: 50,
                y: 60,
                location: Point(x: 50, y: 60),
                errorData: nil
            )
        ]),
        navigationStatus: .inProgress,
        lastNavigationStatus: .notStarted
    )
    var pinLocationWaypoint: [Waypoint]? = []
    var _isAddCalled: Bool = false
    var _building: IPSBuilding?
    var _stoppedNavigation = false
    var _isItemUsedInNavigation = false
    var _startNavigationCalled = false
    var _toggleNavigation = false
    var _handleNavigationInterruptionIfNeeded = false
    var _resetnavigationSessionState = false
    var _fetchRoute = false
    var _hasPinsOnMap = true

    func _resetMock() {
        _isAddCalled = false
        _building = nil
        _stoppedNavigation = false
        _isItemUsedInNavigation = false
        waypoints.removeAll()
    }

    func startNavigation() {
        _startNavigationCalled = true
    }

    func setBuilding(_ building: IPSFramework.IPSBuilding?) {
        _building = building
    }

    func add(waypoint: Waypoint) {
        waypoints.append(waypoint)
    }

    func addWaypoint(at index: Int, coordinate: CGPoint, floorSelected: Int) {
        guard let building = _building else {
            return
        }

        let waypoint = Waypoint(
            id: UUID().uuidString,
            coordinate: coordinate,
            buildingId: building.id,
            floorOrder: floorSelected
        )

        if index == 0 {
            currentLocationWaypoint = waypoint
        } else {
            pinLocationWaypoint?.append(waypoint)
        }

        Log.debug(
            """
            [Navigation] currentLocationWaypoint: \(String(describing: currentLocationWaypoint.debugDescription)) and
            pinLocationWaypoint: \(String(describing: pinLocationWaypoint?.debugDescription))
            """
        )
    }

    var _updateNavigationStateCalled = false
    var _resetWaypointsCalled = false
    var _resetWaypointsParams: (shouldClearBlueDot: Bool, shouldClearPinList: Bool)?
    var _resetNavigationSessionStateCalled = false

    func updateNavigationState(currentLocation: Waypoint?, pinWaypoint: Waypoint?, renderRequest: RenderPinsRequest?, pinListUpdate: PinList?) {
        _updateNavigationStateCalled = true
    }

    func resetWaypoints(shouldClearBlueDot: Bool, shouldClearPinList: Bool) {
        _resetWaypointsCalled = true
        _resetWaypointsParams = (shouldClearBlueDot, shouldClearPinList)
        if shouldClearBlueDot {
            navigationSessionState?.currentLocationWaypoint = nil
        }

        if shouldClearPinList {
            let isInProgress = navigationSessionState?.navigationStatus == .inProgress
            let wasInProgress = navigationSessionState?.lastNavigationStatus == .inProgress

            if isInProgress, wasInProgress {
                navigationSessionState?.navigationStatus = .interrupted
                route.value = nil
            }

            if let currentStatus = navigationSessionState?.navigationStatus {
                navigationSessionState?.lastNavigationStatus = currentStatus
            }

            navigationSessionState?.destinationWaypoints = []
        }
    }

    func areNavigationRequiredPointsAvailable() -> Bool {
        let isWaypointsPresent = (navigationSessionState?.currentLocationWaypoint != nil) &&
            !(navigationSessionState?.destinationWaypoints?.isEmpty ?? true)
        return isWaypointsPresent
    }


    func remove(waypointId: String) {
        waypoints.removeAll(where: { $0.id == waypointId })
    }

    func stopNavigation() {
        _stoppedNavigation = true
    }

    func isUsedInNavigation(itemId: String) -> Bool {
        _isItemUsedInNavigation
    }

    func toggleNavigation(enabled: inout Bool) -> Bool {
        enabled = !enabled
        _toggleNavigation = enabled
        return true
    }

    func handleRouteUpdate(assetService: any AssetService, indoorPositioningService: any IndoorPositioningService, setPathfindingEnabled: @escaping (Bool) -> Void, updateCustomRoute: @escaping ([Coord], Double) -> Void) -> AnyCancellable {
        return AnyCancellable {}
    }

    func handleNavigationInterruptionIfNeeded() {
        _handleNavigationInterruptionIfNeeded = true
    }

    func resetnavigationSessionState() {
        _resetNavigationSessionStateCalled = true
        _resetnavigationSessionState = true
    }

    func fetchRoute() {
        _fetchRoute = true
    }

    func hasPinsOnMap() -> Bool {
        _hasPinsOnMap
    }

    func resetNavigationSessionState() {
        _resetNavigationSessionStateCalled = true
    }
}
