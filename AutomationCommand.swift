//
//  AutomationCommand.swift
//  GestaltLab
//
//  Headless entry points so the Mac side can drive the app without taps.
//

import Foundation

enum AutomationCommand {
    static let dumpArgument = "--dump"
    static let setRegionArgument = "--set-region"
    static let restoreRegionArgument = "--restore-ch-region"
    static let siriAIArgument = "--siri-ai"
    static let setKeyArgument = "--set-key"
    static let successMarker = "GESTALTLAB_SUCCESS"
    static let failureMarker = "GESTALTLAB_FAILURE"

    static func runIfNeeded() {
        let args = CommandLine.arguments
        guard args.contains(dumpArgument)
                || args.contains(setRegionArgument)
                || args.contains(restoreRegionArgument)
                || args.contains(siriAIArgument)
                || args.contains(setKeyArgument) else { return }

        do {
            let access = GestaltAccess.shared()
            try access.connect()

            if args.contains(dumpArgument) {
                let data = try access.readGestaltData()
                let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("MobileGestalt-dump.plist")
                try data.write(to: path)
                finish(marker: successMarker, message: path.path)
            }

            // Siri AI: RegionCode only. RegionInfo is deliberately untouched.
            if args.contains(siriAIArgument) {
                try write(key: GestaltRegion.key, value: GestaltRegion.unitedStates)
                finish(marker: successMarker,
                       message: "RegionCode=\(GestaltRegion.unitedStates) (RegionInfo unchanged)")
            }

            if args.contains(restoreRegionArgument) || args.contains(setRegionArgument) {
                let code = args.contains(restoreRegionArgument) ? GestaltRegion.china
                    : value(after: setRegionArgument, in: args) ?? GestaltRegion.china
                try write(key: GestaltRegion.key, value: code)
                finish(marker: successMarker, message: "RegionCode=\(code)")
            }

            if let spec = value(after: setKeyArgument, in: args) {
                // Format: KEY=INT_VALUE or KEY="STRING"
                let parts = spec.split(separator: "=", maxSplits: 1).map(String.init)
                guard parts.count == 2 else {
                    throw AutomationError.badArgument(spec)
                }
                let raw = parts[1]
                let value: Any = raw.hasPrefix("\"") && raw.hasSuffix("\"")
                    ? String(raw.dropFirst().dropLast())
                    : (Int64(raw).map { NSNumber(value: $0) } ?? raw)
                try write(key: parts[0], value: value)
                finish(marker: successMarker, message: "\(parts[0])=\(raw)")
            }

            finish(marker: failureMarker, message: "no action matched")
        } catch {
            finish(marker: failureMarker, message: error.localizedDescription)
        }
    }

    private static func value(after flag: String, in args: [String]) -> String? {
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    private static func write(key: String, value: Any) throws {
        let access = GestaltAccess.shared()
        let original = try access.readGestaltData()
        guard var plist = try access.readGestalt() as? [String: Any],
              var cacheExtra = plist["CacheExtra"] as? [String: Any] else {
            throw AutomationError.invalidPlist
        }
        cacheExtra[key] = value
        plist["CacheExtra"] = cacheExtra
        _ = try GestaltBackupStore.create(from: original)
        try access.saveGestalt(plist)
    }

    private static func finish(marker: String, message: String) -> Never {
        let sanitized = message.replacingOccurrences(of: "\n", with: " ")
        FileHandle.standardOutput.write(Data("\(marker):\(sanitized)\n".utf8))
        exit(marker == successMarker ? EXIT_SUCCESS : EXIT_FAILURE)
    }
}

enum AutomationError: LocalizedError {
    case invalidPlist
    case badArgument(String)

    var errorDescription: String? {
        switch self {
        case .invalidPlist: "MobileGestalt plist 或 CacheExtra 无效"
        case .badArgument(let s): "参数格式不对：\(s)"
        }
    }
}
