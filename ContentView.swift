//
//  ContentView.swift
//  MG27
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var viewModel: GestaltViewModel
    @State private var tab = 0

    var body: some View {
        ZStack {
            MGCanvas()

            if GestaltAccess.isRunningSupportedOS() {
                VStack(spacing: 0) {
                    MGTopBar()

                    ScrollView {
                        Group {
                            switch tab {
                            case 0: WorkbenchTab()
                            case 1: FieldsTab()
                            default: BackupTab()
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 96)
                    }
                    .scrollIndicators(.hidden)

                    MGTabBar(selection: $tab)
                }
                .task { viewModel.load() }
            } else {
                UnsupportedOSView()
            }
        }
        .overlay {
            if viewModel.isRespringing {
                NeoSpringView { viewModel.finishRespring() }
            }
        }
        .alert(item: $viewModel.notice) { notice in
            Alert(title: Text(notice.title),
                  message: Text(notice.message),
                  dismissButton: .default(Text("好")))
        }
    }
}

// MARK: - top bar

private struct MGTopBar: View {
    @EnvironmentObject private var viewModel: GestaltViewModel

    private var applyTitle: String {
        viewModel.hasStagedTweaks ? "应用 \(viewModel.stagedChangeCount)" : "应用"
    }

    private var canApply: Bool {
        !viewModel.isBusy && viewModel.hasStagedTweaks
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("MG27")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.primary)
                Text(viewModel.plist == nil ? "未连接" : "已连接")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(viewModel.plist == nil ? Palette.amber : Palette.mint)
            }

            Spacer(minLength: 0)

            Button {
                viewModel.applySelectedTweaks()
            } label: {
                HStack(spacing: 6) {
                    if viewModel.isBusy {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12, weight: .bold))
                    }
                    Text(applyTitle)
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(canApply ? .white : Color.secondary)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background {
                    Capsule().fill(
                        canApply
                            ? AnyShapeStyle(LinearGradient(colors: [Palette.accent, Palette.violet],
                                                          startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(Color.secondary.opacity(0.18))
                    )
                }
                .overlay {
                    if canApply {
                        Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!canApply)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }
}

// MARK: - tab bar

private struct MGTabBar: View {
    @Binding var selection: Int

    private let items: [(String, String)] = [
        ("工具", "slider.horizontal.3"),
        ("字段", "text.magnifyingglass"),
        ("备份", "clock.arrow.circlepath"),
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                let active = selection == index
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selection = index
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.1)
                            .font(.system(size: 17, weight: .semibold))
                            .frame(height: 20)
                        Text(item.0)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(active ? .white : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if active {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(LinearGradient(colors: [Palette.accent, Palette.violet],
                                                     startPoint: .topLeading,
                                                     endPoint: .bottomTrailing))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Palette.cardStroke, lineWidth: 1)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

private struct UnsupportedOSView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundStyle(Palette.amber)
            Text("系统版本不支持")
                .font(.title2.weight(.semibold))
            Text("当前构建面向 iOS 27。build \(GestaltAccess.currentOSBuild())")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }
}

// MARK: - workbench

private struct WorkbenchTab: View {
    @EnvironmentObject private var viewModel: GestaltViewModel

    var body: some View {
        VStack(spacing: 14) {
            MGHero(
                deviceName: viewModel.deviceProfile?.marketingName ?? "当前设备",
                regulatory: viewModel.deviceProfile?.regulatoryModel,
                build: GestaltAccess.currentOSBuild(),
                connected: viewModel.plist != nil,
                regionCode: viewModel.currentRegion,
                regionInfo: viewModel.currentRegionInfo,
                fieldCount: viewModel.plist?.cacheExtraKeys.count ?? 0,
                statusLine: viewModel.statusLine,
                udid: viewModel.udid
            )

            if viewModel.plist == nil {
                loadFailureCard
            }

            regionCard
            capabilityCard(.display)
            capabilityCard(.hardware)
            capabilityCard(.ipad)
            internalCard
            islandCard
            modelNameCard
            footerCard
        }
    }

    private var loadFailureCard: some View {
        MGCard {
            HStack(spacing: 12) {
                if viewModel.isBusy || !viewModel.hasAttemptedLoad {
                    ProgressView().controlSize(.small)
                    Text("正在读取 MobileGestalt…")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Palette.amber)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("读不到 MobileGestalt")
                            .font(.system(size: 13, weight: .semibold))
                        Button("重试") { viewModel.reload() }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Palette.accent)
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: region

    private var regionCard: some View {
        MGCard {
            VStack(alignment: .leading, spacing: 10) {
                MGSectionHeader(title: "区域", symbol: "globe.asia.australia.fill",
                                tint: Palette.mint, count: nil)

                regionRow(
                    symbol: "sparkles",
                    tint: Palette.mint,
                    title: "Siri AI 强开",
                    detail: "只写 RegionCode = LL。RegionInfo（关于本机里的 CH/A）不动。",
                    active: viewModel.stagedRegion == GestaltRegion.unitedStates
                ) {
                    viewModel.stagedRegion = viewModel.stagedRegion == GestaltRegion.unitedStates
                        ? nil : GestaltRegion.unitedStates
                }

                Divider().opacity(0.4)

                regionRow(
                    symbol: "arrow.uturn.backward",
                    tint: Palette.amber,
                    title: "恢复国行区域码",
                    detail: "RegionCode 写回 CH，国行设备的出厂值。",
                    active: viewModel.stagedRegion == GestaltRegion.china
                ) {
                    viewModel.stagedRegion = viewModel.stagedRegion == GestaltRegion.china
                        ? nil : GestaltRegion.china
                }
            }
        }
    }

    private func regionRow(symbol: String, tint: Color, title: String,
                           detail: String, active: Bool,
                           action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(tint.opacity(0.13),
                                in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: active ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(active ? tint : Color.secondary.opacity(0.35))
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: capabilities

    private func capabilityCard(_ category: TweakCategory) -> some View {
        let definitions = TweakCatalog.definitions.filter { $0.category == category }
        let tint: Color = {
            switch category {
            case .display: Palette.violet
            case .hardware: Palette.accent
            case .ipad: Palette.mint
            default: Palette.amber
            }
        }()
        let symbol: String = {
            switch category {
            case .display: "sparkles.rectangle.stack.fill"
            case .hardware: "cpu"
            case .ipad: "ipad.and.iphone"
            default: "wrench.and.screwdriver.fill"
            }
        }()

        return MGCard {
            VStack(alignment: .leading, spacing: 4) {
                MGSectionHeader(title: category.label, symbol: symbol,
                                tint: tint, count: definitions.count)

                ForEach(Array(definitions.enumerated()), id: \.element.id) { index, definition in
                    if index > 0 { Divider().opacity(0.35) }
                    MGRow(
                        symbol: rowSymbol(definition),
                        tint: tint,
                        title: definition.title,
                        detail: definition.detail,
                        badge: definition.isRisky ? "高风险" : nil,
                        isOn: Binding(
                            get: { viewModel.selectedTweaks.contains(definition.id) },
                            set: { viewModel.setTweak(definition.id, enabled: $0) }
                        )
                    )
                }
            }
        }
    }

    private func rowSymbol(_ definition: TweakDefinition) -> String {
        switch definition.id {
        case .dynamicIsland: return "capsule.fill"
        case .alwaysOnDisplay, .alwaysOnVibrancy: return "moon.stars.fill"
        case .disableParallax: return "photo.fill"
        case .liquidGlassLowPerf, .liquidGlassFullPerf: return "drop.fill"
        case .bootChime: return "speaker.wave.2.fill"
        case .chargeLimit: return "battery.75percent"
        case .tapToWake: return "hand.tap.fill"
        case .cameraButton: return "camera.fill"
        case .pencil: return "pencil.tip"
        case .actionButton: return "button.programmable"
        case .collisionSOS: return "car.fill"
        case .stageManager: return "rectangle.3.group.fill"
        case .iPadApps: return "square.grid.2x2.fill"
        case .iPadOS: return "ipad"
        default: return "gearshape.fill"
        }
    }

    // MARK: internal

    private var internalCard: some View {
        let definitions = TweakCatalog.definitions.filter { $0.category == .internalFeatures }
        return MGCard {
            VStack(alignment: .leading, spacing: 4) {
                MGSectionHeader(title: TweakCategory.internalFeatures.label,
                                symbol: "ant.fill", tint: Palette.rose,
                                count: definitions.count)

                ForEach(Array(definitions.enumerated()), id: \.element.id) { index, definition in
                    if index > 0 { Divider().opacity(0.35) }
                    internalRow(definition)
                }
            }
        }
    }

    private func internalRow(_ definition: TweakDefinition) -> some View {
        let enabled = viewModel.selectedTweaks.contains(definition.id)
        let restoring = viewModel.restoreTweaks.contains(definition.id)
        let present = viewModel.isKeyPresent(definition)

        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Text(definition.title)
                    .font(.system(size: 14, weight: .semibold))
                MGBadge(text: "高风险", tint: Palette.amber)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(present ? Palette.mint : Color.secondary.opacity(0.4))
                        .frame(width: 5, height: 5)
                    Text(present ? "键存在" : "键缺失")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(present ? Palette.mint : .secondary)
                }
            }

            Text(definition.detail)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                MGSegmentButton(title: "启用", symbol: "power", active: enabled,
                                tint: Palette.mint) {
                    viewModel.setTweak(definition.id, enabled: !enabled)
                }
                MGSegmentButton(title: "清除", symbol: "trash", active: restoring,
                                tint: Palette.rose) {
                    viewModel.setRestore(definition.id, enabled: !restoring)
                }
            }
        }
        .padding(.vertical, 9)
    }

    // MARK: island

    private var islandCard: some View {
        MGCard {
            VStack(alignment: .leading, spacing: 10) {
                MGSectionHeader(title: "灵动岛", symbol: "capsule.fill",
                                tint: Palette.violet, count: nil)

                Picker("子类型", selection: $viewModel.dynamicIslandSubtype) {
                    Text("不修改").tag(Int?.none)
                    ForEach(DynamicIslandOption.all) { option in
                        Text("\(option.subtype) · \(option.title)").tag(Int?.some(option.subtype))
                    }
                }
                .pickerStyle(.menu)
                .tint(Palette.violet)

                Text("会同时写入 ArtworkDeviceSubType 和灵动岛支持标志。")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: model name

    private var modelNameCard: some View {
        MGCard {
            VStack(alignment: .leading, spacing: 10) {
                MGSectionHeader(title: "机型名", symbol: "textformat",
                                tint: Palette.accent, count: nil)

                MGRow(symbol: "iphone", tint: Palette.accent,
                      title: "修改「关于本机」里的机型名",
                      detail: "写 ArtworkDeviceProductDescription。",
                      badge: nil,
                      isOn: $viewModel.changesModelName)

                if viewModel.changesModelName {
                    TextField("例如 iPhone 17 Pro Max", text: $viewModel.modelName)
                        .font(.system(size: 13, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 9)
                        .background(Color.secondary.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    // MARK: footer

    private var footerCard: some View {
        MGCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("写入前会自动备份当前 plist，写完回读校验，成功后触发 respring。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    viewModel.createBackup()
                } label: {
                    Label("仅创建备份", systemImage: "square.and.arrow.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Palette.accent.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isBusy)
            }
        }
    }
}

// MARK: - fields

private struct FieldsTab: View {
    @EnvironmentObject private var viewModel: GestaltViewModel
    @State private var query = ""
    @State private var editing: EditTarget?

    private struct EditTarget: Identifiable {
        let id = UUID()
        let key: String
        let isCacheExtra: Bool
        let value: Any?
    }

    var body: some View {
        VStack(spacing: 14) {
            searchField

            if let plist = viewModel.plist {
                if !filteredCacheExtra.isEmpty {
                    fieldCard(title: "CacheExtra", symbol: "shippingbox.fill",
                              tint: Palette.accent, keys: filteredCacheExtra,
                              plist: plist, isCacheExtra: true)
                }
                if !filteredTopLevel.isEmpty {
                    fieldCard(title: "顶层键", symbol: "square.stack.3d.up.fill",
                              tint: Palette.violet, keys: filteredTopLevel,
                              plist: plist, isCacheExtra: false)
                }
                if filteredCacheExtra.isEmpty && filteredTopLevel.isEmpty {
                    MGCard {
                        Text("没有匹配的键")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
            } else {
                MGCard {
                    Text(viewModel.hasAttemptedLoad ? "尚未读取到 plist" : "读取中…")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            writeCard
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.tertiary)
            TextField("搜索键名或值", text: $query)
                .font(.system(size: 13))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(.ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Palette.cardStroke, lineWidth: 1)
        }
    }

    private func fieldCard(title: String, symbol: String, tint: Color,
                           keys: [String], plist: GestaltPlist,
                           isCacheExtra: Bool) -> some View {
        MGCard(padding: 14) {
            VStack(alignment: .leading, spacing: 2) {
                MGSectionHeader(title: title, symbol: symbol, tint: tint, count: keys.count)
                    .padding(.bottom, 4)

                ForEach(Array(keys.enumerated()), id: \.element) { index, key in
                    if index > 0 { Divider().opacity(0.3) }
                    fieldRow(key: key,
                             value: isCacheExtra ? plist.cacheExtra[key] : plist.value(forKey: key),
                             isCacheExtra: isCacheExtra)
                }
            }
        }
    }

    private func fieldRow(key: String, value: Any?, isCacheExtra: Bool) -> some View {
        let info = PlistValueInfo.info(for: value)
        return Button {
            editing = EditTarget(key: key, isCacheExtra: isCacheExtra, value: value)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(key)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    HStack(spacing: 6) {
                        MGBadge(text: info.kind.label, tint: kindTint(info.kind))
                        Text(info.summary)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.quaternary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private func kindTint(_ kind: PlistValueKind) -> Color {
        switch kind {
        case .string: return Palette.accent
        case .integer, .float: return Palette.mint
        case .boolean: return Palette.amber
        case .data: return Palette.violet
        case .array, .dictionary: return Palette.rose
        }
    }

    private var writeCard: some View {
        MGCard {
            Button {
                viewModel.applyChanges()
            } label: {
                HStack(spacing: 6) {
                    if viewModel.isBusy {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 11, weight: .bold))
                    }
                    Text("写入 plist")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: [Palette.mint, Palette.accent],
                                             startPoint: .leading, endPoint: .trailing))
                }
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isBusy || viewModel.plist == nil)
        }
    }

    private var filteredCacheExtra: [String] {
        guard let plist = viewModel.plist else { return [] }
        let keys = plist.cacheExtraKeys
        guard !query.isEmpty else { return keys }
        return keys.filter { key in
            if key.localizedCaseInsensitiveContains(query) { return true }
            return PlistValueInfo.info(for: plist.cacheExtra[key])
                .summary.localizedCaseInsensitiveContains(query)
        }
    }

    private var filteredTopLevel: [String] {
        guard let plist = viewModel.plist else { return [] }
        guard !query.isEmpty else { return plist.topLevelKeys }
        return plist.topLevelKeys.filter { $0.localizedCaseInsensitiveContains(query) }
    }
}

// MARK: - value editor

private struct ValueEditor: View {
    @EnvironmentObject private var viewModel: GestaltViewModel
    @Environment(\.dismiss) private var dismiss

    let key: String
    let isCacheExtra: Bool
    let value: Any?

    @State private var kind: PlistValueKind = .string
    @State private var text = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                MGCanvas()

                ScrollView {
                    VStack(spacing: 14) {
                        MGCard {
                            VStack(alignment: .leading, spacing: 6) {
                                MGSectionHeader(title: "键", symbol: "number",
                                                tint: Palette.accent, count: nil)
                                Text(key)
                                    .font(.system(size: 12, design: .monospaced))
                                    .textSelection(.enabled)
                                MGBadge(text: isCacheExtra ? "CacheExtra" : "顶层键",
                                        tint: isCacheExtra ? Palette.accent : Palette.violet)
                            }
                        }

                        MGCard {
                            VStack(alignment: .leading, spacing: 8) {
                                MGSectionHeader(title: "类型", symbol: "tag.fill",
                                                tint: Palette.violet, count: nil)
                                Picker("类型", selection: $kind) {
                                    ForEach(PlistValueKind.allCases) { k in
                                        Text(k.label).tag(k)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(Palette.violet)
                            }
                        }

                        MGCard {
                            VStack(alignment: .leading, spacing: 8) {
                                MGSectionHeader(title: "值", symbol: "text.cursor",
                                                tint: Palette.mint, count: nil)
                                TextEditor(text: $text)
                                    .font(.system(size: 12, design: .monospaced))
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 130)
                                    .padding(8)
                                    .background(Color.secondary.opacity(0.07),
                                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                if let errorMessage {
                                    Text(errorMessage)
                                        .font(.system(size: 11))
                                        .foregroundStyle(Palette.rose)
                                }
                            }
                        }

                        MGCard {
                            VStack(spacing: 9) {
                                Button {
                                    commit()
                                } label: {
                                    Text("保存到内存")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                        .background(Palette.accent,
                                                    in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.isBusy)

                                Button {
                                    remove()
                                } label: {
                                    Text("删除该键")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Palette.rose)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 11)
                                        .background(Palette.rose.opacity(0.12),
                                                    in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.isBusy)

                                Text("这里只改内存里的 plist，回字段页点「写入 plist」才落盘。")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("编辑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(Palette.accent)
                }
            }
            .onAppear {
                kind = PlistValueKind.kind(of: value)
                text = PlistValueInfo.encode(value, as: kind)
            }
            .onChange(of: kind) { _, newKind in
                text = PlistValueInfo.encode(value, as: newKind)
            }
        }
    }

    private func commit() {
        do {
            let parsed = try PlistValueInfo.parse(text, as: kind)
            guard var plist = viewModel.plist else { return }
            if isCacheExtra {
                plist.setCacheExtra(parsed, forKey: key)
            } else {
                plist.setValue(parsed, forKey: key)
            }
            viewModel.plist = plist
            errorMessage = nil
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func remove() {
        guard var plist = viewModel.plist else { return }
        if isCacheExtra {
            plist.removeCacheExtraValue(forKey: key)
        } else {
            plist.dict.removeValue(forKey: key)
        }
        viewModel.plist = plist
        dismiss()
    }
}

// MARK: - backups

private struct BackupTab: View {
    @EnvironmentObject private var viewModel: GestaltViewModel
    @State private var importing = false
    @State private var exporting: GestaltBackup?
    @State private var confirmRestore: GestaltBackup?

    var body: some View {
        VStack(spacing: 14) {
            MGCard {
                VStack(alignment: .leading, spacing: 10) {
                    MGSectionHeader(title: "备份", symbol: "externaldrive.fill",
                                    tint: Palette.accent, count: viewModel.backups.count)

                    HStack(spacing: 8) {
                        MGSegmentButton(title: "立即备份", symbol: "square.and.arrow.down",
                                        active: false, tint: Palette.accent) {
                            viewModel.createBackup()
                        }
                        MGSegmentButton(title: "从文件导入", symbol: "square.and.arrow.down.on.square",
                                        active: false, tint: Palette.violet) {
                            importing = true
                        }
                    }

                    Text("备份保存在 App 沙盒的 Documents/MobileGestalt Backups。")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            if viewModel.backups.isEmpty {
                MGCard {
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.system(size: 26, weight: .light))
                            .foregroundStyle(.quaternary)
                        Text("还没有备份")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
            } else {
                ForEach(viewModel.backups) { backup in
                    backupCard(backup)
                }
            }
        }
        .fileImporter(isPresented: $importing,
                      allowedContentTypes: [.propertyList, .xml, .data],
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                viewModel.importBackup(from: url)
            }
        }
        .sheet(item: $exporting) { backup in
            ShareSheet(items: [backup.url])
        }
        .alert("恢复这个备份？",
               isPresented: Binding(get: { confirmRestore != nil },
                                    set: { if !$0 { confirmRestore = nil } })) {
            Button("取消", role: .cancel) { confirmRestore = nil }
            Button("恢复", role: .destructive) {
                if let backup = confirmRestore { viewModel.restore(backup) }
                confirmRestore = nil
            }
        } message: {
            Text(confirmRestore?.name ?? "")
        }
    }

    private func backupCard(_ backup: GestaltBackup) -> some View {
        MGCard(padding: 14) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.badge.clock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.violet)
                        .frame(width: 26, height: 26)
                        .background(Palette.violet.opacity(0.13),
                                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(backup.name)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text("\(backup.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(backup.sizeText)")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }

                HStack(spacing: 8) {
                    MGSegmentButton(title: "恢复", symbol: "arrow.uturn.backward",
                                    active: false, tint: Palette.mint) {
                        confirmRestore = backup
                    }
                    MGSegmentButton(title: "导出", symbol: "square.and.arrow.up",
                                    active: false, tint: Palette.accent) {
                        exporting = backup
                    }
                    MGSegmentButton(title: "删除", symbol: "trash",
                                    active: false, tint: Palette.rose) {
                        viewModel.delete(backup)
                    }
                }
            }
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
