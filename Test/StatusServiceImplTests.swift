//
//  StatusServiceTests.swift
//  compass_sdk_iosTests
//
//  Created by Young Jin Ju - Vendor on 4/3/23.
//

@testable import compass_sdk_ios
import XCTest

final class statusServiceTests: XCTestCase {
    private var statusService: StatusServiceImpl!

    override func setUpWithError() throws {
        statusService = StatusServiceImpl()
        try super.setUpWithError()
    }

    override func tearDownWithError() throws {
        statusService = nil
        try super.tearDownWithError()
    }
    
    func testEmitCompassMapEvent() {
        XCTAssertNil(statusService.eventEmitterHandler)

        statusService.eventEmitterHandler = { eventEmitter in
            guard let mapStatusEventEmitter = eventEmitter as? MapStatusEventEmitter else {
                return
            }
            let dict = mapStatusEventEmitter.toDictionary()
            XCTAssertNotNil(dict["success"] as? Bool)
            XCTAssertNotNil(dict["errorCode"] as? String)
            XCTAssertNotNil(dict["success"])
            XCTAssertEqual(dict["errorCode"] as? String, "")
            XCTAssertEqual(dict["errorMessage"] as? String, "")
            XCTAssertEqual(dict["errorMessage"] as? String, "")
            XCTAssertEqual(mapStatusEventEmitter.eventType, EventType.mapStatusEventEmitter)
       }

        statusService.emitMapStatusEvent(isSuccess: false)
    }

    func testEmitAssetsStatusEvent_withWalmartAutoPinDrop() {
        let assetId = TestData.validAssetId
        let storeId = 2280
        let pinDropType = PinDropType.autoPinDropAisleLocList
        let mapType = MapIdentifier.WalmartMap.rawValue
        let assetEvents = [assetId: TestData.assetEvent1]
        let idType = PinDropMethod.assets
        let encodedLocation = PinDropEventEmitter.encodeLocation(assetEvents: assetEvents, storeId: storeId)

        XCTAssertNil(statusService.eventEmitterHandler)

        statusService.eventEmitterHandler = { [weak self] evenEmitter in
            guard let pinDropEventEmitter = evenEmitter as? PinDropEventEmitter else {
                return
            }

            let dict = pinDropEventEmitter.toDictionary()
            XCTAssertEqual((dict["mapType"] as! String).lowercased(), mapType.lowercased())
            XCTAssertEqual(dict["longPressed"] as! Bool, pinDropType == .manualPinDropAisleLocList)
            XCTAssertEqual(dict["encodedLocation"] as! String, encodedLocation)
            XCTAssertEqual(dict["idType"] as! String, idType.rawValue)
            XCTAssertEqual(pinDropEventEmitter.eventType, EventType.pinListEventEmitter)
            let assetHashMap = dict["assets"] as! HashMap
            XCTAssertNotNil(self)
            guard assetHashMap[assetId] as? [String : Any] != nil else {
                return
            }
            let matchedAssetHashMap = assetHashMap[assetId] as! [String : Any]
            XCTAssertNotNil(matchedAssetHashMap["assetId"] as? String)
            guard (matchedAssetHashMap["assetId"] as! String) == assetId,
                  matchedAssetHashMap["success"] as! Bool == true else {
                return
            }
            XCTAssertEqual((matchedAssetHashMap["assetId"] as! String), assetId)
            XCTAssertTrue(matchedAssetHashMap["success"] as! Bool)
            XCTAssertNotNil(matchedAssetHashMap["locations"] as? [String])
            XCTAssertFalse((matchedAssetHashMap["locations"] as! [String]).isEmpty)
        }

        statusService.emitPinDropEvent(using: assetId,
                                       storeId: storeId,
                                       pinDropType: pinDropType,
                                       assetEvents: assetEvents,
                                       idType: idType)
    }

