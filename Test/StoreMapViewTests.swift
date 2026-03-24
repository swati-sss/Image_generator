//
//  StoreMapViewTests.swift
//  compass_sdk_iosTests
//
//  Created by Rakesh Shetty on 3/29/24.
//

import XCTest
@testable import compass_sdk_ios
import LivingDesign
import WebKit

class StoreMapViewTests: XCTestCase {
    static var mockNavigation = MockWKNavigation()
    var storeMapView: StoreMapView!
    var webViewLoaderViewModel: StoreMapLoaderViewModel!
    var statusService: StatusService!
    
    override func setUpWithError() throws {
        let serviceLocator = MockServiceLocator()
        statusService = serviceLocator.getStatusService()
        let options = StoreMapView.Options(
            dynamicMapEnabled: true,
            zoomControlEnabled: true,
            errorScreensEnabled: true,
            spinnerEnabled: true,
            dynamicMapRotationEnabled: false,
            navigationConfig: NavigationConfig(enabled: false, refreshDuration: 0.0),
            mapUiConfig: MapUiConfig(bannerEnabled: false, snackBarEnabled: false),
            pinsConfig: PinsConfig(),
            debugLog: DebugLog()
        )
        webViewLoaderViewModel = StoreMapLoaderViewModel(
            blueDotMode: .visible,
            storeMapOptions: options,
            debugLog: options.debugLog,
            serviceLocator: serviceLocator
        )
        storeMapView = StoreMapView(webViewLoaderViewModel: webViewLoaderViewModel, options: options)
    }

    override func tearDownWithError() throws {
        storeMapView = nil
    }

    func testWKNavigationResponsePolicyWhenNavigationResponse() {
        var policy: WKNavigationResponsePolicy?
        let decisionHandler: (WKNavigationResponsePolicy) -> Void = { p in
            policy = p
        }
        let response = HTTPURLResponse.make(statusCode: 200)
        let errorResponse = MockWKNavigationResponse(response: response)

        storeMapView.webView(WKWebView(), decidePolicyFor: errorResponse, decisionHandler: decisionHandler)
        XCTAssertEqual(WKNavigationResponsePolicy.allow, policy)
    }

    func testMapEventStatusWhenNavigationResponseContainsInvalidStatusCode() {
        var policy: WKNavigationResponsePolicy?
        let decisionHandler: (WKNavigationResponsePolicy) -> Void = { p in
            policy = p
        }
        let response = HTTPURLResponse.make(statusCode: 500)
        let errorResponse = MockWKNavigationResponse(response: response)
        statusService.eventEmitterHandler = { eventEmitter in
            guard let mapStatusEventEmitter = eventEmitter as? MapStatusEventEmitter else {
                return
            }

            let dict = mapStatusEventEmitter.toDictionary()
            XCTAssertEqual(mapStatusEventEmitter.eventType, EventType.mapStatusEventEmitter)
            XCTAssertNotNil(dict["success"] as? Bool)
            XCTAssertFalse(dict["success"] as! Bool)
        }
        storeMapView.webView(WKWebView(), decidePolicyFor: errorResponse, decisionHandler: decisionHandler)
        XCTAssertEqual(WKNavigationResponsePolicy.cancel, policy)
    }

    func testMapEventStatusWhenNavigationResponseContainsInvalidURLResponse() throws {
        var policy: WKNavigationResponsePolicy?
        let decisionHandler: (WKNavigationResponsePolicy) -> Void = { p in
            policy = p
        }
        let response = URLResponse(url: URL(string: "http://sample")!,
                                   mimeType: nil,
                                   expectedContentLength: 0,
                                   textEncodingName: nil)
        let errorResponse = MockWKNavigationResponse(response: response)
        statusService.eventEmitterHandler = { eventEmitter in
            guard let mapStatusEventEmitter = eventEmitter as? MapStatusEventEmitter else {
                return
            }

            let dict = mapStatusEventEmitter.toDictionary()
            XCTAssertEqual(mapStatusEventEmitter.eventType, EventType.mapStatusEventEmitter)
            XCTAssertNotNil(dict["success"] as? Bool)
            XCTAssertFalse(dict["success"] as! Bool)
        }
        storeMapView.webView(WKWebView(), decidePolicyFor: errorResponse, decisionHandler: decisionHandler)
        XCTAssertEqual(WKNavigationResponsePolicy.cancel, policy)
    }

