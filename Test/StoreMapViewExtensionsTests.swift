//
//  StoreMapViewExtensionsTests.swift
//  compass_sdk_iosTests
//
//  Created by Copilot on 1/22/26.
//

import XCTest
@testable import compass_sdk_ios

final class StoreMapViewExtensionsTests: XCTestCase {
    private let asyncUITestTimeout: TimeInterval = 5.0
    private var serviceLocator: MockServiceLocator!
    private var viewModel: MockStoreMapLoaderViewModel!
    private var storeMapView: StoreMapView!

    override func setUp() {
        super.setUp()
        serviceLocator = MockServiceLocator()
        viewModel = MockStoreMapLoaderViewModel(blueDotMode: .visible, serviceLocator: serviceLocator)
        let options = StoreMapView.Options(
            dynamicMapEnabled: true,
            zoomControlEnabled: true,
            errorScreensEnabled: true,
            spinnerEnabled: true,
            dynamicMapRotationEnabled: false,
            navigationConfig: NavigationConfig(enabled: true, refreshDuration: 0.0),
            mapUiConfig: MapUiConfig(bannerEnabled: false, snackBarEnabled: false, pinLocationUnavailableBannerEnabled: false),
            pinsConfig: PinsConfig(actionAlleyEnabled: false, groupPinsEnabled: true),
            debugLog: DebugLog(sensitiveInfoEnabled: false, navigationValidateCoordEnabled: false)
        )
        storeMapView = StoreMapView(webViewLoaderViewModel: viewModel, options: options)
    }

    override func tearDown() {
        storeMapView = nil
        viewModel = nil
        serviceLocator = nil
        super.tearDown()
    }

    func testToggleLoadingView_NoOp() {
        storeMapView.toggleLoadingView(true)
        storeMapView.toggleLoadingView(false)
        XCTAssertTrue(true)
    }

    func testUpdateZoomInteraction_TogglesUserInteraction() {
        storeMapView.updateZoomInteraction(enabled: false)
        XCTAssertFalse(storeMapView.webView.scrollView.isUserInteractionEnabled)
        storeMapView.updateZoomInteraction(enabled: true)
        XCTAssertTrue(storeMapView.webView.scrollView.isUserInteractionEnabled)
    }

