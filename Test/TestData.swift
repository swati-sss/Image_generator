//
//  TestData.swift
//  compass_sdk_iosTests
//
//  Created by Young Jin Ju - Vendor on 4/13/23.
//

import Foundation
@testable import compass_sdk_ios

enum TestError: Error {
    case generic
}

struct TestData {
    static let assetResponse = AssetResponse(status: "",
                                             errors: [],
                                             payload: assetPayload)

    static let assetResponseForGeneric = AssetResponse(status: "",
                                             errors: [],
                                             payload: assetPayloadForGeneric)

    static let assetPayload = AssetPayload(
        id: "fetched asset ID",
        x: 10.0,
        y: 20.0,
        z: nil,
        type: "Asset",
        aisle: "D116",
        allAisles: ["D116", "K233"])

    static let assetPayloadForGeneric = AssetPayload(
        id: "",
        x: 0.0,
        y: 0.0,
        z: nil,
        type: "Generic",
        aisle: "A123",
        allAisles: ["A132", "B456"])

    static let iPSBuilding = IPSBuildingImpl(
        id: "mock_building_id_2280",
        name: "mock_building_name_2280",
        floors: [MockIPSFloor()],
        geofenceOrigin: IPSGlobalCoordinateImpl(
            latitude: 0.0,
            longitude: 0.0,
            altitude: 0.0),
        rotationToENU: 0.0,
        geofenceRadius: 0.0,
        externalRegions: [])
    static let iPSCoordinate = OriientCoordinate(x: 0, y: 0, z: 0)
    static let exampleURL = URL(string: "www.example.com")!
    static let urlString = "https://developer.api.us.stg.walmart.com/api-proxy/service/COMPASS/SERVICE/v1/config/"
    static let parameters: [String: String] = ["store_id": "2280",
                                      "consumer_id": "c061c52a-b978-4ae9-9875-6584e58e8a74",
                                      "timestamp": "1673378302000"]
    static let timestamp = "1681328746381"
    static let clientId =  "Uhcqt1EBCq3COum7WhGK4b0Pre0TyMndfqMsCslnzyd70Zc5Xy1NI-pyCARRNG0qQvkI2iVv2s7sKGBiTwz_PQ"
    static let accessTokenResponse = AccessTokenResponse(accessToken: """
                "eyJraWQiOiJkOTY5MzBhYy04YjhlLTRkMDAtOGE1Ny05MGYwYWQwNWEwOGYiL\
                CJlbmMiOiJBMjU2R0NNIiwiYWxnIjoiZGlyIn0..Do_OpfQi_i6llo8e.29gdvt1TXSPN5JYm9rpiNEIHRDCevBi0itSi68m1IwDMs87OJQk\
                GCNBglZsd4yPT-3xfmQKJe364g5Vf5UUvY2sERY3S5NLP9sSg65GL2xyG\
                N-VkoktZh_498PbhTUN95eDsLC5ADze3uD3FWITc0QTsZ6YlIi_JJnRdT\
                tswVodocHd00z9VSTs9SwCqZwXOVTU8ManRKvPFyjR_dqdwbtMyFLJcPcu\
                toHe83klQK0-U-T6GOiiMbyoQjW6qo9oi7is7JzPsO07Qv7q8dz9SZxOFTO\
                E2ekmYEvmTjiPF42-EPAnZHRsWRLjM_dGQcv-qpMZhoQF6bTNPa11pGUt3c\
                SfgzvYqK2pz29FjRDsH0uQzJC3yjDx-67rogSo-zhIJN1GdYlCvvcN0lttc\
                l4bSxP96Ji7kTSW6HHfgkiXhwN68Yq48KvVEpN8wlDCrNTvGBdO6iXIO7w5\
                GCBhrIjM6ILJ5hKwLg75hYviIX8vLiF23EgGwGa-DQiwRJs6HCJbRlTDuFk2\
                qRUAIkS90QT2mf5KfS-oE_vIwBRfzTjghcFaktpD0UXWYc5AWHStgNlQgJOYE\
                Afmv3UDia9eqbdJWBEKu0Jq0Sp8MB16smOyFwbOu7C6gipp52Ej9ovcTY_Z5kR\
                exlEHhHPXRIh7e7Uvj0Br7r94eAhNzuSR_sj6_sCydKwbOS_1tSd92SnTe13tHg\
                uehe_KdwgNCV4tzQBj5pNb6H1YmoRHhwo19oFWlRjkpsdc7VCN32FWNHkvtL8o-e\
                Ioun2O4jIZJqIEnPG1v-T3_0buLREMgH5syS-aG3MB7FeXq-cDStvWi0xjkU8S-VR\
                yIQtB5_7nzs8G5Mb2GiMsO64F0FIV_AJiITwS9KigxtL6h1HE4rORZvZ6Nyps.aytE\
                Lhuk1IjGNrOs0tRyEg
                """,
                                                  tokenType: "User",
                                                  expiresIn: 900)
    static let authParameter = AuthParameter(clientSecret: accessTokenResponse.accessToken,
                                             tokenType: accessTokenResponse.tokenType,
                                              accountID: "accountID",
                                              consumerID: "c061c52a-b978-4ae9-9875-6584e58e8a74")
    static let authParameterWithTokenTypeOfUser = AuthParameter(clientSecret: accessTokenResponse.accessToken,
                                             tokenType: "user",
                                              accountID: "accountID",
                                              consumerID: "c061c52a-b978-4ae9-9875-6584e58e8a74")
    static let authParameterWithEmptyAccountId = AuthParameter(clientSecret: "authToken",
                                              tokenType: "tokenType",
                                              accountID: "",
                                              consumerID: "c061c52a-b978-4ae9-9875-6584e58e8a74")
    static let configuration = Configuration(country: "US",
                                      site: 2280,
                                      userId: "988sdd-erer-43434",
                                      siteType: .Store,
                                      manualPinDrop: true,
                                      navigateToPin: false,
                                      multiPin: false,
                                      searchBar: false,
                                      centerMap: true,
                                      locationIngestion: true,
                                      mockUser: false,
                                      anonymizedUserID: "anonymizedUserID",
                                      startPositioning: true,
                                      automaticCalibration: true,
                                      businessUnitType: .WALMART)
    static let error = WebAPIRequestError.nilHTTPResponse