    func testEmitAssetsStatusEvent_withWalmartManualPinDrop() {
        let assetId = TestData.validAssetId
        let storeId = 2280
        let pinDropType = PinDropType.manualPinDropAisleLocList
        let mapType = MapIdentifier.WalmartMap.rawValue
        let assetEvents = [assetId: TestData.assetEvent1]
        let idType = PinDropMethod.assets
        let encodedLocation = PinDropEventEmitter.encodeLocation(assetEvents: assetEvents, storeId: storeId)

        XCTAssertNil(statusService.eventEmitterHandler)

        statusService.eventEmitterHandler = { evenEmitter in
            guard let pinDropEventEmitter = evenEmitter as? PinDropEventEmitter else {
                return
            }

            let dict = pinDropEventEmitter.toDictionary()
            XCTAssertEqual((dict["mapType"] as! String).lowercased(), mapType.lowercased())
            XCTAssertEqual(dict["longPressed"] as! Bool, pinDropType == .manualPinDropAisleLocList)
            XCTAssertEqual(dict["encodedLocation"] as! String, encodedLocation)
            XCTAssertEqual(dict["idType"] as! String, idType.rawValue)
            XCTAssertEqual(pinDropEventEmitter.eventType, EventType.pinListEventEmitter)
            let assetHashMap = dict["assets"] as! HashMap
            guard assetHashMap[assetId] as? [String : Any] != nil else {
                return
            }
            let matchedAssetHashMap = assetHashMap[assetId] as! [String : Any]
            XCTAssertNotNil(matchedAssetHashMap["assetId"] as? String)
            guard (matchedAssetHashMap["assetId"] as! String) == assetId,
                  matchedAssetHashMap["success"] as! Bool == true else {
                return
            }
            XCTAssertEqual((matchedAssetHashMap["assetId"] as! String), assetId)
            XCTAssertTrue(matchedAssetHashMap["success"] as! Bool)
            XCTAssertNotNil(matchedAssetHashMap["locations"] as? [String])
            XCTAssertFalse((matchedAssetHashMap["locations"] as! [String]).isEmpty)
//>>>>>>> Stashed changes
        }
        statusService.emitPinDropEvent(using: assetId,
                                            storeId: storeId,
                                            pinDropType: pinDropType,
                                            assetEvents: assetEvents,
                                            idType: idType)
    }


    func testEmitAssetsStatusEvent_withOriientAutoPinDrop() {
        let assetId = TestData.validAssetId
        let storeId = 2280
        let pinDropType = PinDropType.autoPinDropAisleLocList
        let mapType = MapIdentifier.WalmartMap.rawValue
        let assetEvents = [assetId: TestData.assetEvent1]
        let idType = PinDropMethod.assets
        let encodedLocation = PinDropEventEmitter.encodeLocation(assetEvents: assetEvents, storeId: storeId)

        XCTAssertNil(statusService.eventEmitterHandler)

        statusService.eventEmitterHandler = { [weak self] eventEmitter in
            guard let pinDropEventEmitter = eventEmitter as? PinDropEventEmitter else {
                return
            }

            let dict = pinDropEventEmitter.toDictionary()
            XCTAssertEqual((dict["mapType"] as! String).lowercased(), mapType.lowercased())
            XCTAssertEqual(dict["longPressed"] as! Bool, pinDropType == .manualPinDropAisleLocList)
            XCTAssertEqual(dict["encodedLocation"] as! String, encodedLocation)
            XCTAssertEqual(dict["idType"] as! String, idType.rawValue)
            XCTAssertEqual(pinDropEventEmitter.eventType, EventType.pinListEventEmitter)
            let assetHashMap = dict["assets"] as! HashMap
            XCTAssertNotNil(self)
            guard assetHashMap[assetId] as? [String : Any] != nil else {
                return
            }
            let matchedAssetHashMap = assetHashMap[assetId] as! [String : Any]
            XCTAssertNotNil(matchedAssetHashMap["assetId"] as? String)
            guard (matchedAssetHashMap["assetId"] as! String) == assetId,
                  matchedAssetHashMap["success"] as! Bool == true else {
                return
            }
            XCTAssertEqual((matchedAssetHashMap["assetId"] as! String), assetId)
            XCTAssertTrue(matchedAssetHashMap["success"] as! Bool)
            XCTAssertNotNil(matchedAssetHashMap["locations"] as? [String])
            XCTAssertFalse((matchedAssetHashMap["locations"] as! [String]).isEmpty)
        }
        statusService.emitPinDropEvent(using: assetId,
                                            storeId: storeId,
                                            pinDropType: pinDropType,
                                            assetEvents: assetEvents,
                                            idType: idType)
    }

