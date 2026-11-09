//
//  GestaltViewModel.swift
//  GestaltLab
//

import Combine
import Foundation

@MainActor
final class GestaltViewModel: ObservableObject {
    @Published var plist: GestaltPlist?
    @Published var isBusy = false
    @Published var notice: GestaltNotice?
    @Published private(set) var hasAttemptedLoad = false
    @Published private(set) var backups: [GestaltBackup] = []
    @Published var selectedTweaks: Set<TweakID> = []
    /// Internal/research keys can be both written and deleted; this tracks the
    /// ones staged for deletion (factory restore).
    @Published var restoreTweaks: Set<TweakID> = []
    @Published var dynamicIslandSubtype: Int?
    @Published var changesModelName = false
    @Published var modelName = ""
    /// nil = leave RegionCode alone. "LL" = force AI region, "CH" = restore.
    @Published var stagedRegion: String?
    @Published private(set) var isRespringing = false
    @Published private(set) var statusLine = "未连接"

    private let access = GestaltAccess.shared()

    var deviceProfile: DeviceProfile? {
        plist.flatMap(DeviceProfile.init(plist:))
    }

    var currentRegion: String? {
        plist?.cacheExtra[GestaltRegion.key] as? String
    }

    var currentRegionInfo: String? {
        plist?.cacheExtra[GestaltRegion.infoKey] as? String
    }

    /// UniqueDeviceID lives in CacheExtra under the obfuscated key
    /// base64(md5("MGCopyAnswer" + "UniqueDeviceID"))[:-2].
    var udid: String? {
        guard let value = plist?.cacheExtra["re6Zb+zwFKJNlkQTUeT+/w"] as? String,
              !value.isEmpty else { return nil }
        return value
    }

    var isRegionStock: Bool { currentRegion == GestaltRegion.china }

    var hasStagedTweaks: Bool {
        !selectedTweaks.isEmpty
            || !restoreTweaks.isEmpty
            || dynamicIslandSubtype != nil
            || (changesModelName && !modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            || stagedRegion != nil
    }

    var stagedChangeCount: Int {
        selectedTweaks.count
            + restoreTweaks.count
            + (dynamicIslandSubtype == nil ? 0 : 1)
            + (changesModelName ? 1 : 0)
            + (stagedRegion == nil ? 0 : 1)
    }

    // MARK: load

    func load() {
        guard !isBusy else { return }
        hasAttemptedLoad = true
        isBusy = true
        notice = nil
        statusLine = "读取中…"

        defer { isBusy = false }
        do {
            guard let dict = try access.readGestalt() as? [String: Any] else {
                throw LabError.invalidPlist
            }
            plist = GestaltPlist(dict: dict)
            statusLine = "已连接 · \(access.plistPath ?? "")"
            refreshBackups()
        } catch {
            plist = nil
            statusLine = "读取失败"
            report(error)
        }
    }

    func reload() { load() }

    // MARK: staging

    func setTweak(_ id: TweakID, enabled: Bool) {
        if enabled {
            selectedTweaks.insert(id)
            restoreTweaks.remove(id)
            if id == .liquidGlassLowPerf {
                selectedTweaks.remove(.liquidGlassFullPerf)
            } else if id == .liquidGlassFullPerf {
                selectedTweaks.remove(.liquidGlassLowPerf)
            }
        } else {
            selectedTweaks.remove(id)
        }
    }

    /// Stage deletion of an internal/research key (factory restore).
    func setRestore(_ id: TweakID, enabled: Bool) {
        if enabled {
            restoreTweaks.insert(id)
            selectedTweaks.remove(id)
        } else {
            restoreTweaks.remove(id)
        }
    }

    /// True when the key this preset writes is present in CacheExtra.
    func isKeyPresent(_ definition: TweakDefinition) -> Bool {
        guard let cacheExtra = plist?.cacheExtra else { return false }
        return definition.values.keys.contains { cacheExtra[$0] != nil }
    }

    func applySelectedTweaks() {
        guard !isBusy, var pending = plist else { return }
        do {
            for id in selectedTweaks {
                guard let definition = TweakCatalog.definition(for: id) else { continue }
                try pending.apply(definition: definition, mode: .enable)
            }
            for id in restoreTweaks {
                guard let definition = TweakCatalog.definition(for: id) else { continue }
                try pending.apply(definition: definition, mode: .restore)
            }
            if let dynamicIslandSubtype {
                try pending.setDynamicIslandSubtype(dynamicIslandSubtype)
            }
            if changesModelName {
                let name = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { throw LabError.emptyModelName }
                try pending.setModelName(name)
            }
            if let stagedRegion {
                pending.setCacheExtra(stagedRegion, forKey: GestaltRegion.key)
            }
            save(pending, verifyRegion: stagedRegion) { [weak self] in
                self?.selectedTweaks.removeAll()
                self?.restoreTweaks.removeAll()
                self?.dynamicIslandSubtype = nil
                self?.changesModelName = false
                self?.modelName = ""
                self?.stagedRegion = nil
            }
        } catch {
            report(error)
        }
    }

    func applyChanges() {
        guard !isBusy, let plist else { return }
        save(plist, verifyRegion: nil)
    }

    // MARK: backups

    func createBackup() {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let data = try access.readGestaltData()
            let backup = try GestaltBackupStore.create(from: data)
            refreshBackups()
            notice = GestaltNotice(kind: .success,
                                   message: "已保存 \(backup.name).plist，可在「备份」页导出。")
        } catch {
            report(error)
        }
    }