    // test configResponseDetails
    static let compassSpec = CompassSpec(logFrequency: 300,
                                  logUploadStartTime: "09:00",
                                  logUploadEndTime: "17:00")
    static let consumerSpec = ConsumerSpec(getLocation: false)
    static let deviceSpec = DeviceSpec(frequency: 300)
    static let consumerConfig = ConsumerConfig(consumerId: "c061c52a-b978-4ae9-9875-6584e58e8a74")
    static let storeConfig = StoreConfig(storeId: Int(2281),
                                         valid: true,
                                         bluedotEnabled: false,
                                         mapType: "walmartmap",
                                         sessionRefreshTime: 900,
                                         offset: StoreConfigOffset(x: 7, y: 7),
                                         analytics: false,
                                         batchInterval: 99000.0,
                                         heartbeatInterval: 88000.0
    )

    static let configPayload = ConfigurationPayload(consumerConfig: consumerConfig,
                                                      storeConfig: storeConfig)
    static let configResponse = ConfigurationResponse(payload: configPayload)

    static let pinCreateResponse = PinCreateResponse(
        status: "ok",
        errors: [],
        payload: pinPayload
    )

    static let pinPayload =  PinPayloadResponse(
        id: "test-id",
        comment: "",
        storeId: "2280",
        positionX: 3000,
        positionY: 2300,
        locationList: []
    )
    static let logEventResponse = LogEventResponse(status: "success", statusCode: 200)

    // test error
    static let errorCode = -9
    static let errorDescription = "dummyDescription"
    static let errorType = "dummyErrorType"
    static var iamAuthParameter: AuthParameter?
    
    static let coordinate1 = Coordinate(x: 1000, y: 2000)
    static let coordinate2 = Coordinate(x: 2000, y: 4000)
    static let assetEvent1 = AssetEvent(assetId: "asset1", locations: ["loc1", "loc2", "loc3"], coordinate: coordinate1, success: true)
    static let assetEvent2 = AssetEvent(assetId: "aeert2", locations: ["loc4", "loc5"], coordinate: coordinate2, success: true)
    static let assetEvents = [assetEvent1, assetEvent2]
    static let pinEvent = PinDropEventEmitter(
        eventType: .bootstrapEventEmitter, mapType: MapIdentifier.WalmartMap.rawValue, longPressed: false, assets: ["asset1": assetEvent1], encodedLocation: "", idType: PinDropMethod.assets.rawValue
    )

    static let pins = [pinAisleEvent1]
    static let location1 = ["A": "101"]
    static let location2 = ["Z": "999"]
    static let pinAisleEvent1 = PinAisleEvent(id: "pinAisleEventId1", location: location1, success: true)
    static let pinAisleEvent2 = PinAisleEvent(id: "pinAisleEventId2", location: location2, success: true)
    
    static let validAssetId = "peter123"
    static let invalidAssetId = "peter1235"
}