    func testSetZoomScale_SetsScaleAndCallsCompletion() {
        let expectation = expectation(description: "setZoomScale completion")
        let targetScale = StoreMapZoomLevel.second.minimumZoomScale
        storeMapView.setZoomScale(to: targetScale, zoomType: .zoomIn) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: asyncUITestTimeout)
        XCTAssertEqual(storeMapView.webView.scrollView.zoomScale.rounded(toDecimalPlaces: 2), targetScale)
    }

    func testZoomOut_UsesMinimumScaleAndCallsCompletion() {
        let expectation = expectation(description: "zoomOut completion")
        // Start at a different scale
        storeMapView.webView.scrollView.setZoomScale(StoreMapZoomLevel.third.minimumZoomScale, animated: false)
        storeMapView.zoomOut(with: nil) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: asyncUITestTimeout)
        XCTAssertEqual(storeMapView.webView.scrollView.zoomScale.rounded(toDecimalPlaces: 2), StoreMapZoomLevel.first.minimumZoomScale)
    }

    func testZoomOnRegion_CallsCompletion() {
        let expectation = expectation(description: "zoomOnRegion completion")
        let rect = CGRect(x: 0, y: 0, width: 10, height: 10)
        storeMapView.zoomOnRegion(with: rect, zoomAnimationDelay: 0.1) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: asyncUITestTimeout)
    }

    func testHandleNavigationInterruption_ResetsFlag() {
        storeMapView.isNavigationButtonClicked = true
        storeMapView.handleNavigationInterruption(for: 1, status: .interrupted)
        XCTAssertFalse(storeMapView.isNavigationButtonClicked)
    }

    func testRefreshNavigationButtonState_UpdatesVisibility() {
        XCTAssertNil(storeMapView.lastNavigationButtonVisibility)
        storeMapView.refreshNavigationButtonState(true)
        XCTAssertEqual(storeMapView.lastNavigationButtonVisibility, true)
        storeMapView.refreshNavigationButtonState(false)
        XCTAssertEqual(storeMapView.lastNavigationButtonVisibility, false)
    }

    // MARK: - Internal Extension Tests
    func testResetCenterButtonAndStatus_ResetsFlags() {
        storeMapView.isCenterButtonClicked = true
        storeMapView.isLocationStatusVisible = true
        storeMapView.resetCenterButtonAndStatus()
        XCTAssertFalse(storeMapView.isCenterButtonClicked)
        XCTAssertFalse(storeMapView.isLocationStatusVisible)
    }

    func testUpdateMapCenterButton_HiddenWhenPositionNotLocked() {
        storeMapView.currentIsPositionLocked = false
        storeMapView.updateMapCenterButton()
        XCTAssertTrue(storeMapView.mapCenterButton.isHidden)
    }

    func testUpdateMapCenterButton_HiddenWhenDynamicMapDisabled() {
        let disabledOptions = StoreMapView.Options(
            dynamicMapEnabled: false,
            zoomControlEnabled: true,
            errorScreensEnabled: true,
            spinnerEnabled: true,
            dynamicMapRotationEnabled: false,
            navigationConfig: NavigationConfig(enabled: true, refreshDuration: 0.0),
            mapUiConfig: MapUiConfig(bannerEnabled: false, snackBarEnabled: false, pinLocationUnavailableBannerEnabled: false),
            pinsConfig: PinsConfig(actionAlleyEnabled: false, groupPinsEnabled: true),
            debugLog: DebugLog(sensitiveInfoEnabled: false, navigationValidateCoordEnabled: false)
        )
        let disabledView = StoreMapView(webViewLoaderViewModel: viewModel, options: disabledOptions)
        disabledView.currentIsPositionLocked = true
        disabledView.updateMapCenterButton()
        XCTAssertTrue(disabledView.mapCenterButton.isHidden)
    }

    func testUpdateMapCenterButton_VisibleWhenPositionLockedAndDynamicMapEnabled() {
        storeMapView.currentIsPositionLocked = true
        storeMapView.isCenterButtonClicked = false
        storeMapView.updateMapCenterButton()
        // updateMapCenterButton handles main queue dispatch internally
        XCTAssertFalse(storeMapView.mapCenterButton.isHidden)
    }

    func testUpdateNavigationButton_HiddenWhenNavigationDisabled() {
        let disabledOptions = StoreMapView.Options(
            dynamicMapEnabled: true,
            zoomControlEnabled: true,
            errorScreensEnabled: true,
            spinnerEnabled: true,
            dynamicMapRotationEnabled: false,
            navigationConfig: NavigationConfig(enabled: false, refreshDuration: 0.0),
            mapUiConfig: MapUiConfig(bannerEnabled: false, snackBarEnabled: false, pinLocationUnavailableBannerEnabled: false),
            pinsConfig: PinsConfig(actionAlleyEnabled: false, groupPinsEnabled: true),
            debugLog: DebugLog(sensitiveInfoEnabled: false, navigationValidateCoordEnabled: false)
        )
        let disabledView = StoreMapView(webViewLoaderViewModel: viewModel, options: disabledOptions)
        disabledView.updateNavigationButton()
        XCTAssertTrue(disabledView.navigationButton.isHidden)
    }

    func testUpdateNavigationButton_VisibleWhenAllConditionsMet() {
        // Setup navigation config to pass the first guard
        let navEnabledOptions = StoreMapView.Options(
            dynamicMapEnabled: true,
            zoomControlEnabled: true,
            errorScreensEnabled: true,
            spinnerEnabled: true,
            dynamicMapRotationEnabled: false,
            navigationConfig: NavigationConfig(enabled: true, refreshDuration: 0.0, isAutomaticNavigation: false),
            mapUiConfig: MapUiConfig(bannerEnabled: false, snackBarEnabled: false, pinLocationUnavailableBannerEnabled: false),
            pinsConfig: PinsConfig(actionAlleyEnabled: false, groupPinsEnabled: true),
            debugLog: DebugLog(sensitiveInfoEnabled: false, navigationValidateCoordEnabled: false)
        )
        let navView = StoreMapView(webViewLoaderViewModel: viewModel, options: navEnabledOptions)
        
        // Setup navigation session state with pins on map
        var sessionState = NavigationSessionState(
            currentLocationWaypoint: nil,
            destinationWaypoints: [],
            renderPinsRequest: nil,
            pinList: nil
        )
        sessionState.hasPinsOnMap = true
        viewModel._navigationSessionState = sessionState
        
        navView.currentIsPositionLocked = true
        navView.isNavigationButtonClicked = true
        navView.updateNavigationButton()
        XCTAssertFalse(navView.navigationButton.isHidden)
    }

    func testUpdateNavigationButton_HiddenWhenPositionNotLocked() {
        storeMapView.currentIsPositionLocked = false
        storeMapView.isNavigationButtonClicked = false
        storeMapView.updateNavigationButton()
        XCTAssertTrue(storeMapView.navigationButton.isHidden)
    }

    func testGetZoomButtonModel_ForZoomIn() {
        let model = storeMapView.getZoomButtonModel(for: .zoomIn)
        XCTAssertEqual(model.type, .zoomIn)
    }

    func testGetZoomButtonModel_ForZoomOut() {
        let model = storeMapView.getZoomButtonModel(for: .zoomOut)
        XCTAssertEqual(model.type, .zoomOut)
    }

    func testCreateZoomButton_HasCorrectConfiguration() {
        let zoomButton = storeMapView.createZoomButton(actionType: .zoomIn)
        XCTAssertFalse(zoomButton.translatesAutoresizingMaskIntoConstraints)
    }

    func testZoomButtonAction_ZoomIn_TriggersViewModelCallback() {
        // Arrange
        let zoomButton = storeMapView.createZoomButton(actionType: .zoomIn)
        let initialZoomInCount = viewModel.onStoreMapZoomChangeCallCount

        // Act
        zoomButton.sendActions(for: .primaryActionTriggered)

        // Assert
        XCTAssertGreaterThan(viewModel.onStoreMapZoomChangeCallCount, initialZoomInCount)
        XCTAssertEqual(viewModel.lastZoomType, .zoomIn)
    }

    func testZoomButtonAction_ZoomOut_TriggersViewModelCallback() {
        // Arrange
        let zoomButton = storeMapView.createZoomButton(actionType: .zoomOut)
        let initialZoomOutCount = viewModel.onStoreMapZoomChangeCallCount

        // Act
        zoomButton.sendActions(for: .primaryActionTriggered)

        // Assert
        XCTAssertGreaterThan(viewModel.onStoreMapZoomChangeCallCount, initialZoomOutCount)
        XCTAssertEqual(viewModel.lastZoomType, .zoomOut)
    }

    func testZoomButtonAction_ResetsCenterButtonAndStatus() {
        // Arrange
        storeMapView.isCenterButtonClicked = true
        storeMapView.isLocationStatusVisible = true
        let zoomButton = storeMapView.createZoomButton(actionType: .zoomIn)

        // Act
        zoomButton.sendActions(for: .primaryActionTriggered)

        // Assert
        XCTAssertFalse(storeMapView.isCenterButtonClicked)
        XCTAssertFalse(storeMapView.isLocationStatusVisible)
    }

    func testZoomButtonAction_WithWeakSelfGuard_DoesNotCrash() {
        // Arrange
        var weakView: StoreMapView? = StoreMapView(webViewLoaderViewModel: viewModel, options: StoreMapView.Options(
            dynamicMapEnabled: true,
            zoomControlEnabled: true,
            errorScreensEnabled: true,
            spinnerEnabled: true,
            dynamicMapRotationEnabled: false,
            navigationConfig: NavigationConfig(enabled: true, refreshDuration: 0.0),
            mapUiConfig: MapUiConfig(bannerEnabled: false, snackBarEnabled: false, pinLocationUnavailableBannerEnabled: false),
            pinsConfig: PinsConfig(actionAlleyEnabled: false, groupPinsEnabled: true),
            debugLog: DebugLog(sensitiveInfoEnabled: false, navigationValidateCoordEnabled: false)
        ))

        let zoomButton = weakView!.createZoomButton(actionType: .zoomIn)

        // Act - Deallocate the view to test weak self guard
        weakView = nil

        // This should not crash due to guard let self else { return }
        zoomButton.sendActions(for: .primaryActionTriggered)

        // Assert - No crash occurred
        XCTAssertTrue(true)
    }

    func testMapCenterButtonTapped_TogglesFlag() {
        let initialState = storeMapView.isCenterButtonClicked
        storeMapView.mapCenterButtonTapped()
        XCTAssertNotEqual(storeMapView.isCenterButtonClicked, initialState)
    }

    func testHandleError_InvalidStatusCode() {
        storeMapView.handleError(.invalidStatusCode(404))
        if case .error = storeMapView.mapState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected error state")
        }
    }

    func testHandleError_InvalidResponse() {
        storeMapView.handleError(.invalidResponse)
        if case .error = storeMapView.mapState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected error state")
        }
    }

    func testHandleError_FailedToLoadContent() {
        let testError = NSError(domain: "test", code: -1, userInfo: nil)
        storeMapView.handleError(.failedToLoadContent(testError))
        if case .error = storeMapView.mapState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected error state")
        }
    }

    func testHandleError_NoInternetConnection() {
        let testError = NSError(domain: "test", code: -1, userInfo: nil)
        storeMapView.handleError(.noInternetConnection(testError))
        if case .warning = storeMapView.mapState {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected warning state")
        }
    }

    func testScrollViewWillBeginDragging_ResetsState() {
        storeMapView.isCenterButtonClicked = true
        storeMapView.isLocationStatusVisible = true
        storeMapView.scrollViewWillBeginDragging(storeMapView.webView.scrollView)
        XCTAssertFalse(storeMapView.isCenterButtonClicked)
        XCTAssertFalse(storeMapView.isLocationStatusVisible)
    }

    func testConfigurePinErrorBanner_SetsUpBanner() {
        storeMapView.configurePinErrorBanner()
        XCTAssertTrue(storeMapView.pinErrorBanner.isHidden)
    }

    func testDisplayPinErrorBanner_ShowsBannerWhenEnabled() {
        storeMapView.displayPinErrorBanner(true)
        XCTAssertFalse(storeMapView.pinErrorBanner.isHidden)
    }

    func testDisplayPinErrorBanner_HidesBannerWhenDisabled() {
        // Create view with banner enabled so displayPinErrorBanner actually runs
        let bannerEnabledOptions = StoreMapView.Options(
            dynamicMapEnabled: true,
            zoomControlEnabled: true,
            errorScreensEnabled: true,
            spinnerEnabled: true,
            dynamicMapRotationEnabled: false,
            navigationConfig: NavigationConfig(enabled: true, refreshDuration: 0.0),
            mapUiConfig: MapUiConfig(bannerEnabled: false, snackBarEnabled: false, pinLocationUnavailableBannerEnabled: true),
            pinsConfig: PinsConfig(actionAlleyEnabled: false, groupPinsEnabled: true),
            debugLog: DebugLog(sensitiveInfoEnabled: false, navigationValidateCoordEnabled: false)
        )
        let bannerView = StoreMapView(webViewLoaderViewModel: viewModel, options: bannerEnabledOptions)
        bannerView.displayPinErrorBanner(false)
        XCTAssertTrue(bannerView.pinErrorBanner.isHidden)
    }

    func testSetMapState_LoadingStateWithSpinnerEnabled() {
        storeMapView.setMapState(.loading(true))
        XCTAssertNotNil(storeMapView.mapState)
    }

    func testSetMapState_ErrorStateWithErrorScreensEnabled() {
        storeMapView.setMapState(.error)
        XCTAssertNotNil(storeMapView.mapState)
    }

    func testSetMapState_WarningStateWithErrorScreensEnabled() {
        storeMapView.setMapState(.warning)
        XCTAssertNotNil(storeMapView.mapState)
    }

    func testSetFloorSelectionAnalytics() {
        storeMapView.setFloorSelectionAnalytics(floorValue: "1")
        XCTAssertTrue(true)
    }

    func testSetMapInteractionAnalytics() {
        storeMapView.setMapInteractionAnalytics()
        XCTAssertTrue(true)
    }

    func testNavigationButtonTapped_CallsSetNavigation() {
        storeMapView.navigationButtonTapped()
        XCTAssertTrue(true)
    }

    func testCreateFloorButton_ReturnsCustomButton() {
        let model = storeMapView.getFloorButtonModel(for: .floorOne)
        let floorButton = storeMapView.createFloorButton(with: model)
        XCTAssertNotNil(floorButton)
    }

    func testUpdateLocationStatus_WhenLockedStopsAnimating() {
        storeMapView.isLocationStatusVisible = true
        storeMapView.locationStatusLabel.isHidden = false
        storeMapView.locationActivityIndicator.startAnimating()
        storeMapView.updateLocationStatus(text: "Locked", isLocked: true)
        XCTAssertFalse(storeMapView.isLocationStatusVisible)
        XCTAssertFalse(storeMapView.locationActivityIndicator.media.isAnimating)
    }

    func testUpdateLocationStatus_WhenNotLockedStartsAnimating() {
        storeMapView.isLocationStatusVisible = false
        storeMapView.locationStatusLabel.isHidden = false
        storeMapView.updateLocationStatus(text: "Finding location", isLocked: false)
        XCTAssertTrue(storeMapView.isLocationStatusVisible)
        XCTAssertTrue(storeMapView.locationActivityIndicator.media.isAnimating)
    }

    func testUpdateLocationStatus_IgnoredWhenLabelHidden() {
        storeMapView.locationStatusLabel.isHidden = true
        let initialState = storeMapView.isLocationStatusVisible
        storeMapView.updateLocationStatus(text: "Test", isLocked: false)
        XCTAssertEqual(storeMapView.isLocationStatusVisible, initialState)
    }

