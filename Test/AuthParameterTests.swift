//
//  AuthParameterTests.swift
//  compass_sdk_iosTests
//
//  Created by Young Jin Ju - Vendor on 3/29/23.
//

@testable import compass_sdk_ios
import XCTest

final class AuthParameterTests: XCTestCase {

    private var authParameter: AuthParameter!

    override func setUpWithError() throws {
        authParameter = TestData.authParameter

    }

    override func tearDownWithError() throws {
        authParameter = nil
    }

    func testUpdate() {
        authParameter.update(using: TestData.accessTokenResponse)

        XCTAssertEqual(authParameter.clientSecret, TestData.authParameter.clientSecret)
        XCTAssertEqual(authParameter.tokenType, TestData.authParameter.tokenType)
    }
}
