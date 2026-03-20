//
//  CommonExtensions.swift
//  compass_sdk_ios
//
//  Created by Rakesh Shetty on 9/3/25.
//

import Foundation
import Combine
import UIKit

extension Dictionary where Key == String {
    func toCodableValueDictionary() -> [String: CodableValue] {
        var result = [String: CodableValue]()
        for (key, value) in self {
            result[key] = CodableValue.convert(value)
        }
        return result
    }
}

// Protocol to allow different pin types to be converted into the common `Pin` model
protocol PinConvertible {
    /// Convert the conforming type to a `Pin` suitable for the map/webview request.
    func toPin(selected: Bool) -> Pin
    /// Optional location string used for analytics (only applicable to aisle-style pins).
    func pinLocationString() -> String?
}

// Strongly-typed wrapper for different pin flavors to avoid `[Any]` casts at call sites.
public enum CompassPin {
    case aisle(AislePin)
    case campaign(CampaignPin)

    func toPin(selected: Bool) -> Pin {
        switch self {
        case .aisle(let p): return p.toPin(selected: selected)
        case .campaign(let p): return p.toPin(selected: selected)
        }
    }

    func pinLocationString() -> String? {
        switch self {
        case .aisle(let p): return p.pinLocationString()
        case .campaign(let p): return p.pinLocationString()
        }
    }
}

extension CompassPin: PinConvertible {}

extension AislePin: PinConvertible {
    func toPin(selected: Bool) -> Pin {
        return Pin(from: self, selected: selected)
    }

    func pinLocationString() -> String? {
        return Pin.locationString(from: self)
    }
}

extension CampaignPin: PinConvertible {
    func toPin(selected: Bool) -> Pin {
        return Pin(from: self, selected: selected)
    }

    func pinLocationString() -> String? { return nil }
}

extension Array where Element: PinConvertible {
    func toPinsAndLocation(honorPinSelection: Bool)
    -> (pins: [Pin], isZoomOutRequired: Bool) {
        var pins: [Pin] = []
        var pinLocation = ""
        var aisleLocations: [String] = []
        var campaignIds: [String] = []
        var isZoomOutRequired = true

        for (index, element) in self.enumerated() {
            let clientSelected = _clientSelected(from: element)
            let selectedFlag = honorPinSelection ? clientSelected : (index == 0)
            let pin = element.toPin(selected: selectedFlag)
            pins.append(pin)
            isZoomOutRequired = updateZoomRequirement(isZoomOutRequired, pin: pin, element: element)
            appendLocationData(from: element, pinLocation: &pinLocation, aisleLocations: &aisleLocations)
            handleCampaignData(from: element, campaignIds: &campaignIds, isZoomOutRequired: &isZoomOutRequired)
        }

        if !aisleLocations.isEmpty {
            let locationValue = aisleLocations.joined(separator: ",")
            Analytics.displayPin(payload: DisplayPinAnalytics(pinType: "aisle",
                                                              pinValue: locationValue,
                                                              pinCategory: "auto",
                                                              pinLocation: locationValue,
                                                              success: true))
        }

        if !campaignIds.isEmpty {
            let idsValue = campaignIds.joined(separator: ",")
            Analytics.displayPin(payload: DisplayPinAnalytics(pinType: "campaign",
                                                              pinValue: idsValue,
                                                              pinCategory: "auto",
                                                              pinLocation: nil,
                                                              success: true))
        }

        return (pins: pins, isZoomOutRequired: isZoomOutRequired)
    }

    private func updateZoomRequirement(_ currentValue: Bool, pin: Pin, element: PinConvertible) -> Bool {
        guard _elementIsAisle(element) else { return currentValue }
        guard let zone = pin.zone, !zone.isEmpty, pin.aisle != nil, pin.section != nil else {
            return currentValue
        }
        return false
    }

