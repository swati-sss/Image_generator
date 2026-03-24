//
//  StoreMapLoaderViewModel+StoreMapViewActionable.swift
//  compass_sdk_ios
//
//  Created by Rakesh Shetty on 6/4/25.
//

import Foundation
import IPSFramework

extension StoreMapLoaderViewModel: StoreMapViewActionable {
    // MARK: - Navigation State Helpers
    var isMapViewLoaded: Bool {
        hasLoadedMapView.value
    }

    var navigationSessionState: NavigationSessionState? {
        indoorNavigationService.navigationSessionState
    }

    var isNavigationActiveOrStopped: Bool {
        guard let status = navigationSessionState?.navigationStatus else { return false }
        return status == .inProgress || status == .stopped
    }

    var shouldSkipZoomOnLocation: Bool {
        isNavigationActiveOrStopped &&
        (mapViewDelegate?.isCenterButtonClicked == false)
    }

    var isNavigationInProgress: Bool {
        navigationSessionState?.navigationStatus == .inProgress
    }

    var shouldUpdateNavigationRoute: Bool {
        guard let navigationSessionState = navigationSessionState else { return false }
        let isCurrentLocationWaypointNil = navigationSessionState.currentLocationWaypoint == nil
        let isNewRouteNeeded = isCurrentLocationWaypointNil ||
        indoorNavigationService.areNavigationRequiredPointsAvailable()
        let isInProgress = isCurrentLocationWaypointNil || navigationSessionState.navigationStatus == .inProgress
        return navigationEnabled == true && isNewRouteNeeded && isInProgress
    }

    // MARK: - Navigation
    func setNavigation(enabled: inout Bool) -> Bool {
        return indoorNavigationService.toggleNavigation(enabled: &enabled)
    }

    func canDisplayNavigationButton() -> Bool {
        return indoorNavigationService.navigationSessionState?.hasPinsOnMap ?? false
    }

    /// Sets up navigation paths by observing changes in the route
    func setupNavigationPaths() {
        routeCancellable?.cancel()
        routeCancellable = indoorNavigationService.handleRouteUpdate(
            assetService: assetService,
            indoorPositioningService: indoorPositioningService,
            setPathfindingEnabled: { [weak self] enabled in
                guard let self, !isStaticPathVisible else { return }
                self.setPathfindingEnabled(enabled, duration: 0.2)
            },
            updateCustomRoute: { [weak self] coords, distance in
                guard let self, !isStaticPathVisible else { return }
                self.updateCustomRoute(coords: coords, distance: distance)
            }
        )
    }

    func updateNavigationRoute(with coordinates: [Point]?,
                               at index: Int,
                               using pinList: PinList?,
                               renderPinsRequest: RenderPinsRequest?) {
        Log.debug("[Navigation] enabled: \(String(describing: navigationEnabled)).")
        guard let navigationEnabled,
              navigationEnabled,
              let coordinates = coordinates,
              let first = coordinates.first,
              let converter = indoorPositioningService.floorCoordinatesConverter else {
            Log.debug("[Navigation] No coordinates found to add navigation route.")
            return
        }

        Log.debug("""
        [Navigation] Adding route coordinates (store map units): \(coordinates)
          - Index: \(index)
          - Floor selected: \(floorSelected)
          - Converting to Oriient units and requesting route API.
        """)

        self.indoorNavigationService.updateNavigationState(
            currentLocation: nil, pinWaypoint: nil,
            renderRequest: renderPinsRequest, pinListUpdate: pinList
        )

        coordinates.forEach {
            let transformedPoint = CGPoint(x: $0.x, y: $0.y)
                .storeMapToWasp(offset: assetService.storeConfigOffset)
                .convertToOriient(using: converter)
                .asCGPoint()

            let roundedPoint = CGPoint(
                x: transformedPoint.x.rounded(toDecimalPlaces: 1),
                y: transformedPoint.y.rounded(toDecimalPlaces: 1)
            )
            self.indoorNavigationService.addWaypoint(
                at: index, coordinate: roundedPoint, floorSelected: floorSelected
            )
        }
    }

