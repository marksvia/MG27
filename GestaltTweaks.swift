//
//  GestaltTweaks.swift
//  GestaltLab
//
//  Capability presets. Key names are MobileGestalt CacheExtra keys; the values
//  are what Nugget/GestaltEdit write for the same features.
//

import Foundation

enum TweakCategory: String, CaseIterable, Identifiable {
    case display, hardware, ipad, region, internalFeatures

    var id: String { rawValue }

    var label: String {
        switch self {
        case .display: "显示与外观"
        case .hardware: "硬件能力"
        case .ipad: "iPad 能力"
        case .region: "区域"
        case .internalFeatures: "内部 / 研究"
        }
    }
}

enum TweakID: String, CaseIterable, Identifiable {
    case dynamicIsland
    case alwaysOnDisplay
    case alwaysOnVibrancy
    case disableParallax
    case liquidGlassLowPerf
    case liquidGlassFullPerf
    case bootChime
    case chargeLimit
    case tapToWake
    case cameraButton
    case pencil
    case actionButton
    case collisionSOS
    case stageManager
    case iPadApps
    case iPadOS
    case internalInstall
    case internalStorage
    case securityResearch

    var id: String { rawValue }
}

enum GestaltRegion {
    /// "CH" = mainland China stock code, "LL" = US.
    static let china = "CH"
    static let unitedStates = "LL"
    /// RegionCode — the value the Apple Intelligence gate reads.
    static let key = "h63QSdBCiT/z0WU6rdQv6Q"
    /// RegionInfo — the "/A" suffix shown in Settings > General > About
    /// ("CH/A" vs "LL/A"). Siri AI only needs RegionCode, so this stays as is.
    static let infoKey = "zHeENZu+wbg7PUprwNwBWg"
}

struct TweakDefinition: Identifiable {
    let id: TweakID
    let category: TweakCategory
    let title: String
    let detail: String
    let values: [String: Any]
    /// Keys deleted from CacheExtra. A missing key is the factory state.
    var removedKeys: [String] = []
    var isRisky = false
}