    func importBackup(from url: URL) {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            var format = PropertyListSerialization.PropertyListFormat.binary
            guard let dict = try PropertyListSerialization.propertyList(
                from: data, options: [], format: &format
            ) as? [String: Any], dict["CacheExtra"] is [String: Any] else {
                throw LabError.invalidBackup
            }
            let backup = try GestaltBackupStore.create(from: data)
            refreshBackups()
            notice = GestaltNotice(kind: .success,
                                   message: "已导入 \(url.lastPathComponent)，保存为 \(backup.name).plist。")
        } catch {
            report(error)
        }
    }

    func restore(_ backup: GestaltBackup) {
        guard !isBusy else { return }
        do {
            let data = try GestaltBackupStore.data(for: backup)
            var format = PropertyListSerialization.PropertyListFormat.binary
            guard let dict = try PropertyListSerialization.propertyList(
                from: data, options: [], format: &format
            ) as? [String: Any] else {
                throw LabError.invalidBackup
            }
            save(GestaltPlist(dict: dict), verifyRegion: nil)
        } catch {
            report(error)
        }
    }

    func delete(_ backup: GestaltBackup) {
        do {
            try GestaltBackupStore.delete(backup)
            refreshBackups()
        } catch {
            report(error)
        }
    }

    func refreshBackups() {
        do {
            backups = try GestaltBackupStore.list()
        } catch {
            report(error)
        }
    }

    // MARK: save

    private func save(_ pending: GestaltPlist, verifyRegion: String?, completion: (() -> Void)? = nil) {
        isBusy = true
        notice = nil

        do {
            let original = try access.readGestaltData()
            _ = try GestaltBackupStore.create(from: original)
            try access.saveGestalt(pending.dict)

            guard let verification = try access.readGestalt() as? [String: Any] else {
                throw LabError.invalidPlist
            }
            let verified = GestaltPlist(dict: verification)

            if let expected = verifyRegion {
                guard verified.cacheExtra[GestaltRegion.key] as? String == expected else {
                    throw LabError.verificationFailed
                }
            }

            plist = verified
            completion?()
            refreshBackups()
            isBusy = false
            isRespringing = true
        } catch {
            report(error)
            isBusy = false
        }
    }

    func finishRespring() {
        isRespringing = false
    }

    private func report(_ error: Error) {
        notice = GestaltNotice(kind: .error, message: error.localizedDescription)
    }
}

enum LabError: LocalizedError {
    case invalidPlist
    case invalidBackup
    case verificationFailed
    case emptyModelName

    var errorDescription: String? {
        switch self {
        case .invalidPlist: "MobileGestalt 不是一个合法字典。"
        case .invalidBackup: "备份文件不是合法的 MobileGestalt plist。"
        case .verificationFailed: "写入后回读的值与预期不一致。"
        case .emptyModelName: "机型名不能为空。"
        }
    }
}