    func updateStaticPathRoute(with coordinates: [Point]?) {
        guard let coordinates = coordinates,
              !coordinates.isEmpty,
              let converter = indoorPositioningService.floorCoordinatesConverter else {
            Log.debug("[DisplayStaticPath] No coordinates found to add navigation route.")
            return
        }

        Log.debug(
                """
                [DisplayStaticPath] Adding route coordinates (store map units): \(coordinates)
                  - Floor selected: \(floorSelected)
                  - Converting to Oriient units and requesting route API.
                """
        )

        coordinates.enumerated().forEach {
            let transformedPoint = CGPoint(x: $1.x, y: $1.y)
                .storeMapToWasp(offset: assetService.storeConfigOffset)
                .convertToOriient(using: converter)
                .asCGPoint()

            let roundedPoint = CGPoint(
                x: transformedPoint.x.rounded(toDecimalPlaces: 1),
                y: transformedPoint.y.rounded(toDecimalPlaces: 1)
            )
            self.staticPathPreviewService.addWaypoint(
                coordinate: roundedPoint,
                floorSelected: floorSelected,
                shouldFetchRoute: coordinates.count == $0+1
            )
        }
    }

    func setPathfindingEnabled(_ enabled: Bool, duration: TimeInterval = 0.0, force: Bool = false) {
        let performRequest = {
            self.request(.setPathfindingEnabled(SetPathFindingRequest(pathfinderEnabled: enabled)))
        }

        if force {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: performRequest)
            return
        }