    func testMapEventStatusWhenMapFailsToLoad() throws {
        let error = MockWebViewError()
        statusService.eventEmitterHandler = { eventEmitter in
            guard let mapStatusEventEmitter = eventEmitter as? MapStatusEventEmitter else {
                return
            }

            let dict = mapStatusEventEmitter.toDictionary()
            XCTAssertEqual(eventEmitter.eventType, EventType.mapStatusEventEmitter)
            XCTAssertNotNil(dict["success"] as? Bool)
            XCTAssertFalse(dict["success"] as! Bool)
        }
        storeMapView.webView(
            WKWebView(),
            didFailProvisionalNavigation: StoreMapViewTests.mockNavigation,
            withError: error
        )
    }

    func testMapEventStatusWhenMapFailsWithNotConnectedToInternetToLoad() throws {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: [
                NSLocalizedDescriptionKey : "The Internet connection appears to be offline."
            ]
        )

        statusService.eventEmitterHandler = { eventEmitter in
            guard let mapStatusEventEmitter = eventEmitter as? MapStatusEventEmitter else {
                return
            }

            let dict = mapStatusEventEmitter.toDictionary()
            XCTAssertEqual(eventEmitter.eventType, EventType.mapStatusEventEmitter)
            XCTAssertNotNil(dict["success"] as? Bool)
            XCTAssertFalse(dict["success"] as! Bool)
        }
        storeMapView.webView(
            WKWebView(),
            didFailProvisionalNavigation: StoreMapViewTests.mockNavigation,
            withError: error
        )
    }

    func testMapEventStatusWhenMapFailsWithTimedOutToLoad() throws {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorTimedOut,
            userInfo: [
                NSLocalizedDescriptionKey : "The request timed out."
            ]
        )

        statusService.eventEmitterHandler = { eventEmitter in
            guard let mapStatusEventEmitter = eventEmitter as? MapStatusEventEmitter else {
                return
            }

            let dict = mapStatusEventEmitter.toDictionary()
            XCTAssertEqual(eventEmitter.eventType, EventType.mapStatusEventEmitter)
            XCTAssertNotNil(dict["success"] as? Bool)
            XCTAssertFalse(dict["success"] as! Bool)
        }
        storeMapView.webView(
            WKWebView(),
            didFailProvisionalNavigation: StoreMapViewTests.mockNavigation,
            withError: error
        )
    }

    func testMapEventStatusWhenMapFailsWithUnknowToLoad() throws {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorUnknown,
            userInfo: [
                NSLocalizedDescriptionKey : "Failed to load content."
            ]
        )

        statusService.eventEmitterHandler = { eventEmitter in
            guard let mapStatusEventEmitter = eventEmitter as? MapStatusEventEmitter else {
                return
            }

            let dict = mapStatusEventEmitter.toDictionary()
            XCTAssertEqual(eventEmitter.eventType, EventType.mapStatusEventEmitter)
            XCTAssertNotNil(dict["success"] as? Bool)
            XCTAssertFalse(dict["success"] as! Bool)
        }
        storeMapView.webView(
            WKWebView(),
            didFailProvisionalNavigation: StoreMapViewTests.mockNavigation,
            withError: error
        )
    }

    func testMapEventStatusWhenMapLoadFinish() throws {
        storeMapView.webView(WKWebView(), didFinish: StoreMapViewTests.mockNavigation)
        XCTAssert(storeMapView.isWebViewLoaded)
    }
}
