//
//  StoreMapStatesViewControllerTest.swift
//  compass_sdk_iosTests
//
//  Created by Rakesh Shetty on 11/21/24.
//

import XCTest
@testable import compass_sdk_ios

final class StoreMapStatesViewControllerTest: XCTestCase {
    class MockReloadDelegate: StoreMapReloadDelegate {
        var reloadCalled = false
        func reloadStoreMap() {
            reloadCalled = true
        }
    }
    
    let storeMapStatesViewController = StoreMapStatesView(mapStateModel: MapStateModel())

    func test_updateMapDisplayForState_withLoadingStoreMapState_shouldShowStoreMapStatesView() {
        storeMapStatesViewController.storeMapState = .loading(true)
        storeMapStatesViewController.updateMapDisplayForState()

        XCTAssertFalse(storeMapStatesViewController.isHidden)
    }

    func test_updateMapDisplayForState_withWarningStoreMapState_shouldShowStoreMapStatesView() {
        storeMapStatesViewController.storeMapState = .warning
        storeMapStatesViewController.updateMapDisplayForState()

        XCTAssertFalse(storeMapStatesViewController.isHidden)
    }

    func test_updateMapDisplayForState_withErrorStoreMapState_shouldShowStoreMapStatesView() {
        storeMapStatesViewController.storeMapState = .error
        storeMapStatesViewController.updateMapDisplayForState()

        XCTAssertFalse(storeMapStatesViewController.isHidden)
    }

    func test_reloadMapButtonTapped_shouldCallDelegate() {
        let mockDelegate = MockReloadDelegate()
        storeMapStatesViewController.storeMapReloadDelegate = mockDelegate
        storeMapStatesViewController.attempts = 0
        storeMapStatesViewController.reloadMapButtonTapped()
        XCTAssertTrue(mockDelegate.reloadCalled)
    }

    func test_reloadMapButtonTapped_whenAttemptsExceedMax_shouldStartCooldown() {
        let mockDelegate = MockReloadDelegate()
        storeMapStatesViewController.storeMapReloadDelegate = mockDelegate
        storeMapStatesViewController.attempts = 6 // greater than maxAttempts (5)
        storeMapStatesViewController.reloadMapButtonTapped()
        XCTAssertFalse(mockDelegate.reloadCalled, "Delegate should not be called when in cooldown.")
        // Optionally, you can check if attempts is still > 5 or other cooldown side effects
    }
}