    func testEmitAssetsStatusEvent_withOriientManualPinDrop() {
        let assetId = TestData.validAssetId
        let storeId = 2280
        let pinDropType = PinDropType.manualPinDropAisleLocList
        let mapType = MapIdentifier.WalmartMap.rawValue
        let assetEvents = [assetId: TestData.assetEvent1]
        let idType = PinDropMethod.assets
        let encodedLocation = PinDropEventEmitter.encodeLocation(assetEvents: assetEvents, storeId: storeId)

        XCTAssertNil(statusService.eventEmitterHandler)

        statusService.eventEmitterHandler = { [weak self] eventEmitter in
            guard let pinDropEventEmitter = eventEmitter as? PinDropEventEmitter else {
                return
            }
            let dict = pinDropEventEmitter.toDictionary()
            XCTAssertEqual((dict["mapType"] as! String).lowercased(), mapType.lowercased())
            XCTAssertEqual(dict["longPressed"] as! Bool, pinDropType == .manualPinDropAisleLocList)
            XCTAssertEqual(dict["encodedLocation"] as! String, encodedLocation)
            XCTAssertEqual(dict["idType"] as! String, idType.rawValue)
            XCTAssertEqual(pinDropEventEmitter.eventType, EventType.pinListEventEmitter)
            let assetHashMap = dict["assets"] as! HashMap
            XCTAssertNotNil(self)
            guard assetHashMap[assetId] as? [String : Any] != nil else {
                return
            }
            let matchedAssetHashMap = assetHashMap[assetId] as! [String : Any]
            XCTAssertNotNil(matchedAssetHashMap["assetId"] as? String)
            guard (matchedAssetHashMap["assetId"] as! String) == assetId,
                  matchedAssetHashMap["success"] as! Bool == true else {
                return
            }
            XCTAssertEqual((matchedAssetHashMap["assetId"] as! String), assetId)
            XCTAssertTrue(matchedAssetHashMap["success"] as! Bool)
            XCTAssertNotNil(matchedAssetHashMap["locations"] as? [String])
            XCTAssertFalse((matchedAssetHashMap["locations"] as! [String]).isEmpty)
//>>>>>>> Stashed changes
        }
        statusService.emitPinDropEvent(using: assetId,
                                            storeId: storeId,
                                            pinDropType: pinDropType,
                                            assetEvents: assetEvents,
                                            idType: idType)
    }

    func testEmitAislesStatusEvent() {
        let pinDropType = PinDropType.manualPinDropAisleLocList
        let mapType = MapIdentifier.WalmartMap
        let pins = TestData.pins
        
        XCTAssertNil(statusService.eventEmitterHandler)

        statusService.eventEmitterHandler = { eventEmitter in
            guard let pinDropEventEmitter = eventEmitter as? PinDropEventEmitter else {
                return
            }
            let dict = pinDropEventEmitter.toDictionary()
            XCTAssertEqual((dict["mapType"] as! String).lowercased(), MapIdentifier.WalmartMap.rawValue.lowercased())
            XCTAssertTrue(dict["longPressed"] as! Bool)
            XCTAssertNotNil(dict["encodedLocation"] as! String)
            XCTAssertEqual(dict["idType"] as! String, PinDropMethod.assets.rawValue.lowercased())
            XCTAssertEqual(pinDropEventEmitter.eventType, EventType.aislesPinListEventEmitter)
            let pinHashMap = dict["pins"] as! [HashMap]
            XCTAssertNotNil(self)
            XCTAssertEqual((pinHashMap[0]["id"] as! String), pins[0].id)
            XCTAssertNotNil(pinHashMap[0]["location"] as? [String: String])
            XCTAssertNotNil(pinHashMap[0]["success"] as? Bool)
        }
        
        statusService.emitAislesPinDropEvent(pinDropType: pinDropType, mapType: mapType, pins: pins)
    }