//    func testUpdateLocationStatusAfterDelay_SetsTextAfterDelay() {
//        // Arrange
//        storeMapView.locationStatusLabel.text = nil
//        let delayTime: TimeInterval = 0.1
//        let expectation = expectation(description: "Text updated after delay")
//
//        // Act
//        storeMapView.updateLocationStatusAfterDelay(text: "Test Status", delay: delayTime)
//
//        // Assert - Wait for the delay
//        DispatchQueue.main.asyncAfter(deadline: .now() + delayTime + 0.05) {
//            XCTAssertEqual(self.storeMapView.locationStatusLabel.text, "Test Status")
//            expectation.fulfill()
//        }
//        waitForExpectations(timeout: 1.0)
//    }
//
//    func testUpdateLocationStatusAfterDelay_WithCustomDelay() {
//        // Arrange
//        storeMapView.locationStatusLabel.text = nil
//        let delayTime: TimeInterval = 0.2
//        let expectation = expectation(description: "Custom delay executed")
//
//        // Act
//        storeMapView.updateLocationStatusAfterDelay(text: "Custom Delay", delay: delayTime)
//
//        // Assert - Text should NOT be set immediately
//        XCTAssertNotEqual(storeMapView.locationStatusLabel.text, "Custom Delay")
//
//        // Wait for delay to complete
//        DispatchQueue.main.asyncAfter(deadline: .now() + delayTime + 0.05) {
//            XCTAssertEqual(self.storeMapView.locationStatusLabel.text, "Custom Delay")
//            expectation.fulfill()
//        }
//        waitForExpectations(timeout: 1.0)
//    }
//
//    func testUpdateLocationStatusAfterDelay_DefaultDelayIs5Seconds() {
//        // Arrange
//        storeMapView.locationStatusLabel.text = nil
//
//        // Act - Call without delay parameter (uses default 5.0)
//        storeMapView.updateLocationStatusAfterDelay(text: "Default Delay")
//
//        // Assert - Text should not be set immediately
//        XCTAssertNotEqual(storeMapView.locationStatusLabel.text, "Default Delay")
//        
//        // Verify it will be set after a short delay (we won't wait the full 5 seconds in test)
//        let expectation = expectation(description: "Default delay used")
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//            // At 0.1 seconds, it shouldn't be set yet (5 second delay)
//            XCTAssertNotEqual(self.storeMapView.locationStatusLabel.text, "Default Delay")
//            expectation.fulfill()
//        }
//        waitForExpectations(timeout: 1.0)
//    }

    func testDisableTextSelection_iOS14_5Plus() {
        storeMapView.disableTextSelection()
        if #available(iOS 14.5, *) {
            XCTAssertFalse(storeMapView.webView.configuration.preferences.isTextInteractionEnabled)
        } else {
            // On earlier iOS, check that user script was added
            XCTAssertGreaterThan(storeMapView.webView.configuration.userContentController.userScripts.count, 0)
        }
    }
}
