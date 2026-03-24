//
//  AssetServiceImplTests.swift
//  compass_sdk_iosTests
//
//  Created by Young Jin Ju - Vendor on 6/11/23.
//

import XCTest
import Combine
@testable import compass_sdk_ios
import IPSFramework

final class AssetServiceImplTests: XCTestCase {
    private var serviceLocator: MockServiceLocator!
    private let validAssetId = "peter123"
    private let invalidAssetId = "peter1235"
    private let validEncodedLocation = "YzAvWy0xcFcsdXFdLzE="
    private let invalidEncodedLocation = "==YzAvWy0xc=="
    private var cancellable = Set<AnyCancellable>()
    private var assetService: AssetServiceImpl!
    private var networkService: MockNetworkService!

    override func setUpWithError() throws {
        try super.setUpWithError()
        serviceLocator = MockServiceLocator()
        assetService = AssetServiceImpl(serviceLocator: serviceLocator)
        networkService = serviceLocator.getNetworkService() as? MockNetworkService
    }

    override func tearDownWithError() throws {
        serviceLocator._resetMock()
        cancellable.removeAll()
        try super.tearDownWithError()
    }

    func test_evaluateAssets_withWalmartMap_shouldGetOnCompletion() throws {
        let exp = XCTestExpectation(description: #function)
        assetService.storeId = 2280
        networkService._expectedAssetResponse = TestData.assetResponse
        assetService.evaluateAssets(
            using: [self.validAssetId],
            idType: .assets,
            pinDropType: .autoPinDropAisleLocList
        ) { points in
            XCTAssertFalse(points.isEmpty)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_evaluateAssets_withOriientmap_shouldGetOnCompletion() throws {
        let exp = XCTestExpectation(description: #function)
        let indoorPositioningService = serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService
        indoorPositioningService?.floorCoordinatesConverter = MockFloorCoordinatesConverterImpl()
        assetService = AssetServiceImpl(serviceLocator: serviceLocator)
        assetService.storeId = 2280
        networkService._expectedAssetResponse = TestData.assetResponse

        assetService.evaluateAssets(
            using: [self.validAssetId],
            idType: .assets,
            pinDropType: .autoPinDropAisleLocList
        ) { points in
            XCTAssertFalse(points.isEmpty)
            exp.fulfill()
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_evaluateAssets_withWalmartMap_shouldEmitCompassAssetStatusChanged() throws {
        let exp = XCTestExpectation(description: #function)
        var statusService = serviceLocator.getStatusService()
        assetService.storeId = 2280

        statusService.eventEmitterHandler = { eventEmitter in
            guard let locationEventEmitter = eventEmitter as? LocationEventEmitter else {
                return
            }
            XCTAssertEqual(locationEventEmitter.eventType, EventType.locationEventEmitter)
            exp.fulfill()
        }

        assetService.evaluateAssets(
            using: [self.validAssetId],
            idType: .assets,
            pinDropType: .pinAisleLoc
        ) { _ in }

        wait(for: [exp], timeout: 5.0)
    }

    func test_evaluateAssets_withWalmartMap_shouldEmitCompassAssetsStatusChanged() throws {
        let exp = XCTestExpectation(description: #function)
        var statusService = serviceLocator.getStatusService()
        assetService.storeId = 2280

        let assetPayload = AssetPayload(id: validAssetId, x: 20, y: 40, z: 0, type: "asset", aisle: "A123", allAisles: ["A123"])
        networkService._expectedAssetResponse = AssetResponse(status: "Success", errors: [], payload: assetPayload)

        statusService.eventEmitterHandler = { [weak self] eventEmitter in
            guard let pinDropEventEmitter = eventEmitter as? PinDropEventEmitter else {
                return
            }
            let dict = pinDropEventEmitter.toDictionary()
            XCTAssertNotNil(dict["mapType"] as? String)
            XCTAssertNotNil(dict["longPressed"] as? Bool)
            guard dict["mapType"] as! String == MapIdentifier.WalmartMap.rawValue,
            dict["longPressed"] as! Bool == false else {
                return
            }
            XCTAssertEqual((dict["mapType"] as! String).lowercased(), MapIdentifier.WalmartMap.rawValue.lowercased())
            XCTAssertEqual(pinDropEventEmitter.eventType, EventType.pinListEventEmitter)
            XCTAssertNotNil(dict["longPressed"] as? Bool)
            XCTAssertFalse(dict["longPressed"] as! Bool)
            XCTAssertNotNil(dict["assets"] as? HashMap)
            let assetHashMap = dict["assets"] as! HashMap
            XCTAssertNotNil(self)
            guard assetHashMap[self!.validAssetId] as? [String : Any] != nil else {
                return
            }
            let matchedAssetHashMap = assetHashMap[self!.validAssetId] as! [String : Any]
            XCTAssertNotNil(matchedAssetHashMap["assetId"] as? String)
            guard matchedAssetHashMap["assetId"] as! String == self!.validAssetId,
                  matchedAssetHashMap["success"] as! Bool == true else {
                return
            }
            XCTAssertEqual(matchedAssetHashMap["assetId"] as! String, self!.validAssetId)
            XCTAssertTrue(matchedAssetHashMap["success"] as! Bool)
            XCTAssertNotNil(matchedAssetHashMap["locations"] as? [String])
            XCTAssertFalse((matchedAssetHashMap["locations"] as! [String]).isEmpty)
            exp.fulfill()
        }

        assetService.evaluateAssets(
            using: [self.validAssetId],
            idType: .assets,
            pinDropType: .autoPinDropAisleLocList
        ) { points in
            XCTAssertFalse(points.isEmpty)
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_evaluateAssets_withWalmartMapAndInvalidAsset_shouldEmitCompassErrorStatusChanged() throws {
        let exp = XCTestExpectation(description: #function)
        let error = ErrorResponse(response: HTTPURLResponse(url: TestData.exampleURL, statusCode: 520, httpVersion: "1.1", headerFields: [:])!, error: MockNetworkServiceError.requestFailed)
        networkService._shouldFail = true
        networkService._expectedError = error

        var statusService = serviceLocator.getStatusService()
        assetService.storeId = 2280

        statusService.eventEmitterHandler = { eventEmitter in
            guard let errorEventEmitter = eventEmitter as? ErrorEventEmitter else {
                return
            }
            let dict = errorEventEmitter.toDictionary()
            XCTAssertNotNil(dict["errorCode"] as? Int)
            XCTAssertEqual((dict["errorCode"] as! Int), 520)
            exp.fulfill()
        }

        assetService.evaluateAssets(
            using: [invalidAssetId],
            idType: .assets,
            pinDropType: .autoPinDropAisleLocList
        ) { points in
            XCTAssertFalse(points.isEmpty)
        }

        wait(for: [exp], timeout: 5.0)
    }

    func test_setEventAndEvaluateAssets_withOriientMap_shouldGetOnCompletionAndDeleteAllEvents() throws {
        let exp = XCTestExpectation(description: #function)
        assetService.storeId = 2280

        let indoorPositioningService = serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService
        indoorPositioningService?.floorCoordinatesConverter = MockFloorCoordinatesConverterImpl()
        let eventModel = EventStoreModel(eventType: "Asset",
                                         eventValue: validAssetId,
                                         x: 20.0,
                                         y: 40.0,
                                         aisleLocation: "Unknown",
                                         aisleLocations: ["Unknown"])

        serviceLocator.getEventStoreService()
            .insertOrUpdateEvent(eventModel)
            .catch { _ in return Empty().eraseToAnyPublisher() }
            .flatMap { [weak self] eventModel -> AnyPublisher<Void, Never> in
                XCTAssertNotNil(eventModel)
                self?.assetService.evaluateAssets(
                    using: [self!.validAssetId],
                    idType: .assets,
                    pinDropType: .autoPinDropAisleLocList
                ) { points in
                    Log.debug("point \(points)")
                    XCTAssertFalse(points.isEmpty)
                    XCTAssertEqual(points.first!.x, 20.0)
                    XCTAssertEqual(points.first!.y, 40.0)
                    exp.fulfill()
                }
                return Just(()).eraseToAnyPublisher()
            }
            .sink {}
            .store(in: &cancellable)

        wait(for: [exp], timeout: 5.0)
    }

    func test_evaluateAisles_withWalmartMap_shouldEmitCompassAssetsStatusChanged() throws {
        let exp = XCTestExpectation(description: #function)
        var statusService = serviceLocator.getStatusService()
        assetService.storeId = 2280
        assetService.idList.removeAll()
        assetService.assetEvents.removeAll()
        assetService.idList = [validAssetId]

        statusService.eventEmitterHandler = { [weak self] eventEmitter in
            guard let pinDropEventEmitter = eventEmitter as? PinDropEventEmitter else {
                return
            }

            let dict = pinDropEventEmitter.toDictionary()
            XCTAssertNotNil(dict["mapType"] as? String)
            XCTAssertNotNil(dict["longPressed"] as? Bool)
            guard dict["mapType"] as! String == MapIdentifier.WalmartMap.rawValue,
            dict["longPressed"] as! Bool == true else {
                return
            }
            XCTAssertEqual(pinDropEventEmitter.eventType, EventType.pinListEventEmitter)
            XCTAssert(dict["longPressed"] as! Bool)
            XCTAssertEqual((dict["mapType"] as! String).lowercased(), MapIdentifier.WalmartMap.rawValue.lowercased())
            XCTAssertNotNil(dict["assets"] as? HashMap)
            let assetHashMap = dict["assets"] as! HashMap
            XCTAssertNotNil(self)
            XCTAssertNotNil(assetHashMap[self!.validAssetId] as? [String : Any])
            guard let matchedAssetHashMap = assetHashMap[self!.validAssetId] as? [String : Any] else {
                return
            }
            XCTAssertNotNil(matchedAssetHashMap["assetId"] as? String)
            guard matchedAssetHashMap["assetId"] as! String == self!.validAssetId,
                  matchedAssetHashMap["success"] as! Bool == true else {
                return
            }
            XCTAssertEqual(matchedAssetHashMap["assetId"] as! String, self!.validAssetId)
            XCTAssertTrue(matchedAssetHashMap["success"] as! Bool)
            XCTAssertNotNil(matchedAssetHashMap["locations"] as? [String])
            XCTAssertFalse((matchedAssetHashMap["locations"] as! [String]).isEmpty)
//>>>>>>> Stashed changes
            exp.fulfill()
        }

        assetService.evaluateAisles(
            using: validAssetId,
            pinDropType: .manualPinDropAisleLocList,
            position: CGPoint(x: 20.0, y: 40.0)
        ) { _ in }

        wait(for: [exp], timeout: 5.0)
    }

    func test_evaluateAisles_withWalmartMapAndInvalidAsset_shouldEmitCompassErrorStatusChanged() throws {
        let exp = XCTestExpectation(description: #function)
        var statusService = serviceLocator.getStatusService()
        let error = ErrorResponse(response: HTTPURLResponse(url: TestData.exampleURL, statusCode: 520, httpVersion: "1.1", headerFields: [:])!, error: MockNetworkServiceError.requestFailed)
        networkService._shouldFail = true
        networkService._expectedError = error
        assetService.storeId = 228022802280
        assetService.idList.removeAll()
        assetService.assetEvents.removeAll()
        assetService.idList = [invalidAssetId]
        
        statusService.eventEmitterHandler = { eventEmitter in
            guard let errorEventEmitter = eventEmitter as? ErrorEventEmitter else {
                return
            }

            let dict = errorEventEmitter.toDictionary()
            XCTAssertNotNil(dict["errorCode"] as? Int)
            XCTAssertEqual((dict["errorCode"] as! Int), 520)
            exp.fulfill()
        }

        assetService.evaluateAisles(
            using: invalidAssetId,
            pinDropType: .manualPinDropAisleLocList,
            position: CGPoint(x: 20.0, y: 40.0)
        ) { _ in }

        wait(for: [exp], timeout: 5.0)
    }

    func test_evaluateAisles_withOriientmap_shouldEmitCompassAssetsStatusChanged() throws {
        let exp = expectation(description: #function)

        let indoorPositioningService = serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService
        indoorPositioningService?.floorCoordinatesConverter = MockFloorCoordinatesConverterImpl()

        let assetPayload = AssetPayload(id: validAssetId, x: 20, y: 40, z: 0, type: "asset", aisle: "A123", allAisles: ["A123"])
        networkService._expectedAssetResponse = AssetResponse(status: "Success", errors: [], payload: assetPayload)

        var statusService = serviceLocator.getStatusService()
        statusService.eventEmitterHandler = { eventEmitter in
            guard let pinDropEventEmitter = eventEmitter as? PinDropEventEmitter else {
                return
            }
            let dict = pinDropEventEmitter.toDictionary()
            XCTAssertEqual(pinDropEventEmitter.eventType, EventType.pinListEventEmitter)
            XCTAssert(dict["longPressed"] as! Bool)
            XCTAssertEqual((dict["mapType"] as! String).lowercased(), MapIdentifier.WalmartMap.rawValue.lowercased())
            XCTAssertNotNil(dict["assets"] as? HashMap)
            let assetHashMap = dict["assets"] as! HashMap
            XCTAssertNotNil(assetHashMap[self.validAssetId])
            let matchedAssetHashMap = assetHashMap[self.validAssetId] as! [String : Any]
            XCTAssertNotNil(matchedAssetHashMap["assetId"] as? String)
            XCTAssertEqual(matchedAssetHashMap["assetId"] as! String, self.validAssetId)
            XCTAssertTrue(matchedAssetHashMap["success"] as! Bool)
            XCTAssertFalse((matchedAssetHashMap["locations"] as! [String]).isEmpty)
            exp.fulfill()
        }

        assetService.storeId = 2280
        assetService.idType = .assets
        assetService.idList.removeAll()
        assetService.assetEvents.removeAll()
        assetService.idList = [validAssetId]
        assetService.evaluateAisles(
            using: validAssetId,
            pinDropType: .manualPinDropAisleLocList,
            position: CGPoint(x: 20.0, y: 40.0)
        ) { _ in }

        waitForExpectations(timeout: 4.0)
    }

    func test_evaluateAisles_withOriientmapAndInvalidAsset_shouldEmitCompassErrorStatusChanged() throws {
        let exp = XCTestExpectation(description: #function)
        let error = ErrorResponse(response: HTTPURLResponse(url: TestData.exampleURL, statusCode: 520, httpVersion: "1.1", headerFields: [:])!, error: MockNetworkServiceError.requestFailed)
        networkService._shouldFail = true
        networkService._expectedError = error

        var statusService = serviceLocator.getStatusService()
        assetService.idList.removeAll()
        assetService.assetEvents.removeAll()
        assetService.idList = [invalidAssetId]
        assetService.storeId = 228022802280

        statusService.eventEmitterHandler = { eventEmitter in
            guard let errorEventEmitter = eventEmitter as? ErrorEventEmitter else {
                return
            }

            let dict = errorEventEmitter.toDictionary()
            XCTAssertNotNil(dict["errorCode"] as? Int)
            XCTAssertEqual((dict["errorCode"] as! Int), 520)
            exp.fulfill()
        }

        assetService.evaluateAisles(
            using: invalidAssetId,
            pinDropType: .manualPinDropAisleLocList,
            position: CGPoint(x: 20.0, y: 40.0)
        ) { _ in }

        wait(for: [exp], timeout: 5.0)
    }

    func test_evaluateAssets_withWalmartMapAndGenericType_shouldGetOnCompletion() throws {
        let exp = XCTestExpectation(description: #function)
        assetService.storeId = 2280

        assetService.evaluateAssets(
            using: [validEncodedLocation],
            idType: .generic,
            pinDropType: .autoPinDropAisleLocList
        ) { points in
            XCTAssertFalse(points.isEmpty)
            exp.fulfill()
        }
        
        wait(for: [exp], timeout: 2.0)
    }

    func test_evaluateAssets_withWalmartMapAndGenericType_shouldEmitCompassAssetStatusChanged() throws {
        let exp = XCTestExpectation(description: #function)
        var statusService = serviceLocator.getStatusService()
        assetService.storeId = 2280

        statusService.eventEmitterHandler = { eventEmitter in
            guard let locationEventEmitter = eventEmitter as? LocationEventEmitter else {
                return
            }
            XCTAssertEqual(locationEventEmitter.eventType, EventType.locationEventEmitter)
//            XCTAssert(aisle.isEmptyOrWhitespace())
            exp.fulfill()
        }

        assetService.evaluateAssets(
            using: [validEncodedLocation],
            idType: .generic,
            pinDropType: .pinAisleLoc
        ) { _ in }

        wait(for: [exp], timeout: 3)
    }

    func test_evaluateAssets_withWalmartMapAndGenericType_shouldEmitCompassAssetsStatusChanged() throws {
        let exp = XCTestExpectation(description: #function)
        var statusService = serviceLocator.getStatusService()
        assetService.storeId = 2280

        statusService.eventEmitterHandler = { eventEmitter in
            guard let pinDropEventEmitter = eventEmitter as? PinDropEventEmitter else {
                return
            }
            let dict = pinDropEventEmitter.toDictionary()
            XCTAssertNotNil(dict["mapType"] as? String)
            XCTAssertNotNil(dict["longPressed"] as? Bool)
            guard dict["mapType"] as! String == MapIdentifier.WalmartMap.rawValue,
            dict["longPressed"] as! Bool == false else {
                return
            }
            exp.fulfill()
        }

        assetService.evaluateAssets(
            using: [validEncodedLocation],
            idType: .generic,
            pinDropType: .autoPinDropAisleLocList
        ) { points in
            XCTAssertFalse(points.isEmpty)
        }

        wait(for: [exp], timeout: 2.5)
    }

    func test_evaluateAssets_withWalmartMapAndGenericTypeAndInvalidId_shouldNotSetAssetEvents() throws {
        assetService.storeId = 2280

        assetService.evaluateAssets(
            using: [invalidEncodedLocation],
            idType: .generic,
            pinDropType: .autoPinDropAisleLocList
        ) { _ in }

        XCTAssert(assetService.assetEvents.isEmpty)
    }

    func test_evaluateAisles_withWalmartMapAndGenericType_shouldEmitCompassAssetsStatusChanged() throws {
        let exp = XCTestExpectation(description: #function)
        var statusService = serviceLocator.getStatusService()
        assetService.storeId = 2280
        assetService.idList.removeAll()
        assetService.assetEvents.removeAll()
        assetService.idList = [validEncodedLocation]
        assetService.idType = .generic

        statusService.eventEmitterHandler = { eventEmitter in
            guard let pinDropEventEmitter = eventEmitter as? PinDropEventEmitter else {
                return
            }
            let dict = pinDropEventEmitter.toDictionary()
            XCTAssertNotNil(dict["mapType"] as? String)
            XCTAssertNotNil(dict["longPressed"] as? Bool)
            guard dict["mapType"] as! String == MapIdentifier.WalmartMap.rawValue,
            dict["longPressed"] as! Bool == true else {
                return
            }
            XCTAssertEqual(pinDropEventEmitter.eventType, EventType.pinListEventEmitter)
            XCTAssert(dict["longPressed"] as! Bool)
            XCTAssertEqual((dict["mapType"] as! String).lowercased(), MapIdentifier.WalmartMap.rawValue.lowercased())
            XCTAssertNotNil(dict["encodedLocation"] as? String)
            XCTAssertEqual(dict["encodedLocation"] as! String, "YzAvW0EsS10vMQ==")
            exp.fulfill()
        }
    
        assetService.evaluateAisles(
            using: validEncodedLocation,
            pinDropType: .manualPinDropAisleLocList,
            position: CGPoint(x: 20.0, y: 40.0)
        ) { _ in }

        wait(for: [exp], timeout: 2.0)
    }

    func test_evaluateAisles_withOriientmapAndGenericType_shouldEmitCompassAssetsStatusChanged() throws {
        let exp = XCTestExpectation(description: #function)
        var statusService = serviceLocator.getStatusService()
        let indoorPositioningService = serviceLocator.getIndoorPositioningService() as? MockIndoorPositioningService
        indoorPositioningService?.floorCoordinatesConverter = MockFloorCoordinatesConverterImpl()
        assetService.storeId = 2280
        assetService.idList.removeAll()
        assetService.assetEvents.removeAll()
        assetService.idList = [validEncodedLocation]
        assetService.idType = .generic

        statusService.eventEmitterHandler = { eventEmitter in
            guard let pinDropEventEmitter = eventEmitter as? PinDropEventEmitter else {
                return
            }
            let dict = pinDropEventEmitter.toDictionary()
            XCTAssertNotNil(dict["mapType"] as? String)
            XCTAssertNotNil(dict["longPressed"] as? Bool)
            guard dict["mapType"] as! String == MapIdentifier.WalmartMap.rawValue,
            dict["longPressed"] as! Bool == true else {
                return
            }
            XCTAssertEqual(pinDropEventEmitter.eventType, EventType.pinListEventEmitter)
            XCTAssert(dict["longPressed"] as! Bool)
            XCTAssertEqual((dict["mapType"] as! String).lowercased(), MapIdentifier.WalmartMap.rawValue.lowercased())
            XCTAssertNotNil(dict["encodedLocation"] as? String)
            XCTAssertEqual(dict["encodedLocation"] as! String, "YzAvW0EsS10vMQ==")
            exp.fulfill()
        }

        assetService.evaluateAisles(
            using: validEncodedLocation,
            pinDropType: .manualPinDropAisleLocList,
            position: CGPoint(x: 20.0, y: 40.0)
        ) { _ in }

        wait(for: [exp], timeout: 2.0)
    }
}
