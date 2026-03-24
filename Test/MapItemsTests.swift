//
//  MapItemsTests.swift
//  compass_sdk_iosTests
//
//  Created by Young Jin Ju - Vendor on 4/16/23.
//

@testable import compass_sdk_ios
import XCTest

final class MapItemsTests: XCTestCase {

    func testWaypointShouldBeCreatedFromProperties() {
        let waypoint = Waypoint(
            id: "pin-id",
            coordinate: CGPoint(x: 12, y: 34),
            buildingId: "building-id",
            floorOrder: 2
        )

        XCTAssertEqual(waypoint.id, "pin-id")
        XCTAssertEqual(waypoint.buildingId, "building-id")
        XCTAssertEqual(waypoint.floorOrder, 2)
        XCTAssertEqual(waypoint.x, 12)
        XCTAssertEqual(waypoint.y, 34)
    }
}