    func testEmitPinEvent() throws {
        let assetLocation = "A101"
        XCTAssertNil(statusService.eventEmitterHandler)

        statusService.eventEmitterHandler = { evenEmitter in
            guard let locationEventEmitter = evenEmitter as? LocationEventEmitter else {
                return
            }
            XCTAssertEqual(locationEventEmitter.location, assetLocation)
            XCTAssertEqual(locationEventEmitter.eventType, EventType.locationEventEmitter)
        }
        statusService.emitLocationEvent(assetLocation: assetLocation)
    }
    
    func testEmitStatusAddEvent() throws {
        let description = "event described"
        
        XCTAssertNil(statusService.eventEmitterHandler)

        statusService.eventEmitterHandler = { eventEmitter in
            guard let eventEmitterDescription = eventEmitter as? EventEmitterDescription else {
                return
            }
            XCTAssertEqual(eventEmitterDescription.description, description )
            XCTAssertEqual(eventEmitterDescription.eventType, EventType.bootstrapEventEmitter)
        }
        statusService.emitBootstrapEvent(description: description)
    }

    func testEmitMapStatusEvent() throws {
        let description = "event described"

        XCTAssertNil(statusService.eventEmitterHandler)

        statusService.eventEmitterHandler = { eventEmitter in
            guard let eventEmitterDescription = eventEmitter as? EventEmitterDescription else {
                return
            }
            XCTAssertEqual(eventEmitterDescription.description, description )
            XCTAssertEqual(eventEmitterDescription.eventType, .showMapEventEmitter)
        }

        statusService.emitMapStatusEvent(description: description)
    }
    
    func testEmitErrorStatusEvent() throws {
        let error = ErrorResponse(errorCode: 404, error: MockNetworkServiceError.requestFailed, localizedDescription: "This is a mocked error")
        let compassErrorType = CompassErrorType.unsuccessfulHTTPStatusCode
        let isInitError = false
        
        XCTAssertNil(statusService.eventEmitterHandler)

       statusService.eventEmitterHandler = { eventEmitter in
           guard let errorEventEmitter = eventEmitter as? ErrorEventEmitter else{
               return
           }
           XCTAssertEqual(errorEventEmitter.errorCode, 404 )
           XCTAssertEqual(errorEventEmitter.errorDescription, error.localizedDescription)
           XCTAssertEqual(errorEventEmitter.compassErrorType, compassErrorType.rawValue)
           XCTAssertEqual(errorEventEmitter.eventType, EventType.errorEventEmitter )
        }
        
        statusService.emitErrorStatusEvent(using: error, compassErrorType: compassErrorType, isInitError: isInitError)
    }

    func testEmitProgressEvent() throws {
        let calibrationProgress = Float(77)
        let isCalibrationGestureNeeded = false
        let positioningProgress = Float(33)
        let isPositionLocked = false
        let compassPositioningState = PositioningStateEventEmitter(eventType: .positioningStateEventEmitter, isCalibrationNeeded: isCalibrationGestureNeeded,
                                                              isPositioningActive: positioningProgress > 0 && positioningProgress < 100,
                                                              isPositionLocked: isPositionLocked,
                                                              calibrationProgress: calibrationProgress,
                                                              positioningProgress: positioningProgress)
        XCTAssertNil(statusService.eventEmitterHandler)

        statusService.eventEmitterHandler = { eventEmitter in
            guard let positioningStateEventEmitter = eventEmitter as? PositioningStateEventEmitter else {
                return
            }
            XCTAssertEqual(positioningStateEventEmitter.isCalibrationNeeded, compassPositioningState.isCalibrationNeeded)
            XCTAssertEqual(positioningStateEventEmitter.isPositioningActive, compassPositioningState.isPositioningActive)
            XCTAssertEqual(positioningStateEventEmitter.isPositionLocked, compassPositioningState.isPositionLocked)
            XCTAssertEqual(positioningStateEventEmitter.calibrationProgress, compassPositioningState.calibrationProgress)
            XCTAssertEqual(positioningStateEventEmitter.positioningProgress, compassPositioningState.positioningProgress)
            XCTAssertEqual(positioningStateEventEmitter.eventType, .positioningStateEventEmitter)
        }
        
        statusService.emitPositionStatusEvent(calibrationProgress: calibrationProgress,
                                        isCalibrationGestureNeeded: isCalibrationGestureNeeded,
                                        positioningProgress: positioningProgress,
                                        isPositionLocked: isPositionLocked)
    }