enum TweakCatalog {
    static let definitions: [TweakDefinition] = [
        .init(id: .dynamicIsland, category: .display,
              title: "灵动岛能力",
              detail: "写入 Dynamic Island 支持标志；实际外观还取决于 ArtworkDeviceSubType。",
              values: ["YlEtTtHlNesRBMal1CqRaA": 1]),

        .init(id: .alwaysOnDisplay, category: .display,
              title: "全天候显示",
              detail: "不支持 LTPO 的机型开启后可能增加烧屏风险。",
              values: ["2OOJf1VhaM7NxfRok3HbWQ": 1, "j8/Omm6s1lsmTDFsXjsBfA": 1],
              isRisky: true),

        .init(id: .alwaysOnVibrancy, category: .display,
              title: "AOD 通透效果",
              detail: "AOD 渲染看起来不对时再开这个。",
              values: ["ykpu7qyhqFweVMKtxNylWA": 1]),

        .init(id: .disableParallax, category: .display,
              title: "关闭壁纸视差",
              detail: "停止随设备移动的壁纸位移。",
              values: ["UIParallaxCapability": 0]),

        .init(id: .liquidGlassLowPerf, category: .display,
              title: "Liquid Glass 低性能模式",
              detail: "iOS 26 及以后。",
              values: ["SAGvsp6O6kAQ4fEfDJpC4Q": 1]),

        .init(id: .liquidGlassFullPerf, category: .display,
              title: "关闭 Liquid Glass 低性能模式",
              detail: "与上一项互斥。",
              values: ["SAGvsp6O6kAQ4fEfDJpC4Q": 0]),

        .init(id: .bootChime, category: .hardware,
              title: "开机 / 关机提示音",
              detail: "打开开关机音效能力。",
              values: ["QHxt+hGLaBPbQJbXiUJX3w": 1]),

        .init(id: .chargeLimit, category: .hardware,
              title: "充电上限菜单",
              detail: "只显示设置项，实际限流取决于硬件。",
              values: ["37NVydb//GP/GrhuTN+exg": 1]),

        .init(id: .tapToWake, category: .hardware,
              title: "轻点唤醒",
              detail: "主要给 iPhone SE 这类默认没有的机型。",
              values: ["yZf3GTRMGTuwSV/lD7Cagw": 1]),

        .init(id: .cameraButton, category: .hardware,
              title: "相机控制设置",
              detail: "显示 Camera Control 相关设置项。",
              values: ["CwvKxM2cEogD3p+HYgaW0Q": 1, "oOV1jhJbdV3AddkcCg0AEA": 1]),

        .init(id: .pencil, category: .hardware,
              title: "Apple Pencil 设置",
              detail: "显示 Apple Pencil 设置页。",
              values: ["yhHcB0iH0d1XzPO/CFd3ow": 1]),

        .init(id: .actionButton, category: .hardware,
              title: "操作按钮设置",
              detail: "显示 Action Button 设置页。",
              values: ["cT44WE1EohiwRzhsZ8xEsw": 1]),

        .init(id: .collisionSOS, category: .hardware,
              title: "碰撞检测 SOS",
              detail: "在 SOS 设置里显示碰撞检测。",
              values: ["HCzWusHQwZDea6nNhaKndw": 1]),

        .init(id: .stageManager, category: .ipad,
              title: "台前调度支持",
              detail: "标记设备支持 Stage Manager。",
              values: ["qeaj75wk3HF4DwQ8qbIi7g": 1]),

        .init(id: .iPadApps, category: .ipad,
              title: "允许安装 iPad 应用",
              detail: "在 iPhone 上打开 iPad 应用兼容类型。",
              values: ["9MZ5AdH43csAUajl/dU+IQ": [1, 2]]),

        .init(id: .iPadOS, category: .ipad,
              title: "启用 iPadOS 模式",
              detail: "改五个能力位并重写 CacheData，实验性，风险高。",
              values: ["mG0AnH/Vy1veoqoLRAIgTA": 1,
                       "UCG5MkVahJxG1YULbbd5Bg": 1,
                       "ZYqko/XM5zD3XBfN5RmaXA": 1,
                       "nVh/gwNpy7Jv1NOk00CMrw": 1,
                       "uKc7FPnEO++lVhHWHFlGbQ": 1],
              isRisky: true),

        .init(id: .internalInstall, category: .internalFeatures,
              title: "内部安装标记",
              detail: "打开后设备被当作 Apple 内部安装机；关掉则删除该键，恢复出厂状态。",
              values: ["EqrsVvjcYDdxHBiQmGhAWw": 1],
              removedKeys: ["EqrsVvjcYDdxHBiQmGhAWw"], isRisky: true),

        .init(id: .internalStorage, category: .internalFeatures,
              title: "内部存储视图",
              detail: "打开后显示内部存储视图；关掉则删除该键，恢复出厂状态。",
              values: ["LBJfwOEzExRxzlAnSuI7eg": 1],
              removedKeys: ["LBJfwOEzExRxzlAnSuI7eg"], isRisky: true),

        .init(id: .securityResearch, category: .internalFeatures,
              title: "安全研究设备模式",
              detail: "打开后设备按 SRD 模式运行；关掉则删除该键，恢复出厂状态。",
              values: ["XYlJKKkj2hztRP1NWWnhlw": 1],
              removedKeys: ["XYlJKKkj2hztRP1NWWnhlw"], isRisky: true),
    ]

    static func definition(for id: TweakID) -> TweakDefinition? {
        definitions.first { $0.id == id }
    }
}

struct DynamicIslandOption: Identifiable, Hashable {
    let subtype: Int
    let title: String
    var id: Int { subtype }

    static let all: [DynamicIslandOption] = [
        .init(subtype: 2436, title: "iPhone X 手势 (SE)"),
        .init(subtype: 2556, title: "iPhone 14 Pro"),
        .init(subtype: 2796, title: "iPhone 14 Pro Max"),
        .init(subtype: 2622, title: "iPhone 16 Pro"),
        .init(subtype: 2868, title: "iPhone 16 Pro Max"),
        .init(subtype: 2736, title: "iPhone Air"),
    ]
}

enum TweakError: LocalizedError {
    case artworkDictionaryMissing
    case cacheDataMissing
    case cacheDataTooShort
    case cacheDataPatternNotFound
    case invalidCacheDataOffset