        if isStaticPathVisible {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: performRequest)
            return
        }

        guard lastPathfindingEnabled != enabled,
              let navigationEnabled,
              navigationEnabled else {
            return
        }

        lastPathfindingEnabled = enabled
        Log.info("[Navigation or DisplayStaticPath] Set pathfinding enabled: \(enabled).")
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: performRequest)
    }

    func setPinSelectionEnabled(_ enabled: Bool) {
        Log.info("Set pinSelection enabled: \(enabled).")
        self.request(.setPinSelectionEnabled(SetPinSelectionRequest(pinSelectionEnabled: enabled)))
    }

    func updateCustomRoute(coords: [Coord], distance: Double) {
        let shouldRequest = distance.isNaN || (navigationEnabled ?? false)

        guard shouldRequest else { return }

        Log.info("[Navigation or DisplayStaticPath] Update custom route with coord: \(coords), distance: \(distance).")
        let navigationValidateCoordEnabled = debugLog?.navigationValidateCoordEnabled ?? false
        request(.customRoute(CustomRouteRequest(coords: coords,
                                                distance: distance,
                                                useBluedot: !isStaticPathVisible,
                                                navigationValidateCoordEnabled: navigationValidateCoordEnabled)))

        // Uncomment the above line to test navigation out of bounds response handling
        /*let testCords = [Coord(x: 59, y: 2046), Coord(x: 1506, y: 2046)]
        request(.customRoute(CustomRouteRequest(coords: testCords,
         distance: distance, useBluedot:
         !isStaticPathVisible,
         navigationValidateCoordEnabled: navigationValidateCoordEnabled)))*/
    }

    // MARK: - Pin Rendering
    func clearRenderedPin(mapConfig: MapConfig) {
        Log.debug("Clear pins")
        clearStaticPath()

        request(.renderXYLocationPinRequested(PinList(pins: [])))
        request(.renderPins(RenderPinsRequest(pins: [], pinGroupingEnabled: pinsConfig.groupPinsEnabled)))
        indoorNavigationService.resetWaypoints(shouldClearBlueDot: false, shouldClearPinList: true)
        indoorNavigationService.resetNavigationSessionState()
        mapViewDelegate?.handleNavigationInterruption(for: 1, status: navigationSessionState?.navigationStatus)

        if mapConfig.resetZoom {
            Log.debug("Reset Zoom level")
            showMapZoomedOut()
        }
    }

    /// Render pins on the map. Only sends the render request and updates config if provided.
    /// Navigation and route logic is handled in handlePinRenderedMessage after the response.
    func renderPins(_ renderPinsRequest: RenderPinsRequest, config: DisplayPinConfig?) {
        clearStaticPath()
        renderPins(renderPinsRequest, config: config, completion: nil)
    }

    func displayStaticPath(
        using renderPinsRequest: RenderPinsRequest,
        startFromNearbyEntrance: Bool,
        disableZoomGestures: Bool
    ) {
        staticPathPreviewService.previewWaypoints = []
        showMapZoomedOut()
        isStaticPathVisible = true
        staticPathPreviewService.startFromNearbyEntrance = startFromNearbyEntrance
        setPinSelectionEnabled(false)
        mapViewDelegate?.displayPinErrorBanner(false)

        request(.renderPins(renderPinsRequest))
        mapViewDelegate?.previewSetUp(isStaticPathVisible: true)
        self.mapViewDelegate?.updateZoomInteraction(enabled: !disableZoomGestures)

        staticPathPreviewCancellable?.cancel()
        staticPathPreviewCancellable = staticPathPreviewService.handleRouteUpdate(
            assetService: assetService,
            indoorPositioningService: indoorPositioningService) { [weak self] enabled in
                self?.setPathfindingEnabled(enabled)
        } updateCustomRoute: { [weak self] coords in
            self?.updateCustomRoute(coords: coords, distance: .nan)
        }
    }

    func renderPins(from points: [CGPoint], config: DisplayPinConfig? = nil) {
        if let config {
            self.config = config
        }
        var pinsToDraw: [DrawPin] = []
        points.forEach { point in
            let mapPoint = point.waspToStoreMap(offset: assetService.storeConfigOffset)
            let drawPin = DrawPin(
                type: PinIdentifier.xyPinLocation.rawValue,
                x: mapPoint.x,
                y: mapPoint.y,
                location: Point(x: mapPoint.x, y: mapPoint.y),
                errorData: nil
            )
            pinsToDraw.append(drawPin)
        }
        // Update the pin list especially when its set from auto pin drop.
        pinList.last = PinList(pins: pinsToDraw)
        if let lastPinList = pinList.last {
            request(.renderXYLocationPinRequested(lastPinList))
        }
        Log.info("Show Pin with pinList: \(pinsToDraw)")
    }

    // MARK: - Zoom
    func updateZoomLevel(with scale: CGFloat) {
        guard let zoomLevel = StoreMapZoomLevel.makeZoomLevel(from: scale),
              let currentZoomLevel = StoreMapZoomLevel.makeZoomLevel(from: currentZoomScale),
              zoomLevel != currentZoomLevel
        else { return }
        Log.debug("updateZoomLevel with scale: \(scale)")
        request(.zoomLevelChange(ZoomLevelChangeRequest(zoom: zoomLevel.zoomValue)))
        zoomAnalyticsLogger?.updateAnalyticsValues(analyticsEventState: .zoomPinch, scale: scale)
        guard currentZoomScale != scale else { return }
        currentZoomScale = scale
        Log.debug("updateZoomViewIfNeed with zoomScale: \(scale)")
    }

    func zoomOut() {
       // zoomOut should only happen when map Center Button is not clicked
        Log.debug("""
                  ZoomOut should only happen when map Center Button is not clicked.
                  isCenterButtonClicked: \(String(describing: mapViewDelegate?.isCenterButtonClicked))
                  """
                 )
        guard let mapViewDelegate, !mapViewDelegate.isCenterButtonClicked else {
            return
        }

        request(.zoomLevelChange(ZoomLevelChangeRequest(zoom: 0)))
        showMapZoomedOut()
    }

    func onStoreMapZoomChange(zoomType: ZoomActionType, _ completion: (() -> Void)?) {
        guard let webView = mapViewDelegate?.webView else { return }
        let currentScale = webView.scrollView.zoomScale
        let zoomScale = getUpdateScale(currentScale, zoomType)
        zoomAnalyticsLogger?.updateAnalyticsValues(analyticsEventState: .zoomButton, scale: zoomScale)
        mapViewDelegate?.setZoomScale(to: zoomScale, zoomType: zoomType, completion)
    }

    // MARK: - Lifecycle
    func viewDidAppear() {
        bindUserPositioning()
        guard blueDotMode != .none, hasLoadedMapView.value == true else { return }
        mapFocusManager.isMapViewPresent.value = true
    }

    func viewWillDisappear() {
        userPositionCancellable?.cancel()
        guard blueDotMode != .none else { return }
        mapFocusManager.isMapViewPresent.value = false
    }

    func didConstructView() {
        refreshWebView()
        setupNavigationPaths()
    }

    func didLoadWebView() {
        zoomToPinsIfNeeded()

        guard let webView = mapViewDelegate?.webView else { return }
        zoomAnalyticsLogger?.updateZoomScale(zoomScale: webView.scrollView.zoomScale)
    }

    // MARK: - Error Handling
    func handleError() {
        statusService.emitMapStatusEvent(isSuccess: false)
    }

    // MARK: - Floor Change
    func onStoreMapFloorChange(levelType: FloorLevelType, _ completion: (() -> Void)?) {
        guard (mapViewDelegate?.webView) != nil else { return }
        floorSelected = levelType == .floorOne ? 0 : 1
        updateStoreConfigueOffset()
        request(.floorLevelChange((FloorLevelChangeRequest(floor: levelType.rawValue))))
    }

    // MARK: - Update the store configuration offset based on the selected floor.
    func updateStoreConfigueOffset() {
        guard let mapFloorOffset = self.mapLoadedData?.offsets,
              !mapFloorOffset.isEmpty else {
            return
        }
        
        guard mapFloorOffset.indices.contains(floorSelected) else {
            Log.warning("Floor index \(floorSelected) out of range for available offsets")
            return
        }
        
        let storeOffset = mapFloorOffset[floorSelected]
        self.assetService.storeConfigOffset = storeOffset
    }

    // MARK: - User Position/Rotation/Loading
    func updateUserPosition(x: Double, y: Double, accuracy: CGFloat?) {
        request(.showUserLocation(UserPosition(x: x, y: y, ringRadius: accuracy)))

        guard shouldUpdateNavigationRoute else { return }

        let pointList = [Point(x: x, y: y)]
        updateNavigationRoute(with: pointList, at: 0, using: nil, renderPinsRequest: nil)
    }

    func updateUserRotation(angle: CGFloat, rotateMap: Bool) {
        guard !isStaticPathVisible else { return }
        request(.rotateUser(UserRotation(angle: angle, rotateMap: rotateMap)))
    }

    func updateUserLoading(percentage: Int) {
        // Ensures the update location animation remains visible
        // even when the percentage is zero, as currently,
        // no animation is shown for a zero percentage value.
        request(.showUserLoading(UserLoading(
            percentage: (percentage == 0) ? 1 : percentage))
        )
    }

    // MARK: - WebView/Request
    func getMapURLRequest() -> URLRequest? {
        let urlPath = APIPath.storeMapAPI
        let urlString = urlPath.replacingOccurrences(
            of: RequestIdentifier.storeId.rawValue,
            with: "\(assetService.storeId)",
            options: .literal,
            range: nil)
        guard let url = URL(string: urlString) else {
            Log.warning("Cannot load Web View")
            return nil
        }

        var request = URLRequest(url: url)

        let httpHeaders = APIHelper.getStandardRequestHeaders()
        httpHeaders.forEach { (key, value) in
            request.setValue(value, forHTTPHeaderField: key)
        }

        guard var urlComponent = URLComponents(string: request.url?.absoluteString ?? "") else {
            return request
        }
        let consumerId = httpHeaders[RequestIdentifier.wmConsumerId.rawValue] ?? ""
        let urlQueryItem = [
            URLQueryItem(name: RequestIdentifier.mapType.rawValue, value: Analytics.mapType),
            URLQueryItem(name: RequestIdentifier.compressionEnabled.rawValue,
                         value: Analytics.isMapCompressionEnabled ? "true" : "false"),
            URLQueryItem(name: RequestIdentifier.cdnEnabled.rawValue,
                         value: Analytics.isMapCdnEnabled ? "true" : "false")
        ]
        urlComponent.queryItems = urlQueryItem
        request.url = urlComponent.url
        return request
    }

    // MARK: - Message Handling
    func messageParser(_ messageParser: MessageParsing, didParseMessageResponse message: MessageResponse) {
        Log.debug("Webview message received: \(message)")
        handle(message)
    }

    func messageParser(_ messageParser: MessageParsing, didFailWithError error: StoreMapDecodingError) {
        Log.error("Error occurred while parsing message: \(error)")
        guard let defaultValue = error.defaultValue else { return }
        handle(defaultValue)
    }

    func removeUserPositionIndicator() {
        let clearPos = UserPosition(x: -1, y: -1, ringRadius: nil)
        request(.showUserLocation(clearPos))
    }

    func getUserDistance(_ request: GetPinLocationRequest, completion: PinLocationFetchCompletionHandler?) {
        self.pinLocationFetchCompletionHandler = completion
        Log.info("user location requested \(request)")
        self.isPinDistanceFetched = true
        self.request(.pinLocationRequested(request))
    }

    func renderPins(_ renderPinsRequest: RenderPinsRequest, config: DisplayPinConfig?, completion: (([Pin]) -> Void)?) {
        if let config = config {
            self.config = config
        }
        self.pinRenderCompletion = completion
        request(.renderPins(renderPinsRequest))
    }

    func renderPins(_ pins: [Pin], config: DisplayPinConfig?) {
        if let config = config {
            self.config = config
        }
        request(.renderPins(RenderPinsRequest(pins: pins,
                                              pinGroupingEnabled: storeMapOptions.pinsConfig.groupPinsEnabled)))
    }

    func clearStaticPath() {
        isStaticPathVisible = false
        mapViewDelegate?.displayPinErrorBanner(false)
        setPinSelectionEnabled(true)
        mapViewDelegate?.previewSetUp(isStaticPathVisible: false)
        self.mapViewDelegate?.updateZoomInteraction(enabled: true)
        setPathfindingEnabled(false, force: true)
    }

    func logNavigationStartEvent(pin: Pin?) {
        guard let compassPosition = getUsersCurrentPosition(), let pin, let pinLocation = pin.location  else {
            return
        }

        let zone = pin.zone ?? ""
        let aisle = "\(pin.aisle ?? -1)"
        let section = "\(pin.section ?? -1)"

        let selectedPinValue = "\(zone).\(aisle).\(section)"

        let eventType = "NAVIGATION_START"
        let event = NavigationAnalytics.Event(type: eventType, value: selectedPinValue)

        let payload = NavigationAnalytics(
            event: event,
            location: NavigationAnalytics.Location(x: compassPosition.x, y: compassPosition.y),
            itemLocation: NavigationAnalytics.Location(x: pinLocation.x, y: pinLocation.y))

        Analytics.mapNavigation(payload: payload)
        wasUserNavigatingBefore = true
    }

    func logNavigationEndEvent() {
        guard let compassPosition = getUsersCurrentPosition() else {
            return
        }

        let eventType = "NAVIGATION_END"
        let event = NavigationAnalytics.Event(type: eventType)

        let payload = NavigationAnalytics(
            event: event,
            location: NavigationAnalytics.Location(x: compassPosition.x, y: compassPosition.y))

        Analytics.mapNavigation(payload: payload)
        wasUserNavigatingBefore = false
    }

    func getUsersCurrentPosition() -> CGPoint? {
        guard let position = indoorPositioningService.lastPosition.value,
              position.isLocked else {
            Log.info("The value of lastLockedPosition is nil")
            return nil
        }

        guard let converter = indoorPositioningService.floorCoordinatesConverter else {
            Log.info("The value of floorCoordinatesConverter is nil")
            return nil
        }

        let compassPosition = position.convertToCompass(using: converter).asCGPoint()
        return compassPosition
    }
}

