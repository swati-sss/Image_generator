//
//  StoreMapLoaderViewModel.swift
//  StoreMaps
//
//  Created by Divya Thyagarajan on 16/08/21.
//  Copyright © 2021 Walmart. All rights reserved.
//

import CoreGraphics
import Combine
import UIKit

enum ZoomTarget {
    case userLocation
    case pinAnnotation
}

class StoreMapLoaderViewModel {
    weak var mapViewDelegate: StoreMapsViewDelegate?
    let blueDotMode: BlueDotMode
    let userPositionManager: UserPositionManagement

    private(set) var navigationEnabled: Bool?
    private(set) var pinsConfig: PinsConfig
    private(set) var debugLog: DebugLog?

    var currentZoomScale: CGFloat = 0
    var lastPathfindingEnabled: Bool?
    var isStaticPathVisible = false
    var staticPathPreviewCancellable: AnyCancellable?
    var routeCancellable: AnyCancellable?
    var pinList: (current: PinList?, last: PinList?)
    var currentPins: [Pin] = []
    var isPinDistanceFetched: Bool = false
    var pinLocationFetchCompletionHandler: PinLocationFetchCompletionHandler?
    var pinRenderCompletion: (([Pin]) -> Void)?
    var floorSelected = 0
    private(set) var storeMapOptions: StoreMapView.Options

    internal var assetService: AssetService
    internal var statusService: StatusService
    internal var indoorNavigationService: IndoorNavigationService
    internal var staticPathPreviewService: StaticPathPreviewService
    internal var userPositionCancellable: AnyCancellable?

    private(set) var indoorPositioningService: IndoorPositioningService
    private(set) var mapFocusManager: MapFocusManager
    private(set) var eventService: EventService
    private(set) var messageParser: MessageParsing
    private(set) var messageSender: MessageSending
    let userDefaults: UserDefaults

    internal var mapData: MapData?
    internal var mapLoadedData: MapLoaded?
    internal var hasLoadedMapView = CurrentValueSubject<Bool, Never>(false)
    internal var hasMapViewZoomed = false
    internal var renderedPins: [Pin] = []
    internal var renderedPinsZoomRect: CGRect?
    internal var mapDataReadyRequestTimer: Timer?

    private(set) var preferredZoomScale: CGFloat = StoreMapZoomLevel.third.minimumZoomScale
    private(set) var zoomAnalyticsLogger: ZoomAnalyticsLogger?
    private(set) var cancellable: [AnyCancellable] = []
    private(set) var callCount: Int = 0
    private(set) var lastLogTime: TimeInterval = 0

    var config = DisplayPinConfig(
        enableManualPinDrop: true,
        resetZoom: false,
        shouldZoomOnPins: true
    )

    internal var configuration = StoreMapView.Configuration(
        isPinSelectionEnabled: false,
        pin: nil,
        preferredFloor: "1"
    )

    internal var wasUserNavigatingBefore: Bool = false

    init(blueDotMode: BlueDotMode,
         storeMapOptions: StoreMapView.Options,
         debugLog: DebugLog?,
         serviceLocator: ServiceLocatorType,
         userDefaults: UserDefaults = .standard,
         zoomAnalyticsLogger: ZoomAnalyticsLogger? = ZoomAnalyticsLogger(workflow: Analytics.workflow)) {
        self.storeMapOptions = storeMapOptions
        self.pinsConfig = storeMapOptions.pinsConfig
        self.blueDotMode = blueDotMode
        self.navigationEnabled = storeMapOptions.navigationConfig.enabled ?? false
        self.debugLog = debugLog
        self.messageSender = serviceLocator.getWebViewMessageSender()
        self.messageParser = serviceLocator.getWebViewMessageParser()
        self.assetService = serviceLocator.getAssetService()
        self.statusService = serviceLocator.getStatusService()
        self.indoorPositioningService = serviceLocator.getIndoorPositioningService()
        self.indoorNavigationService = serviceLocator.getIndoorNavigationService()
        self.staticPathPreviewService = serviceLocator.getStaticPathPreviewService()
        self.indoorNavigationService.navigationConfig = storeMapOptions.navigationConfig
        self.userPositionManager = serviceLocator.getUserPositionManager()
        self.mapFocusManager = serviceLocator.getMapFocusManager()
        self.eventService = serviceLocator.getEventService()
        self.userDefaults = userDefaults
        self.messageParser.delegate = self
        self.zoomAnalyticsLogger = zoomAnalyticsLogger
        self.pinList = (current: nil, last: nil)
        self.indoorNavigationService.delegate = self

        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.userPositionCancellable = nil
            }.store(in: &cancellable)

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.bindUserPositioning()
            }.store(in: &cancellable)
    }

    deinit {
        mapDataReadyRequestTimer?.invalidate()
        mapDataReadyRequestTimer = nil
        cancellable.removeAll()
        Log.info("Released StoreMapLoaderViewModel")
    }