    func testEmitProgressEvent_withPositionLocked() throws {
        let calibrationProgress = Float(77)
        let isCalibrationGestureNeeded = false
        let positioningProgress = Float(33)
        let isPositionLocked = true
        let compassPositioningState = PositioningStateEventEmitter(eventType: .positioningStateEventEmitter, isCalibrationNeeded: isCalibrationGestureNeeded,
                                                              isPositioningActive: positioningProgress > 0 && positioningProgress < 100,
                                                              isPositionLocked: isPositionLocked,
                                                              calibrationProgress: calibrationProgress,
                                                              positioningProgress: positioningProgress)
        XCTAssertNil(statusService.eventEmitterHandler)

        statusService.eventEmitterHandler = { eventEmitter in
            guard let positioningStateEventEmitter = eventEmitter as? PositioningStateEventEmitter else {
                return
            }
            XCTAssertEqual(positioningStateEventEmitter.isCalibrationNeeded, compassPositioningState.isCalibrationNeeded)
            XCTAssertEqual(positioningStateEventEmitter.isPositioningActive, compassPositioningState.isPositioningActive)
            XCTAssertEqual(positioningStateEventEmitter.isPositionLocked, compassPositioningState.isPositionLocked)
            XCTAssertEqual(positioningStateEventEmitter.calibrationProgress, compassPositioningState.calibrationProgress)
            XCTAssertEqual(positioningStateEventEmitter.positioningProgress, compassPositioningState.positioningProgress)
            XCTAssertEqual(positioningStateEventEmitter.eventType, .positioningStateEventEmitter)
        }
        
        statusService.emitPositionStatusEvent(calibrationProgress: calibrationProgress,
                                        isCalibrationGestureNeeded: isCalibrationGestureNeeded,
                                        positioningProgress: positioningProgress,
                                        isPositionLocked: isPositionLocked)
    }

    func testEmitErrorStatusEvent_401() {
        let error = ErrorResponse(errorCode: 401, error: MockNetworkServiceError.requestFailed, localizedDescription: "This is a mocked error with code 401")
        let isInitError = false
        
        XCTAssertNil(statusService.eventEmitterHandler)

       statusService.eventEmitterHandler = { eventEmitter in
           guard let errorEventEmitter = eventEmitter as? ErrorEventEmitter else {
               return
           }
           XCTAssertEqual(errorEventEmitter.errorCode, error.errorCode )
           XCTAssertEqual(errorEventEmitter.errorDescription, error.localizedDescription)
           XCTAssertEqual(errorEventEmitter.compassErrorType, CompassErrorType.unsuccessfulHTTPStatusCode.rawValue)
           XCTAssertEqual(errorEventEmitter.eventType, .errorEventEmitter)
        }
        
        statusService.emitErrorStatusEvent(for: error, isInitError: isInitError)
    }
    
    func testEmitErrorStatusEvent_over500() {
        let error = ErrorResponse(errorCode: 500, error: MockNetworkServiceError.requestFailed, localizedDescription: "This is a mocked error with its code 500 or over")
        let isInitError = false

        XCTAssertNil(statusService.eventEmitterHandler)

        statusService.eventEmitterHandler = { eventEmitter in
            guard let errorEventEmitter = eventEmitter as? ErrorEventEmitter else {
                return
            }

            XCTAssertEqual(errorEventEmitter.errorCode, error.errorCode )
            XCTAssertEqual(errorEventEmitter.errorDescription, error.localizedDescription )
            XCTAssertEqual(errorEventEmitter.compassErrorType, CompassErrorType.unsuccessfulHTTPStatusCode.rawValue)
            XCTAssertEqual(errorEventEmitter.eventType, .errorEventEmitter)
        }

        statusService.emitErrorStatusEvent(for: error, isInitError: isInitError)
    }
    func testEmitErrorStatusEvent_otherErrors() {
        let error = ErrorResponse(errorCode: 499, error: MockNetworkServiceError.requestFailed, localizedDescription: "This is a mocked error for default")
        let isInitError = false

        XCTAssertNil(statusService.eventEmitterHandler)

        statusService.eventEmitterHandler = { eventEmitter in
            guard let errorEventEmitter = eventEmitter as? ErrorEventEmitter else {
                return
            }
            XCTAssertEqual(errorEventEmitter.errorCode, error.errorCode )
            XCTAssertEqual(errorEventEmitter.errorDescription, error.localizedDescription )
            XCTAssertEqual(errorEventEmitter.compassErrorType, CompassErrorType.unsuccessfulHTTPStatusCode.rawValue)
            XCTAssertEqual(errorEventEmitter.eventType, .errorEventEmitter)
        }

        statusService.emitErrorStatusEvent(for: error, isInitError: isInitError)
    }
    
