import SwiftUI
import Shared

struct WidgetTab: View {
    private enum Pane { case customise, how }
    @State private var pane: Pane = .customise

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                HStack(spacing: 4) {
                    seg("Customise", "slider.horizontal.3", .customise)
                    seg("How to", "book", .how)
                }
                .padding(4).background(Capsule().fill(Palette.surface))
                .padding(.horizontal, 20).padding(.top, 10)

                switch pane {
                case .customise: CustomisePane()
                case .how: HowToPane()
                }
            }
            .background(Palette.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func seg(_ title: String, _ icon: String, _ p: Pane) -> some View {
        Button { Haptics.tap(); withAnimation(.easeInOut(duration: 0.2)) { pane = p } } label: {
            Label(title, systemImage: icon).font(.system(size: 19, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 54)
                .foregroundStyle(pane == p ? Color.white : Palette.text)
                .background(Capsule().fill(pane == p ? Palette.tealDeep : Color.clear))
        }
    }
}

// MARK: - Customise

private struct CustomisePane: View {
    @EnvironmentObject var app: AppState
    @State private var sheet: OptionSheetKind?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                section(.small)
                section(.medium)
                Text("Widgets follow your default masjid. Change it in the Masjids tab.")
                    .font(.system(size: 14)).foregroundStyle(Palette.muted)
            }
            .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 24)
        }
        .sheet(item: $sheet) { OptionSheet(kind: $0) }
    }

    private func preview(_ size: WidgetSize) -> some View {
        WidgetPreviewCard(day: app.defaultDay, theme: app.theme(size), layout: app.layout(size).resolved(for: size), size: size, now: Date())
    }

    @ViewBuilder private func section(_ size: WidgetSize) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Palette.tealMid.opacity(0.85)).frame(width: size == .small ? 26 : 34, height: 24)
                Text(size.title).font(.system(size: 27, weight: .bold)).foregroundStyle(Palette.tealDeep)
            }
            if size == .small {
                HStack(spacing: 18) {
                    preview(size)
                    VStack(alignment: .leading, spacing: 14) {
                        optionRow("Theme", "paintpalette") { sheet = OptionSheetKind(size: size, theme: true) }
                        optionRow("Layout", "square.grid.2x2") { sheet = OptionSheetKind(size: size, theme: false) }
                    }
                }
            } else {
                preview(size)
                HStack {
                    optionRow("Theme", "paintpalette") { sheet = OptionSheetKind(size: size, theme: true) }
                    Spacer(minLength: 4)
                    optionRow("Layout", "square.grid.2x2") { sheet = OptionSheetKind(size: size, theme: false) }
                }
                .padding(.horizontal, 6)
            }
        }
    }

    private func optionRow(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 20)).foregroundStyle(Palette.text)
                    .frame(width: 48, height: 48).background(Circle().fill(Palette.surface))
                Text(title).font(.system(size: 20, weight: .bold)).foregroundStyle(Palette.text)
                Image(systemName: "chevron.right").font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.text)
            }
        }
    }
}

struct OptionSheetKind: Identifiable {
    let size: WidgetSize
    let theme: Bool
    var id: String { "\(size.rawValue).\(theme)" }
}

/// One preview at a time, swipe or use the arrows; nothing is saved until "Set".
private struct OptionSheet: View {
    let kind: OptionSheetKind
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0

    private var themes: [WidgetTheme] { WidgetTheme.all }
    private var layouts: [WidgetLayout] { WidgetLayout.allCases.filter { $0.supports(kind.size) } }
    private var count: Int { kind.theme ? themes.count : layouts.count }

    var body: some View {
        VStack(spacing: 16) {
            Text("\(kind.size.title) · \(kind.theme ? "Theme" : "Layout")").font(.system(size: 22, weight: .bold)).padding(.top, 24)
            HStack {
                arrow("chevron.left") { go(-1) }
                TabView(selection: $index) {
                    ForEach(0..<count, id: \.self) { i in preview(i).tag(i).frame(maxWidth: .infinity) }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 178)
                arrow("chevron.right") { go(1) }
            }
            .padding(.horizontal, 8)
            HStack(spacing: 7) {
                ForEach(0..<count, id: \.self) { i in Circle().fill(i == index ? Palette.teal : Palette.line).frame(width: 8, height: 8) }
            }
            VStack(spacing: 3) {
                Text(title(index)).font(.system(size: 17, weight: .semibold))
                Text(subtitle(index)).font(.system(size: 14)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                if isCurrent(index) { Text("Currently set").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.goldDeep) }
            }
            .padding(.horizontal, 24)
            Button("Set") { set(index); dismiss() }.buttonStyle(TealButtonStyle()).padding(.horizontal, 20)
            Spacer(minLength: 0)
        }
        .background(Palette.bg.ignoresSafeArea())
        .presentationDetents([.height(520)])
        .presentationDragIndicator(.visible)
        .onAppear {
            index = kind.theme ? (themes.firstIndex { $0.id == app.themeIds[kind.size] } ?? 0)
                               : (layouts.firstIndex { $0.rawValue == app.layoutIds[kind.size] } ?? 0)
        }
    }