#if DEBUG
    func updateConfiguration(pinsConfig: PinsConfig, navigationConfig: NavigationConfig?) {
        self.pinsConfig = pinsConfig
        navigationEnabled = navigationConfig?.enabled ?? false
        indoorNavigationService.navigationConfig = navigationConfig
    }
#endif
}

extension StoreMapLoaderViewModel {
     func updateStaticPathIfNeeded(for pinRenderedMessage: PinRenderedMessage) {
         // Check if there are pins to process
         guard let pins = pinRenderedMessage.pins,
               !pins.isEmpty,
               isStaticPathVisible else {
             return
         }

         logStaticPathAnalyticsEvent(pins: pins)

         // Filter pins that are selected and valid
         let validPins = pins.filter { $0.errorData == nil }

         guard validPins == pins else {
             mapViewDelegate?.displayPinErrorBanner(true)
             setPathfindingEnabled(false, force: true)
             return
         }

         // Convert valid pins to Point list
         // Add entrance point if available
         var pointList: [Point] = []
         if staticPathPreviewService.startFromNearbyEntrance,
            let entrance = mapLoadedData?.entrances.first {
             pointList.append(Point(x: entrance.x, y: entrance.y))
         }

         // Convert valid pins to Point list and append
         pointList += validPins.compactMap { $0.location.map { Point(x: $0.x, y: $0.y) } }

         // If there are valid pins
         if !validPins.isEmpty {
             // Add route for these pins
             updateStaticPathRoute(with: pointList)
         }
     }

    // For [Pin]
    func refreshNavigationState(withPins pins: [Pin]) {
        let validPins = pins.filter { $0.errorData == nil }
        let hasPinsOnMap = !validPins.isEmpty
        indoorNavigationService.navigationSessionState?.hasPinsOnMap = hasPinsOnMap
        mapViewDelegate?.refreshNavigationButtonState(hasPinsOnMap)
    }

    // For [DrawPin]
    func refreshNavigationState(withDrawPins drawPins: [DrawPin]) {
        let validPins = drawPins.filter { $0.errorData == nil }
        let hasPinsOnMap = !validPins.isEmpty
        indoorNavigationService.navigationSessionState?.hasPinsOnMap = hasPinsOnMap
        mapViewDelegate?.refreshNavigationButtonState(hasPinsOnMap)
    }
}

internal extension StoreMapLoaderViewModel {
    // Handles the rendering and navigation logic for aisle pins
    func handlePinRenderedMessage(_ pinRenderedMessage: PinRenderedMessage) {
        // Log the received message
        Log.debug("Aisle pin rendered: \(pinRenderedMessage)")

        guard !self.isPinDistanceFetched else {
            self.isPinDistanceFetched = false
            pinLocationFetchCompletionHandler?(pinRenderedMessage)
            return
        }

        self.currentPins = pinRenderedMessage.pins ?? []

        // Report analytics/status for the pins
        reportPinAisleStatusEvent(for: pinRenderedMessage.pins ?? [])
        renderFeatureLocationPinsIfNeeded(for: pinRenderedMessage)
        updateNavigationServicesIfNeeded(for: pinRenderedMessage)
        updateStaticPathIfNeeded(for: pinRenderedMessage)
        // Check if there are pins to process
        if let pins = pinRenderedMessage.pins, !pins.isEmpty, isStaticPathVisible == false {
            zoomOnLocation(topLeft: pinRenderedMessage.topLeft, bottomRight: pinRenderedMessage.bottomRight)
        }
    }