    func testPositioningStateEventEmitterDescription() {
        let emitter = PositioningStateEventEmitter(
            eventType: .positioningStateEventEmitter,
            isCalibrationNeeded: true,
            isPositioningActive: false,
            isPositionLocked: true,
            calibrationProgress: 42.5,
            positioningProgress: 99.9
        )
        let desc = emitter.description
        XCTAssertTrue(desc.contains("CalibrationProgress: 42.50"))
        XCTAssertTrue(desc.contains("PositioningProgress: 99.90"))
        XCTAssertTrue(desc.contains("CalibrationNeeded: YES"))
        XCTAssertTrue(desc.contains("IsPositioning: NO"))
        XCTAssertTrue(desc.contains("IsLocked: YES"))
    }
    
    func testEmitUpdateEventList() {
        let expectation = expectation(description: #function)
        let testDescription = "Test update event list description"
        statusService.eventEmitterHandler = { eventEmitter in
            guard let eventEmitterDescription = eventEmitter as? EventEmitterDescription else {
                XCTFail("Expected EventEmitterDescription")
                return
            }
            XCTAssertEqual(eventEmitterDescription.eventType, EventType.updateEventListEventEmitter)
            XCTAssertEqual(eventEmitterDescription.description, testDescription)
            expectation.fulfill()
        }
        statusService.emitUpdateEventList(description: testDescription)
        waitForExpectations(timeout: 2.0)
    }

    func testEmitPinClickedEvent_EmitsWithMatchingIndex() {
        // Arrange
        let pins = [
            Pin(type: .aisleSection, id: 1, zone: "A", aisle: 1, section: "1"),
            Pin(type: .aisleSection, id: 2, zone: "B", aisle: 2, section: "2")
        ]
        UserDefaults.standard.setCustomObject(pins, forKey: UserDefaultsKey.pinList.rawValue)

        let expectation = expectation(description: #function)
        statusService.eventEmitterHandler = { eventEmitter in
            guard let pinClickedEmitter = eventEmitter as? PinClickedEventEmitter else {
                XCTFail("Expected PinClickedEventEmitter")
                return
            }
            XCTAssertEqual(pinClickedEmitter.eventType, .pinClickedEventEmitter)
            XCTAssertEqual(pinClickedEmitter.zone, "B")
            XCTAssertEqual(pinClickedEmitter.aisle, 2)
            XCTAssertEqual(pinClickedEmitter.section, 2)
            XCTAssertEqual(pinClickedEmitter.id, "1") // index of the matching pin
            expectation.fulfill()
        }

        // Act
        statusService.emitPinClickedEvent(zone: "B", aisle: 2, section: 2)

        // Assert
        waitForExpectations(timeout: 2.0)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: UserDefaultsKey.pinList.rawValue)
    }

    func testEmitPointOfInterestEvent_EmitsEvent() {
        let expectation = expectation(description: #function)
        let poi = PointsOfInterest(id: 1, name: "Test POI", iconURL: nil, floor: "1", index: 0, minX: 0, maxX: 1, minY: 0, maxY: 1)

        statusService.eventEmitterHandler = { eventEmitter in
            guard let poiEmitter = eventEmitter as? PointOfInteresetEmitter else {
                XCTFail("Expected PointOfInteresetEmitter")
                return
            }
            XCTAssertEqual(poiEmitter.eventType, .pointOfInterestEventEmitter)
            XCTAssertFalse(poiEmitter.description.isEmpty)
            expectation.fulfill()
        }

        statusService.emitPointOfInterestEvent(PointOfInterest: [poi])
        waitForExpectations(timeout: 2.0)
    }
}
