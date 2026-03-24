//
//  StoreMapViewActionable.swift
//  compass_sdk_ios
//
//  Created by Pratik Patel on 8/31/23.
//

import Foundation

protocol StoreMapViewActionable: MessageParserDelegate {
    typealias PinLocationFetchCompletionHandler = (PinRenderedMessage) -> Void
    var mapViewDelegate: StoreMapsViewDelegate? { get set }
    var messageParser: MessageParsing { get }
    var isMapViewLoaded: Bool { get }

    func didConstructView()
    func didLoadWebView()
    func viewDidAppear()
    func viewWillDisappear()
    func updateZoomLevel(with scale: CGFloat)
    func clearRenderedPin(mapConfig: MapConfig)
    func handleError()
    func renderPins(from points: [CGPoint], config: DisplayPinConfig?)
    func renderPins(_ pins: [Pin], config: DisplayPinConfig?)
    func renderPins(_ request: RenderPinsRequest, config: DisplayPinConfig?)
    func displayStaticPath(
        using renderPinsRequest: RenderPinsRequest,
        startFromNearbyEntrance: Bool,
        disableZoomGestures: Bool
    )
    func getUserDistance(_ request: GetPinLocationRequest, completion: PinLocationFetchCompletionHandler?)
    func updateUserPosition(x: Double, y: Double, accuracy: CGFloat?)
    func updateUserRotation(angle: CGFloat, rotateMap: Bool)
    func updateUserLoading(percentage: Int)
    func zoomOut()
    func onStoreMapZoomChange(zoomType: ZoomActionType, _ completion: (() -> Void)?)
    func getMapURLRequest() -> URLRequest?
    func onStoreMapFloorChange(levelType: FloorLevelType, _ completion: (() -> Void)?)
    func setPathfindingEnabled(_ enabled: Bool, duration: TimeInterval, force: Bool)
    func setPinSelectionEnabled(_ enabled: Bool)
    func setNavigation(enabled: inout Bool) -> Bool
    func canDisplayNavigationButton() -> Bool
}
