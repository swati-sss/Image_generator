//
//  MockOptionalModel.swift
//  compass_sdk_iosTests
//
//  Created by Rakesh Shetty on 3/29/24.
//

struct MockOptionalModel: Decodable {
    let stringVal: String?
    let intVal: Int?

    private enum CodingKeys: String, CodingKey {
        case stringVal = "string"
        case intVal = "int"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stringVal = try container.decodeIfPresent(String.self, forKey: .stringVal)
        intVal = try container.decodeIfPresent(Int.self, forKey: .intVal)
    }
}