    // Handles the rendering and navigation logic for XY pins
    func handlePinXYRenderedMessage(_ message: PinXYRenderedMessage) {
        // Log the received message
        Log.debug("XY pin rendered: \(message)")

        // Get all pins from message (xyLocationPins or pins)
        let allPins = (message.xyLocationPins?.isEmpty == false ? message.xyLocationPins : message.pins) ?? []

        // Check if there are pins to process
        guard !allPins.isEmpty else {
            // Hide navigation button if no pins
            mapViewDelegate?.refreshNavigationButtonState(false)
            // Exit if no pins
            return
        }

        // Reset navigation waypoints
        indoorNavigationService.resetWaypoints(shouldClearBlueDot: false, shouldClearPinList: true)

        // Filter pins that are valid
        let validPins = allPins.filter { $0.errorData == nil }

        // Convert valid pins to Point list
        let pointList = validPins.map { Point(x: $0.x, y: $0.y) }

        // Check if there are any valid pins
        let hasValidPin = !validPins.isEmpty

        // Only update if navigation is not in progress
        let shouldUpdatePinList = indoorNavigationService.navigationSessionState?.navigationStatus != .inProgress

        // Prepare pin list if needed
        let currentPinList = shouldUpdatePinList ? PinList(pins: validPins) : nil

        // Update navigation state with new pins
        indoorNavigationService.updateNavigationState(
            currentLocation: nil,
            pinWaypoint: nil,
            renderRequest: nil,
            pinListUpdate: currentPinList
        )

        mapViewDelegate?.handleNavigationInterruption(for: 1, status: navigationSessionState?.navigationStatus)

        // If there are valid pins
        if hasValidPin {
            // Add navigation route for these pins
            updateNavigationRoute(
                with: pointList,
                at: 1,
                using: currentPinList,
                renderPinsRequest: nil
            )
        } else {
            // Reset navigation session state if no valid pins
            indoorNavigationService.resetNavigationSessionState()
        }

        // Update navigation button state
        refreshNavigationState(withDrawPins: allPins)

        // Zoom to pin area
        zoomOnLocation(topLeft: message.topLeft, bottomRight: message.bottomRight)
    }
}

extension StoreMapLoaderViewModel: IndoorNavigationServiceDelegate {
    func requestRenderPins(_ pins: [Pin]?, pinList: PinList?, navigationEvent: NavigationAnalytics.Event?) {
        if let pins = pins {
            request(.renderPins(.init(pins: pins, pinGroupingEnabled: storeMapOptions.pinsConfig.groupPinsEnabled)))

            guard let position = indoorPositioningService.lastPosition.value,
                  position.isLocked else {
                Log.info("[Navigation] The value of lastLockedPosition is nil")
                return
            }

            guard let converter = indoorPositioningService.floorCoordinatesConverter else {
                Log.info("[Navigation] The value of floorCoordinatesConverter is nil")
                return
            }

            let compassPosition = position.convertToCompass(using: converter).asCGPoint()

            let payload = NavigationAnalytics(
                event: navigationEvent,
                location: NavigationAnalytics.Location(x: compassPosition.x, y: compassPosition.y)
            )

            Analytics.mapNavigation(payload: payload)
        } else if let pinList = pinList {
            request(.renderXYLocationPinRequested(pinList))
        }
    }

    func refreshNavigationButtonState(_ isVisible: Bool?) {
        mapViewDelegate?.refreshNavigationButtonState(isVisible)
    }

    func logStaticPathAnalyticsEvent(pins: [Pin]) {
        var location: StaticPathAnalytics.Location?
        if let position = indoorPositioningService.lastLockedPosition {
            location = StaticPathAnalytics.Location(x: position.x, y: position.y)
        }

        let events: [StaticPathAnalytics.Event] = pins.compactMap {
            var aisleLocation = ""
            if let zone = $0.zone, let aisle = $0.aisle, let Section = $0.section {
                aisleLocation = "\(zone).\(aisle).\(Section)"
            }

            var itemId = ""
            if let itemIdString = $0.id?.description {
                itemId = itemIdString
            }

            let location = StaticPathAnalytics.Location(x: $0.location?.x, y: $0.location?.y)

            return StaticPathAnalytics.Event(itemId: itemId,
                                             aisleLocation: aisleLocation,
                                             itemLocation: location)
        }

        let staticPathAnalyticsPayload = StaticPathAnalytics(location: location, event: events)
        Analytics.displayStaticPath(payload: staticPathAnalyticsPayload)
    }
}