extension StoreMapLoaderViewModel {
    func bindUserPositioning() {
        guard blueDotMode == .visible else { return }
        Log.debug("Subscribing to user position updates")

        var lastCenterButtonClicked = false
        userPositionCancellable = userPositionManager.getUserPosition()
            .receive(on: DispatchQueue.main)
            .filter { [weak self ]_ in
                self?.mapFocusManager.isMapViewPresent.value == true
            }
            .removeDuplicates { [weak self] position, newPosition in
                let isCenterButtonClicked = (lastCenterButtonClicked == self?.mapViewDelegate?.isCenterButtonClicked)
                lastCenterButtonClicked = self?.mapViewDelegate?.isCenterButtonClicked ?? lastCenterButtonClicked
                return position == newPosition && isCenterButtonClicked
            }
        // Throttles the user position updates to ensure a maximum of 3 calls per second
            .throttle(for: .milliseconds(400), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] user in
                self?.mapViewDelegate?.updateButtons(isPositionLocked: user.position?.isLocked ?? false)
                self?.mapViewDelegate?.updateLocationStatus(text: LocalizedKey.findingLocation,
                                                            isLocked: user.position?.isLocked ?? false)

                self?.requestShowUserLocation(position: user.position, accuracy: user.position?.accuracy)
                self?.handlePathfindingUpdate(for: user)
                self?.requestShowUserLoading(position: user.position)

                let dynamicMapEnabled = self?.storeMapOptions.dynamicMapEnabled ?? false
                let dynamicMapRotationEnabled = self?.storeMapOptions.dynamicMapRotationEnabled ?? false
                let isCenterButtonClicked = self?.mapViewDelegate?.isCenterButtonClicked ?? false
                let shouldRotateMap = isCenterButtonClicked && dynamicMapEnabled && dynamicMapRotationEnabled

                Log.debug("""
                          Rotate map only when center is clicked & feature flags enabled.
                          - shouldRotateMap is \(shouldRotateMap)
                          - dynamicMapEnabled is \(dynamicMapEnabled)
                          - dynamicMapRotationEnabled is \(dynamicMapRotationEnabled)
                          - isCenterButtonClicked is \(isCenterButtonClicked)
                         """
                )

                self?.requestUserRotation(headingAngle: user.position?.heading.angle, shouldRotateMap: shouldRotateMap)
            }
    }

    func handlePathfindingUpdate(for user: User) {
        guard user.position?.isLocked == false else {
            return
        }

        indoorNavigationService.resetWaypoints(shouldClearBlueDot: true, shouldClearPinList: false)
    }

    func requestShowUserLocation(position: IPSPosition?, accuracy: CGFloat?) {
        guard let converter = indoorPositioningService.floorCoordinatesConverter,
              let position, position.isLocked else {
            return
        }

        let accuracy = accuracy ?? 0 > 16 ? 16.0 : accuracy
        let point = position.convertToCompass(using: converter).asCGPoint()
            .waspToStoreMap(offset: assetService.storeConfigOffset)
        updateUserPosition(x: point.x, y: point.y, accuracy: accuracy)
    }

    private func requestUserRotation(headingAngle: CGFloat?, shouldRotateMap: Bool) {
        guard let headingAngle else {
            return
        }

        let rotationAngle = 90 - (headingAngle * 180.0 / .pi)
        updateUserRotation(angle: rotationAngle, rotateMap: shouldRotateMap)
    }

    private func requestShowUserLoading(position: IPSPosition?) {
        guard let position else {
            return
        }

        let percentage = Int(position.lockProgress * 100.0)
        updateUserLoading(percentage: percentage)
    }
}