    @ViewBuilder private func preview(_ i: Int) -> some View {
        if kind.theme {
            WidgetPreviewCard(day: app.defaultDay, theme: themes[i], layout: app.layout(kind.size).resolved(for: kind.size), size: kind.size, now: Date())
        } else {
            WidgetPreviewCard(day: app.defaultDay, theme: app.theme(kind.size), layout: layouts[i], size: kind.size, now: Date())
        }
    }
    private func title(_ i: Int) -> String { kind.theme ? themes[i].name : layouts[i].title }
    private func subtitle(_ i: Int) -> String { kind.theme ? "Colours only. Your layout stays the same." : layouts[i].blurb }
    private func isCurrent(_ i: Int) -> Bool { kind.theme ? themes[i].id == app.themeIds[kind.size] : layouts[i].rawValue == app.layoutIds[kind.size] }
    private func set(_ i: Int) { if kind.theme { app.setTheme(themes[i], for: kind.size) } else { app.setLayout(layouts[i], for: kind.size) } }

    private func go(_ d: Int) {
        Haptics.tap()
        withAnimation(.easeInOut(duration: 0.25)) { index = min(max(index + d, 0), count - 1) }
    }
    private func arrow(_ name: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: name).font(.system(size: 18, weight: .semibold)).foregroundStyle(Palette.teal).frame(width: 36, height: 44) }
    }
}

// MARK: - How to

