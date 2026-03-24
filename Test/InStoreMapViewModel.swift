//
//  InStoreMapViewModel.swift
//  Compass_ios
//
//  Created by Rakesh Shetty on 5/31/23.
//

import Combine
import UIKit
import Foundation
import IPSFramework

final class InStoreMapViewModel: MapHostViewModelType {
    private let blueDotMode: BlueDotMode
    let storeMapLoaderViewModel: StoreMapViewActionable
    private var cancellable: Set<AnyCancellable> = []
    private let assetService: AssetService
    private let indoorPositioningService: IndoorPositioningService
    private let indoorNavigationService: IndoorNavigationService
    private let mapFocusManager: MapFocusManager
    internal let storeMapOptions: StoreMapView.Options
    private(set) var storeMapViewController: UIViewController

    init(blueDotMode: BlueDotMode,
         storeMapOptions: StoreMapView.Options,
         serviceLocator: ServiceLocatorType) {
        self.blueDotMode = blueDotMode
        self.assetService = serviceLocator.getAssetService()
        self.indoorPositioningService = serviceLocator.getIndoorPositioningService()
        self.indoorNavigationService = serviceLocator.getIndoorNavigationService()
        self.mapFocusManager = serviceLocator.getMapFocusManager()

        self.storeMapLoaderViewModel = serviceLocator.getStoreMapViewModel(
            blueDotMode: blueDotMode,
            storeMapOptions: storeMapOptions,
            debugLog: storeMapOptions.debugLog
        )
        let mapViewController = StoreMapsViewController(webViewLoaderViewModel: self.storeMapLoaderViewModel,
                                                        options: storeMapOptions)
        self.storeMapViewController = mapViewController
        self.storeMapOptions = storeMapOptions

        if blueDotMode != .visible {
            mapFocusManager.isMapViewPresent.value = true
            let statusService = serviceLocator.getStatusService()
            statusService.emitPositionStatusEvent(calibrationProgress: 0,
                                                  isCalibrationGestureNeeded: false,
                                                  positioningProgress: 0,
                                                  isPositionLocked: true)
        }
    }

    func displayPin(uuidList: [String], idType: PinDropMethod, config: DisplayPinConfig?) {
        if uuidList.isEmpty {
            Analytics.telemetry(
                payload: TelemetryAnalytics(
                    event: idType == .generic ?
                    DisplayPin.DISPLAY_PIN_INVALID_INPUT_ASSET.rawValue :
                    DisplayPin.DISPLAY_PIN_INVALID_INPUT_GENERIC.rawValue
                )
            )
        }
        let defaults = UserDefaults.standard
        defaults.set(uuidList, forKey: UserDefaultsKey.uuidList.rawValue)
        assetService.evaluateAssets(using: uuidList,
                                    idType: idType,
                                    pinDropType: .autoPinDropAisleLocList) { [weak self] points in
            self?.storeMapLoaderViewModel.renderPins(from: points, config: config)
        }
    }

    func displayPin(pins: [CompassPin]?, config: DisplayPinConfig?) {
        // Always compute the zoom requirement (even for empty input) so the
        // map can zoom out when requested by the caller before we early return.
        let compassPins = pins ?? []
        let honorSelection = config?.honorPinSelection ?? false
        let (mappedPins, computedIsZoomOutRequired) = compassPins.toPinsAndLocation(honorPinSelection: honorSelection)

        if config?.resetZoom == true, computedIsZoomOutRequired {
            storeMapLoaderViewModel.zoomOut()
        }

        // Only after handling zoom behavior do we validate input and possibly return.
        guard !compassPins.isEmpty else {
            Analytics.telemetry(payload: TelemetryAnalytics(
                event: DisplayPin.DISPLAY_PIN_INVALID_INPUT_AISLE.rawValue
            ))
            return
        }

        UserDefaults.standard.setCustomObject(mappedPins, forKey: UserDefaultsKey.pinList.rawValue)
        if !mappedPins.isEmpty {
            storeMapLoaderViewModel.renderPins(
                RenderPinsRequest(pins: mappedPins, pinGroupingEnabled: storeMapOptions.pinsConfig.groupPinsEnabled),
                config: config
            )
            return
        }
    }

    func displayStaticPath(pins: [CompassPin], startFromNearbyEntrance: Bool, disableZoomGestures: Bool) {
        guard !pins.isEmpty else {
            Analytics.telemetry(payload: TelemetryAnalytics(
                event: DisplayPin.DISPLAY_PIN_INVALID_INPUT_AISLE.rawValue
            ))
            return
        }

        let (mappedPins, _) = pins.toPinsAndLocation(honorPinSelection: true)
        UserDefaults.standard.setCustomObject(mappedPins, forKey: UserDefaultsKey.pinList.rawValue)

        storeMapLoaderViewModel.displayStaticPath(
            using: RenderPinsRequest(pins: mappedPins, pinGroupingEnabled: storeMapOptions.pinsConfig.groupPinsEnabled),
            startFromNearbyEntrance: startFromNearbyEntrance,
            disableZoomGestures: disableZoomGestures
        )
    }

