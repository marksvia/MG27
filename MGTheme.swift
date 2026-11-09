//
//  MGTheme.swift
//  MG27
//
//  Visual language: deep canvas, frosted cards, one accent per capability
//  family. Nothing here mirrors the reference app's stock Form look.
//

import SwiftUI

enum Palette {
    static let accent = dynamic(light: (0.26, 0.33, 0.92), dark: (0.47, 0.55, 1.00))
    static let mint   = dynamic(light: (0.05, 0.62, 0.50), dark: (0.30, 0.85, 0.72))
    static let amber  = dynamic(light: (0.85, 0.52, 0.05), dark: (1.00, 0.72, 0.30))
    static let rose   = dynamic(light: (0.85, 0.20, 0.32), dark: (1.00, 0.42, 0.52))
    static let violet = dynamic(light: (0.50, 0.28, 0.85), dark: (0.72, 0.50, 1.00))

    static let canvas = dynamic(light: (0.953, 0.957, 0.973), dark: (0.043, 0.047, 0.067))
    static let cardStroke = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.11)
            : UIColor(white: 0.0, alpha: 0.055)
    })

    private static func dynamic(light: (Double, Double, Double),
                                dark: (Double, Double, Double)) -> Color {
        Color(uiColor: UIColor { trait in
            let c = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }
}

// MARK: - background

struct MGCanvas: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Palette.canvas

            Circle()
                .fill(Palette.accent.opacity(scheme == .dark ? 0.30 : 0.16))
                .frame(width: 420, height: 420)
                .blur(radius: 130)
                .offset(x: -130, y: -300)

            Circle()
                .fill(Palette.mint.opacity(scheme == .dark ? 0.20 : 0.12))
                .frame(width: 340, height: 340)
                .blur(radius: 120)
                .offset(x: 150, y: -120)

            Circle()
                .fill(Palette.violet.opacity(scheme == .dark ? 0.16 : 0.10))
                .frame(width: 300, height: 300)
                .blur(radius: 130)
                .offset(x: -60, y: 340)
        }
        .ignoresSafeArea()
    }
}

// MARK: - card

struct MGCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Palette.cardStroke, Palette.cardStroke.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
            }
    }
}

// MARK: - section header

struct MGSectionHeader: View {
    let title: String
    let symbol: String
    let tint: Color
    var count: Int?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            if let count {
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.10), in: Capsule())
            }

            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - switch

struct MGSwitch: View {
    @Binding var isOn: Bool
    var tint: Color = Palette.accent

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                isOn.toggle()
            }
        } label: {
            Capsule(style: .continuous)
                .fill(isOn ? tint : Color.secondary.opacity(0.22))
                .frame(width: 46, height: 28)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(.white)
                        .frame(width: 22, height: 22)
                        .padding(3)
                        .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isOn)
    }
}

// MARK: - badge

struct MGBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy))
            .tracking(0.3)
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.15), in: Capsule())
    }
}

// MARK: - row

struct MGRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let detail: String
    var badge: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    if let badge { MGBadge(text: badge, tint: Palette.amber) }
                }
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            MGSwitch(isOn: $isOn, tint: tint)
                .padding(.top, 1)
        }
        .padding(.vertical, 9)
    }
}

// MARK: - segmented action pair

struct MGSegmentButton: View {
    let title: String
    let symbol: String
    let active: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: active ? "checkmark.circle.fill" : symbol)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(active ? tint : Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(active ? tint.opacity(0.16) : Color.secondary.opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(active ? tint.opacity(0.45) : .clear, lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - hero

struct MGHero: View {
    let deviceName: String
    let regulatory: String?
    let build: String
    let connected: Bool
    let regionCode: String?
    let regionInfo: String?
    let fieldCount: Int
    let statusLine: String
    var udid: String?

    @State private var copied = false

    var body: some View {
        MGCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Palette.accent, Palette.violet],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 48, height: 48)
                    .shadow(color: Palette.accent.opacity(0.35), radius: 10, y: 4)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(deviceName)
                            .font(.system(size: 17, weight: .bold))
                        HStack(spacing: 6) {
                            Circle()
                                .fill(connected ? Palette.mint : Palette.rose)
                                .frame(width: 6, height: 6)
                            Text(connected ? "已连接" : "未连接")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(connected ? Palette.mint : Palette.rose)
                            Text("·")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                            Text(build.isEmpty ? "iOS" : build)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }

                HStack(spacing: 8) {
                    metric("RegionCode", regionCode ?? "—",
                           tint: regionCode == "CH" ? Palette.mint : Palette.amber)
                    metric("RegionInfo", regionInfo ?? "—", tint: .secondary)
                    metric("字段", "\(fieldCount)", tint: Palette.accent)
                }

                if let regulatory, !regulatory.isEmpty {
                    Text("法规型号 \(regulatory)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                if let udid, !udid.isEmpty {
                    Button {
                        UIPasteboard.general.string = udid
                        withAnimation(.easeOut(duration: 0.2)) { copied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                            withAnimation(.easeIn(duration: 0.2)) { copied = false }
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "number.square.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Palette.accent)
                            Text(udid)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 4)
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(copied ? Palette.mint : Color.secondary.opacity(0.5))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background(Color.secondary.opacity(0.07),
                                    in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Text(statusLine)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
    }

    private func metric(_ label: String, _ value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}