private struct HowToPane: View {
    private enum Where { case home, lock }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spot: Where = .home
    @State private var pulse = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                HStack(spacing: 4) {
                    spotButton("Home screen", .home)
                    spotButton("Lock screen", .lock)
                }
                .padding(4).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.surface))

                if spot == .home {
                    step(1, "Long-press your home screen", "Touch and hold an empty spot until the icons start to wiggle.") { Demo1(pulse: pulse) }
                    step(2, "Tap Add Widget", "Tap the + button in the top corner, or Edit then Add Widget.") { Demo2(pulse: pulse) }
                    step(3, "Choose Prayer Widgets", "Search for Prayer Widgets, swipe to a size, then tap Add Widget. It shows your default masjid. To change it, use the Masjids tab.") { Demo3(pulse: pulse) }
                } else {
                    Text("The lock screen is small, so the timetable comes in two halves. Add both and they sit side by side.")
                        .font(.system(size: 16)).foregroundStyle(Palette.muted).frame(maxWidth: .infinity, alignment: .leading)
                    step(1, "Open Customise", "Wake the phone, then touch and hold the lock screen. Tap Customise, then Lock Screen.") { LockDemo1(pulse: pulse) }
                    step(2, "Tap the row under the time", "Tap the box under the clock to open the widget list.") { LockDemo2(pulse: pulse) }
                    step(3, "Add Left, then Right", "Choose Prayer Widgets. Tap “Prayer times · Left” (Fajr, Sunrise, Dhuhr). Then add “Prayer times · Right” (Asr, Maghrib, Isha) next to it.") { LockDemo3(pulse: pulse) }
                }
            }
            .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 24)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: false)) { pulse = true }
        }
    }

    private func spotButton(_ title: String, _ w: Where) -> some View {
        Button { Haptics.tap(); withAnimation(.easeInOut(duration: 0.2)) { spot = w } } label: {
            Text(title).font(.system(size: 16, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 42)
                .foregroundStyle(Palette.text)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(spot == w ? Color.white : Color.clear))
        }
    }

    private func step<D: View>(_ n: Int, _ title: String, _ text: String, @ViewBuilder demo: () -> D) -> some View {
        HStack(alignment: .center, spacing: 16) {
            demo().frame(width: 128, height: 210)
            VStack(alignment: .leading, spacing: 6) {
                Text("\(n)").font(.system(size: 13, weight: .bold)).foregroundStyle(.white).frame(width: 24, height: 24).background(Circle().fill(Palette.coral))
                Text(title).font(.system(size: 18, weight: .bold))
                Text(text).font(.system(size: 15)).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct MiniPhone<Content: View>: View {
    var dark = false
    @ViewBuilder var content: Content
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(dark ? Palette.tealDeep : Color(hex: 0xE9E3D6))
            RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Palette.tealDeep, lineWidth: 3)
            content.padding(.horizontal, 10).padding(.top, 22).padding(.bottom, 10)
            Capsule().fill(dark ? Color.white.opacity(0.7) : Palette.tealDeep).frame(width: 34, height: 6).frame(maxHeight: .infinity, alignment: .top).padding(.top, 7)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct IconGrid: View {
    var wiggle = false
    var body: some View {
        VStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { r in
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { c in
                        RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(hex: [0x9CC3C9, 0xE8A24A, 0x6B8F71, 0xD9694A][(r + c) % 4]).opacity(0.85))
                            .frame(height: 26)
                            .rotationEffect(.degrees(wiggle ? ((r + c) % 2 == 0 ? 2.5 : -2.5) : 0))
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

/// A finger tap with an expanding ring.
private struct Touch: View {
    let pulse: Bool
    var light = false
    var body: some View {
        ZStack {
            Circle().stroke(Palette.gold, lineWidth: 3).frame(width: 34, height: 34).scaleEffect(pulse ? 1.7 : 0.5).opacity(pulse ? 0 : 0.9)
            Image(systemName: "hand.point.up.left.fill").font(.system(size: 22)).foregroundStyle(light ? Color.white : Palette.tealDeep).offset(x: 8, y: 14)
        }
    }
}

private struct Demo1: View {
    let pulse: Bool
    var body: some View {
        MiniPhone {
            ZStack(alignment: .bottomLeading) {
                IconGrid()
                Touch(pulse: pulse).offset(x: 8, y: -22)
            }
        }
    }
}

private struct Demo2: View {
    let pulse: Bool
    var body: some View {
        MiniPhone {
            ZStack(alignment: .topLeading) {
                IconGrid(wiggle: true).padding(.top, 18)
                HStack(spacing: 3) { Image(systemName: "plus"); Text("Add").font(.system(size: 9, weight: .bold)) }
                    .font(.system(size: 9, weight: .bold)).foregroundStyle(.white).padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Capsule().fill(Palette.tealDeep))
                Touch(pulse: pulse).offset(x: 6, y: 0)
            }
        }
    }
}

private struct Demo3: View {
    let pulse: Bool
    var body: some View {
        MiniPhone {
            VStack(spacing: 8) {
                Spacer(minLength: 0)
                VStack(spacing: 6) {
                    Capsule().fill(Palette.line).frame(width: 26, height: 3)
                    Text("Prayer Widgets").font(.system(size: 9, weight: .bold))
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 6).fill(Palette.tealDeep).frame(width: 36, height: 36)
                        RoundedRectangle(cornerRadius: 6).fill(Palette.tealDeep).frame(width: 60, height: 36)
                    }
                    .offset(x: pulse ? -12 : 12)
                    Text("Add Widget").font(.system(size: 9, weight: .bold)).foregroundStyle(.white).padding(.horizontal, 10).padding(.vertical, 4).background(Capsule().fill(Palette.coral))
                }
                .padding(8).frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white))
            }
        }
    }
}

// MARK: Lock screen demos

private struct LockDemo1: View {
    let pulse: Bool
    var body: some View {
        MiniPhone(dark: true) {
            VStack(spacing: 6) {
                Text("9:41").font(.system(size: 30, weight: .bold)).foregroundStyle(.white).padding(.top, 8)
                Spacer(minLength: 0)
                ZStack {
                    Capsule().fill(Color.white.opacity(0.22)).frame(width: 72, height: 22)
                    Text("Customise").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                    Touch(pulse: pulse, light: true).offset(x: 24, y: 6)
                }
                .padding(.bottom, 8)
            }
        }
    }
}

private struct LockDemo2: View {
    let pulse: Bool
    var body: some View {
        MiniPhone(dark: true) {
            VStack(spacing: 8) {
                Text("9:41").font(.system(size: 30, weight: .bold)).foregroundStyle(.white).padding(.top, 8)
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(Color.white.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])).frame(width: 96, height: 30)
                    Image(systemName: "plus").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                    Touch(pulse: pulse, light: true).offset(x: 14, y: 8)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct LockDemo3: View {
    let pulse: Bool
    var body: some View {
        MiniPhone(dark: true) {
            VStack(spacing: 8) {
                Text("9:41").font(.system(size: 30, weight: .bold)).foregroundStyle(.white).padding(.top, 8)
                HStack(spacing: 4) {
                    half("Left", ["Fajr", "Rise", "Dhuhr"]).offset(x: pulse ? 0 : -14).opacity(pulse ? 1 : 0.5)
                    half("Right", ["Asr", "Magh", "Isha"]).offset(x: pulse ? 0 : 14).opacity(pulse ? 1 : 0.5)
                }
                Text("Left + Right").font(.system(size: 9, weight: .semibold)).foregroundStyle(Palette.gold)
                Spacer(minLength: 0)
            }
        }
    }

    private func half(_ title: String, _ names: [String]) -> some View {
        VStack(spacing: 2) {
            Text(names.joined(separator: " ")).font(.system(size: 6, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.5)
            Text("00:00").font(.system(size: 6)).opacity(0.7)
            Text("00:00").font(.system(size: 6)).opacity(0.7)
        }
        .foregroundStyle(.white).padding(4).frame(width: 52, height: 28)
        .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.white.opacity(0.22)))
    }
}
