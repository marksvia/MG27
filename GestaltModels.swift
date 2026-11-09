//
//  GestaltModels.swift
//  GestaltLab
//
//  Plist model plus typed value editing for the MobileGestalt cache.
//

import Foundation

// MARK: - device profile

struct DeviceProfile: Equatable {
    let marketingName: String
    let regulatoryModel: String

    init(marketingName: String, regulatoryModel: String) {
        self.marketingName = marketingName
        self.regulatoryModel = regulatoryModel
    }

    private static let regulatoryModels: [String: String] = [
        "iPhone 18 Pro Max": "A3XXX",
        "iPhone 18 Pro": "A3XXX",
        "iPhone 17 Pro Max": "A3257",
        "iPhone 17 Pro": "A3256",
        "iPhone 17": "A3258",
        "iPhone Air": "A3260",
        "iPhone 16 Pro Max": "A3084",
        "iPhone 16 Pro": "A3083",
        "iPhone 16 Plus": "A3082",
        "iPhone 16": "A3081",
        "iPhone 16e": "A3212",
        "iPhone 15 Pro Max": "A2849",
        "iPhone 15 Pro": "A2848",
    ]

    private static let productTypes: [String: DeviceProfile] = [
        "iPhone17,1": .init(marketingName: "iPhone 16 Pro", regulatoryModel: "A3083"),
        "iPhone17,2": .init(marketingName: "iPhone 16 Pro Max", regulatoryModel: "A3084"),
        "iPhone17,3": .init(marketingName: "iPhone 16", regulatoryModel: "A3081"),
        "iPhone17,4": .init(marketingName: "iPhone 16 Plus", regulatoryModel: "A3082"),
        "iPhone17,5": .init(marketingName: "iPhone 16e", regulatoryModel: "A3212"),
        "iPhone18,1": .init(marketingName: "iPhone 17 Pro", regulatoryModel: "A3256"),
        "iPhone18,2": .init(marketingName: "iPhone 17 Pro Max", regulatoryModel: "A3257"),
        "iPhone18,3": .init(marketingName: "iPhone 17", regulatoryModel: "A3258"),
        "iPhone18,4": .init(marketingName: "iPhone Air", regulatoryModel: "A3260"),
    ]

    init?(plist: GestaltPlist) {
        let productType = plist.cacheExtra["0+nc/Udy4WNG8S+Q7a/s1A"] as? String
            ?? Self.machineIdentifier
        guard let profile = Self.profile(forProductType: productType) else { return nil }
        self = profile
    }

    /// US regulatory model for the current hardware. Used by the Siri AI
    /// preset, which has to move RegionCode, RegionInfo and the regulatory
    /// model together — the eligibility gate reads all three.
    var usRegulatoryModel: String {
        Self.usRegulatoryModels[marketingName] ?? regulatoryModel
    }

    private static let usRegulatoryModels: [String: String] = [
        "iPhone 17 Pro Max": "A3257",
        "iPhone 17 Pro": "A3256",
        "iPhone 17": "A3258",
        "iPhone Air": "A3260",
        "iPhone 16 Pro Max": "A3084",
        "iPhone 16 Pro": "A3083",
        "iPhone 16 Plus": "A3082",
        "iPhone 16": "A3081",
        "iPhone 16e": "A3212",
        "iPhone 15 Pro Max": "A2849",
        "iPhone 15 Pro": "A2848",
    ]

    private static func profile(forProductType productType: String) -> DeviceProfile? {
        if let exact = productTypes[productType] { return exact }
        // MobileGestalt may append a board suffix, e.g. "iPad16,3-A".
        guard let dash = productType.firstIndex(of: "-") else { return nil }
        return productTypes[String(productType[..<dash])]
    }

    private static var machineIdentifier: String {
        var size = 0
        guard sysctlbyname("hw.machine", nil, &size, nil, 0) == 0, size > 0 else { return "" }
        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.machine", &value, &size, nil, 0) == 0 else { return "" }
        return String(cString: value)
    }
}

// MARK: - notices

struct GestaltNotice: Identifiable {
    enum Kind { case error, success, risk }

    let id = UUID()
    let kind: Kind
    let message: String

    var title: String {
        switch kind {
        case .error: "失败"
        case .success: "完成"
        case .risk: "高风险"
        }
    }
}

// MARK: - typed values

enum PlistValueKind: String, CaseIterable, Identifiable {
    case string, integer, float, boolean, data, array, dictionary