    func getUserDistance(pins: [AislePin], completion: UserDistanceCompleteHandler?) {
        guard !pins.isEmpty else {
            handleEmptyPinsCompletion(completion: completion)
            return
        }

        let aislePins: [Pin] = pins.map { Pin(from: $0) }
        guard handleMapNotLoadedIfNeeded(aislePins: aislePins, completion: completion) else {
            return
        }

        let timeoutInSeconds: Double = 3.0
        let completionState = CompletionState()
        let timeoutWorkItem = scheduleUserDistanceTimeout(
            timeoutInSeconds: timeoutInSeconds,
            aislePins: aislePins,
            completionState: completionState,
            completion: completion
        )

        storeMapLoaderViewModel.getUserDistance(GetPinLocationRequest(pins: aislePins)) { [weak self] pinLocation in
            guard !completionState.value else {
                Log.warning("Ignoring response - completion already called by timeout")
                return
            }
            completionState.value = true
            timeoutWorkItem.cancel()

            guard let self,
                  let userLocation = indoorPositioningService.lastLockedPosition,
                    indoorPositioningService.lockProgress == 1 else {
                let positionLockError = UserDistanceError(isPositionLocked: false, category: .positionLockNeeded)
                self?.handleUserDistancePositionLockError(
                    pins: pinLocation.pins ?? aislePins,
                    error: positionLockError,
                    completion: completion
                )
                return
            }

            guard let pins = pinLocation.pins,
                  let converter = indoorPositioningService.floorCoordinatesConverter else {
                let errorMessage = "Missing pinLocation pins or coordinate converter."
                Log.error(errorMessage)
                completion?(self.createErrorResponses(
                    pins: aislePins,
                    isPositionLocked: true,
                    errorCategory: .dataUnavailable,
                    errorMessage: errorMessage
                ))
                return
            }

            let userLocationInWasp = userLocation.convertToCompass(using: converter)
                .asCGPoint()
            let userDistanceResponse = self.getUserDistanceResponse(
                userLocationInWasp: userLocationInWasp,
                pins: pins
            )
            Log.debug("User distance response: \(userDistanceResponse)")
            completion?(userDistanceResponse)
        }
    }

    func getAisle(id: String) {
        assetService.evaluateAssets(using: [id],
                                    idType: .assets,
                                    pinDropType: .pinAisleLoc) { [weak self] points in
            guard let viewModel: StoreMapViewActionable = self?.storeMapLoaderViewModel
            else {
                return
            }

            viewModel.renderPins(from: points, config: nil)
        }
    }

    func displayMap() {
        Analytics.displayMap(payload: DisplayMapAnalytics(success: true))
    }

    func clearMap(mapConfig: MapConfig) {
        self.storeMapLoaderViewModel.clearRenderedPin(mapConfig: mapConfig)
    }

    func removeUserPositionIndicator() {
        storeMapLoaderViewModel.updateUserPosition(x: -1, y: -1, accuracy: nil)
    }
}

private extension InStoreMapViewModel {
    final class CompletionState {
        var value = false
    }