    var errorDescription: String? {
        switch self {
        case .artworkDictionaryMissing:
            "MobileGestalt 里没有 ArtworkDevice 字典，改不了灵动岛或机型名。"
        case .cacheDataMissing:
            "MobileGestalt 里没有 CacheData，无法启用 iPadOS 模式。"
        case .cacheDataTooShort:
            "CacheData 太短，不能安全地改。"
        case .cacheDataPatternNotFound:
            "CacheData 里没找到 iPadOS 需要的标记。"
        case .invalidCacheDataOffset:
            "CacheData 标记校验失败，未做任何修改。"
        }
    }
}

extension GestaltPlist {
    enum ApplyMode { case enable, restore }

    mutating func apply(definition: TweakDefinition, mode: ApplyMode = .enable) throws {
        switch mode {
        case .enable:
            for (key, value) in definition.values {
                setCacheExtra(value, forKey: key)
            }
        case .restore:
            // A key absent from CacheExtra is the factory state, so restore
            // means delete rather than write 0.
            for key in definition.removedKeys {
                removeCacheExtraValue(forKey: key)
            }
        }
        if definition.id == .iPadOS, mode == .enable {
            try enableIPadOSCacheData()
        }
    }

    mutating func setDynamicIslandSubtype(_ subtype: Int) throws {
        let key = "oPeik/9e8lQWMszEjbPzng"
        guard var artwork = cacheExtra[key] as? [String: Any] else {
            throw TweakError.artworkDictionaryMissing
        }
        artwork["ArtworkDeviceSubType"] = subtype
        setCacheExtra(artwork, forKey: key)
        setCacheExtra(1, forKey: "YlEtTtHlNesRBMal1CqRaA")
    }

    mutating func setModelName(_ name: String) throws {
        let key = "oPeik/9e8lQWMszEjbPzng"
        guard var artwork = cacheExtra[key] as? [String: Any] else {
            throw TweakError.artworkDictionaryMissing
        }
        artwork["ArtworkDeviceProductDescription"] = name
        setCacheExtra(artwork, forKey: key)
    }

    /// Nugget's iPadOS marker rewrite: find the 4-hex-digit run inside the
    /// 1616..1816 hex slice, then flip the byte 67 chars to its left.
    private mutating func enableIPadOSCacheData() throws {
        guard let cacheData = dict["CacheData"] as? Data else {
            throw TweakError.cacheDataMissing
        }
        var hex = Array(cacheData.map { String(format: "%02x", $0) }.joined())
        let sliceStart = 1616
        let sliceLength = 200
        guard hex.count > sliceStart else { throw TweakError.cacheDataTooShort }

        let end = min(hex.count, sliceStart + sliceLength)
        let slice = String(hex[sliceStart..<end])
        let regex = try NSRegularExpression(pattern: "0+(?:5555)*([0-9a-f]{4})")
        let nsRange = NSRange(slice.startIndex..<slice.endIndex, in: slice)
        var matchedOffset: Int?
        regex.enumerateMatches(in: slice, range: nsRange) { match, _, stop in
            guard let range = match.flatMap({ Range($0.range(at: 1), in: slice) }) else { return }
            let value = slice[range]
            if value.filter({ $0 != "0" }).count >= 3 {
                matchedOffset = sliceStart + slice.distance(from: slice.startIndex, to: range.lowerBound)
                stop.pointee = true
            }
        }
        guard let offset = matchedOffset else { throw TweakError.cacheDataPatternNotFound }

        let rightOffset = offset + 13
        let leftOffset = offset - 67
        guard leftOffset > 0, rightOffset < hex.count - 1 else {
            throw TweakError.invalidCacheDataOffset
        }
        for position in [leftOffset, rightOffset] {
            guard ["1", "3"].contains(String(hex[position])),
                  hex[position - 1] == "0", hex[position + 1] == "0" else {
                throw TweakError.invalidCacheDataOffset
            }
        }
        hex[leftOffset] = "3"

        let updatedHex = String(hex)
        var updated = Data(capacity: updatedHex.count / 2)
        var index = updatedHex.startIndex
        while index < updatedHex.endIndex {
            let next = updatedHex.index(index, offsetBy: 2)
            guard let byte = UInt8(updatedHex[index..<next], radix: 16) else {
                throw TweakError.invalidCacheDataOffset
            }
            updated.append(byte)
            index = next
        }
        dict["CacheData"] = updated
    }
}