    var id: String { rawValue }

    var label: String {
        switch self {
        case .string: "字符串"
        case .integer: "整数"
        case .float: "浮点"
        case .boolean: "布尔"
        case .data: "Data"
        case .array: "数组"
        case .dictionary: "字典"
        }
    }

    static func kind(of value: Any?) -> PlistValueKind {
        switch value {
        case is String:
            .string
        case let number as NSNumber:
            CFGetTypeID(number) == CFBooleanGetTypeID()
                ? .boolean
                : (CFNumberIsFloatType(number) ? .float : .integer)
        case is Data:
            .data
        case is NSArray:
            .array
        case is NSDictionary:
            .dictionary
        default:
            .string
        }
    }
}

struct PlistValueInfo {
    let kind: PlistValueKind
    let summary: String

    static func info(for value: Any?) -> PlistValueInfo {
        let kind = PlistValueKind.kind(of: value)
        let text = encode(value, as: kind)
        let summary: String
        switch kind {
        case .string:
            summary = text.isEmpty ? "空字符串" : text
        case .integer, .float, .boolean:
            summary = text
        case .data:
            summary = "Data（\((value as? Data)?.count ?? 0) 字节）"
        case .array:
            summary = "数组（\((value as? NSArray)?.count ?? 0) 项）"
        case .dictionary:
            summary = "字典（\((value as? NSDictionary)?.count ?? 0) 项）"
        }
        return PlistValueInfo(kind: kind, summary: summary)
    }

    static func encode(_ value: Any?, as kind: PlistValueKind) -> String {
        switch kind {
        case .string:
            return value as? String ?? ""
        case .integer, .float:
            return (value as? NSNumber)?.stringValue ?? ""
        case .boolean:
            return (value as? NSNumber)?.boolValue == true ? "true" : "false"
        case .data:
            return (value as? Data)?.base64EncodedString() ?? ""
        case .array, .dictionary:
            guard let value, JSONSerialization.isValidJSONObject(value),
                  let data = try? JSONSerialization.data(withJSONObject: value,
                                                         options: [.prettyPrinted, .sortedKeys])
            else { return "" }
            return String(data: data, encoding: .utf8) ?? ""
        }
    }

    static func parse(_ text: String, as kind: PlistValueKind) throws -> Any {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch kind {
        case .string:
            return text
        case .integer:
            guard let v = Int64(trimmed) else { throw PlistValueError.invalid("整数格式不对") }
            return NSNumber(value: v)
        case .float:
            guard let v = Double(trimmed) else { throw PlistValueError.invalid("浮点格式不对") }
            return NSNumber(value: v)
        case .boolean:
            switch trimmed.lowercased() {
            case "true", "1", "yes": return NSNumber(value: true)
            case "false", "0", "no": return NSNumber(value: false)
            default: throw PlistValueError.invalid("填 true 或 false")
            }
        case .data:
            guard let d = Data(base64Encoded: trimmed) else {
                throw PlistValueError.invalid("Base64 格式不对")
            }
            return d
        case .array:
            return try jsonObject(from: trimmed, expected: NSArray.self)
        case .dictionary:
            return try jsonObject(from: trimmed, expected: NSDictionary.self)
        }
    }

    private static func jsonObject<T>(from text: String, expected: T.Type) throws -> Any {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              object is T else {
            throw PlistValueError.invalid("JSON 结构与所选类型不符")
        }
        return object
    }
}

enum PlistValueError: LocalizedError {
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .invalid(let message): message
        }
    }
}

// MARK: - plist

struct GestaltPlist {
    var dict: [String: Any]

    var topLevelKeys: [String] { dict.keys.sorted() }

    var cacheExtra: [String: Any] {
        get { dict["CacheExtra"] as? [String: Any] ?? [:] }
        set { dict["CacheExtra"] = newValue }
    }

    var cacheExtraKeys: [String] { cacheExtra.keys.sorted() }

    func value(forKey key: String) -> Any? { dict[key] }

    mutating func setValue(_ value: Any, forKey key: String) { dict[key] = value }

    mutating func setCacheExtra(_ value: Any, forKey key: String) {
        var values = cacheExtra
        values[key] = value
        cacheExtra = values
    }

    mutating func removeCacheExtraValue(forKey key: String) {
        var values = cacheExtra
        values.removeValue(forKey: key)
        cacheExtra = values
    }
}