    func scheduleUserDistanceTimeout(
        timeoutInSeconds: Double,
        aislePins: [Pin],
        completionState: CompletionState,
        completion: UserDistanceCompleteHandler?
    ) -> DispatchWorkItem {
        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            guard !completionState.value else { return }
            completionState.value = true
            let isLocked = (self?.indoorPositioningService.lockProgress ?? 0) == 1
            let timeoutResponses = self?.createErrorResponses(
                pins: aislePins,
                isPositionLocked: isLocked,
                errorCategory: .pinLocationTimeout,
                errorMessage: "Unable to find aisle distance results timeout."
            ) ?? []
            Log.warning("Get user distance request timed out after \(timeoutInSeconds) seconds")
            completion?(timeoutResponses)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + timeoutInSeconds, execute: timeoutWorkItem)
        return timeoutWorkItem
    }

    func handleMapNotLoadedIfNeeded(
        aislePins: [Pin],
        completion: UserDistanceCompleteHandler?
    ) -> Bool {
        guard storeMapLoaderViewModel.isMapViewLoaded else {
            Log.warning("getUserDistance called but map view is not loaded")
            completion?(createErrorResponses(
                pins: aislePins,
                isPositionLocked: false,
                errorCategory: .mapNotLoaded,
                errorMessage: "Map view is not loaded."
            ))
            return false
        }

        return true
    }

    func handleEmptyPinsCompletion(completion: UserDistanceCompleteHandler?) {
        Log.warning("getUserDistance called with empty pins array")
        Analytics.userDistance(
            payload: UserDistanceAnalytics(
                event: .init(type: "GET_USER_DISTANCE", value: ""),
                location: nil,
                itemLocation: nil,
                isPositionLocked: false,
                userDistanceInInches: nil,
                error: "pins list is empty."
            )
        )
        let response = UserDistanceResponse(
            location: nil,
            userDistanceInInches: nil,
            error: UserDistanceError(isPositionLocked: false, category: .pinsEmpty)
        )
        completion?([response])
    }

    func createErrorResponses(
        pins: [Pin],
        isPositionLocked: Bool,
        errorCategory: UserDistanceError.Category,
        errorMessage: String
    ) -> [UserDistanceResponse] {
        pins.map { pin in
            logUserDistanceAnalytics(
                pin: pin,
                userLocationInWasp: nil,
                isPositionLocked: isPositionLocked,
                userDistanceInInches: nil,
                error: errorMessage
            )
            return UserDistanceResponse(
                location: pin.salesFloorLocation,
                userDistanceInInches: nil,
                error: UserDistanceError(isPositionLocked: isPositionLocked, category: errorCategory)
            )
        }
    }

    func getUserDistanceResponse(userLocationInWasp: CGPoint, pins: [Pin]) -> [UserDistanceResponse] {
        pins.map { pin in
            if let location = pin.location {
                let userLocationOnStoreMap = userLocationInWasp
                        .waspToStoreMap(offset: assetService.storeConfigOffset)
                let pinPoint = CGPoint(x: location.x, y: location.y)
                let userDistance = pinPoint.calculateDistanceTo(userLocationOnStoreMap)
                let response = UserDistanceResponse(location: pin.salesFloorLocation,
                                                    userDistanceInInches: userDistance,
                                                    error: nil)
                Log.debug(
                        "User distance for pin \(pin.salesFloorLocation.debugDescription) is \(userDistance) inches"
                    )

                logUserDistanceAnalytics(
                    pin: pin,
                    userLocationInWasp: CGPoint(x: userLocationInWasp.x,
                                                y: userLocationInWasp.y),
                    isPositionLocked: true,
                    userDistanceInInches: response.userDistanceInInches,
                    error: nil)

                return response
            } else {
                let response = UserDistanceResponse(location: pin.salesFloorLocation,
                                                    userDistanceInInches: nil,
                                                    error: UserDistanceError(isPositionLocked: true,
                                                                             category: .pinLocationUnknown))
                Log.error(response.error?.localizedDescription ?? "Unknown error")

                logUserDistanceAnalytics(
                    pin: pin,
                    userLocationInWasp: CGPoint(x: userLocationInWasp.x,
                                                y: userLocationInWasp.y),
                    isPositionLocked: true,
                    userDistanceInInches: nil,
                    error: "Item location unknown."
                )

                return response
            }
        }
    }

    func handleUserDistancePositionLockError(
        pins: [Pin],
        error: UserDistanceError,
        completion: UserDistanceCompleteHandler?
    ) {
        let responses = pins.map { pin in
            logUserDistanceAnalytics(
                pin: pin,
                userLocationInWasp: nil,
                isPositionLocked: false,
                userDistanceInInches: nil,
                error: "Position lock never acquired, wait for position lock and try again."
            )
            return UserDistanceResponse(
                location: pin.salesFloorLocation,
                userDistanceInInches: nil,
                error: error
            )
        }
        Log.error(error.message)
        Log.debug("User distance response: \(responses)")
        completion?(responses)
    }

    func logUserDistanceAnalytics(
        pin: Pin,
        userLocationInWasp: CGPoint?,
        isPositionLocked: Bool,
        userDistanceInInches: Double?,
        error: String?
    ) {
        let pinLocationString = [pin.zone ?? "", pin.aisle ?? "", pin.section ?? ""]
            .compactMap { $0 }
            .map { "\($0)" }
            .joined(separator: ".")

        let itemLocation: CGPoint? = {
            guard let location = pin.location else { return nil }
            let pinPoint = CGPoint(x: location.x, y: location.y)
            return pinPoint.storeMapToWasp(offset: assetService.storeConfigOffset)
        }()

        let userLocation: UserDistanceAnalytics.Location? = userLocationInWasp.map {
            .init(x: $0.x, y: $0.y)
        }

        let itemLocationAnalytics: UserDistanceAnalytics.Location? = itemLocation.map {
            .init(x: $0.x, y: $0.y)
        }

        Analytics.userDistance(
            payload: UserDistanceAnalytics(
                event: .init(type: "GET_USER_DISTANCE", value: pinLocationString),
                location: userLocation,
                itemLocation: itemLocationAnalytics,
                isPositionLocked: isPositionLocked,
                userDistanceInInches: userDistanceInInches,
                error: error
            )
        )
    }
}