    private func appendLocationData(from element: PinConvertible,
                                    pinLocation: inout String,
                                    aisleLocations: inout [String]) {
        guard let locationString = element.pinLocationString() else { return }
        pinLocation = pinLocation.isEmpty ? locationString : "\(pinLocation),\(locationString)"
        aisleLocations.append(locationString)
    }

    private func handleCampaignData(from element: PinConvertible,
                                    campaignIds: inout [String],
                                    isZoomOutRequired: inout Bool) {
        guard let campaignId = _campaignId(from: element) else { return }
        if campaignId != 0 {
            isZoomOutRequired = false
        }
        campaignIds.append(String(campaignId))
    }

    private func _clientSelected(from element: PinConvertible) -> Bool {
        if let aisle = element as? AislePin { return aisle.location.selected }
        if let campaign = element as? CampaignPin { return campaign.selected }
        if let compass = element as? CompassPin {
            switch compass {
            case .aisle(let p): return p.location.selected
            case .campaign(let p): return p.selected
            }
        }
        return false
    }

    private func _elementIsAisle(_ element: PinConvertible) -> Bool {
        if element is AislePin { return true }
        if let compass = element as? CompassPin {
            if case .aisle = compass { return true }
        }
        return false
    }

    private func _campaignId(from element: PinConvertible) -> Int? {
        if let compass = element as? CompassPin {
            if case .campaign(let c) = compass { return c.id }
        } else if let campaign = element as? CampaignPin {
            return campaign.id
        }
        return nil
    }
}

extension String {
    func isEmptyOrWhitespace() -> Bool {
        guard self.isEmpty else {
            return (self.trimmingCharacters(in: .whitespaces) == "")
        }

        return true
    }
}

extension Data {
    var fnv1a64Hex: String {
        let offsetBasis: UInt64 = 14_695_981_039_346_656_037
        let prime: UInt64 = 1_099_511_628_211
        let hash = reduce(offsetBasis) { partialHash, byte in
            (partialHash ^ UInt64(byte)) &* prime
        }
        return String(format: "%016llx", hash)
    }
}

extension UserDefaults {
    func setCustomObject<T: Codable>(_ object: T, forKey key: String) {
        let encoder = JSONEncoder()
        guard let encoded = try? encoder.encode(object) else { return }
        self.set(encoded, forKey: key)
    }

    func getCustomObject<T: Codable>(forKey key: String, objectType: T.Type) -> T? {
        guard let data = self.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(objectType, from: data)
    }
}

extension DispatchQueue {
    static func dispatchToMainIfNeeded(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async {
                block()
            }
        }
    }
}

extension Just where Output == Void {
    static func void<F>() -> AnyPublisher<Void, F> where F: Error {
        return Just(()).setFailureType(to: F.self).eraseToAnyPublisher()
    }
}

extension Publisher {
    func retry<S>(count: Int = RetryConstant.retryCount.rawValue,
                  delay: S.SchedulerTimeType.Stride = .seconds(RetryConstant.retryDelay.rawValue),
                  scheduler: S = DispatchQueue.main) -> AnyPublisher<Output, Failure> where S: Scheduler {
        self.delayIfFailure(for: delay, scheduler: scheduler)
            .retry(count)
            .eraseToAnyPublisher()
    }

    private func delayIfFailure<S>(for delay: S.SchedulerTimeType.Stride,
                                   scheduler: S) -> AnyPublisher<Output, Failure> where S: Scheduler {
        self.catch { error in
            Future { completion in
                scheduler.schedule(after: scheduler.now.advanced(by: delay)) {
                    completion(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

extension UIViewController {
    func add(childVC: UIViewController) {
        addChild(childVC)
        view.addSubview(childVC.view)
        childVC.view.translatesAutoresizingMaskIntoConstraints = false
        view.addConstraints([
            childVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            childVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            childVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            childVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        childVC.didMove(toParent: self)
    }

    func remove(childVC: UIViewController) {
        childVC.willMove(toParent: nil)
        childVC.view.removeFromSuperview()
        childVC.removeFromParent()
    }
}
