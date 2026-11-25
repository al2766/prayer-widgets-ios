import SwiftUI
import Shared

struct WidgetTab: View {
    private enum Pane: String, CaseIterable { case themes = "Themes", layouts = "Layouts", how = "How to Add" }
    @State private var section: Pane = .themes

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 4) {
                    ForEach(Pane.allCases, id: \.self) { s in
                        Button { Haptics.tap(); withAnimation(.easeInOut(duration: 0.2)) { section = s } } label: {
                            Text(s.rawValue).font(.system(size: 15, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 38)
                                .background(Capsule().fill(section == s ? Palette.navy : Color.clear))
                                .foregroundStyle(section == s ? Color.white : Palette.text)
                        }
                    }
                }
                .padding(4).background(Capsule().fill(Palette.surface))
                .padding(.horizontal, 20).padding(.top, 8)

                switch section {
                case .themes: ThemesPane()
                case .layouts: LayoutsPane()
                case .how: HowToAddPane()
                }
            }
            .background(Palette.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

/// One preview at a time, swipe or use the arrows, nothing is saved until "Set".
private struct Carousel<Item: Identifiable, Preview: View>: View {
    let items: [Item]
    @Binding var index: Int
    let title: (Item) -> String
    let subtitle: (Item) -> String
    let preview: (Item) -> Preview
    let isCurrent: (Item) -> Bool
    let set: (Item) -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                arrow("chevron.left") { go(-1) }
                TabView(selection: $index) {
                    ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                        preview(item).tag(i).frame(maxWidth: .infinity)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 178)
                arrow("chevron.right") { go(1) }
            }
            .padding(.horizontal, 8)

            HStack(spacing: 7) {
                ForEach(items.indices, id: \.self) { i in Circle().fill(i == index ? Palette.navy : Palette.line).frame(width: 8, height: 8) }
            }
            VStack(spacing: 3) {
                Text(title(items[index])).font(.system(size: 17, weight: .semibold))
                Text(subtitle(items[index])).font(.system(size: 14)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                if isCurrent(items[index]) { Text("Currently set").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.amber) }
            }
            .padding(.horizontal, 24)
            Button("Set") { set(items[index]) }.buttonStyle(NavyButtonStyle()).padding(.horizontal, 20)
            Spacer(minLength: 0)
        }
    }

    private func go(_ d: Int) {
        Haptics.tap()
        withAnimation(.easeInOut(duration: 0.25)) { index = min(max(index + d, 0), items.count - 1) }
    }
    private func arrow(_ name: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: name).font(.system(size: 18, weight: .semibold)).foregroundStyle(Palette.navy).frame(width: 36, height: 44) }
    }
}

private struct ThemesPane: View {
    @EnvironmentObject var app: AppState
    @State private var index = 0

    var body: some View {
        Carousel(items: WidgetTheme.all, index: $index,
                 title: { $0.name }, subtitle: { _ in "Colours only. Your layout stays the same." },
                 preview: { t in WidgetPreviewCard(day: app.defaultDay, theme: t, layout: app.layout, size: app.layout.previewSize, now: Date()) },
                 isCurrent: { $0.id == app.themeId }, set: { app.setTheme($0) })
            .onAppear { index = WidgetTheme.all.firstIndex { $0.id == app.themeId } ?? 0 }
    }
}

private struct LayoutsPane: View {
    @EnvironmentObject var app: AppState
    @State private var index = 0

    var body: some View {
        Carousel(items: WidgetLayout.allCases, index: $index,
                 title: { "\($0.title) (\($0.previewSize == .small ? "small" : "medium"))" }, subtitle: { $0.blurb },
                 preview: { l in WidgetPreviewCard(day: app.defaultDay, theme: app.theme, layout: l, size: l.previewSize, now: Date()) },
                 isCurrent: { $0.rawValue == app.layoutId }, set: { app.setLayout($0) })
            .onAppear { index = WidgetLayout.allCases.firstIndex { $0.rawValue == app.layoutId } ?? 0 }
    }
}

// MARK: - How to add

private struct HowToAddPane: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                step(1, "Long-press your home screen", "Touch and hold an empty spot until the icons start to wiggle.") { Demo1(pulse: pulse) }
                step(2, "Tap Add Widget", "Tap the + button in the top corner, or Edit then Add Widget.") { Demo2(pulse: pulse) }
                step(3, "Choose Prayer Widgets", "Search for Prayer Widgets, swipe to a size, then tap Add Widget. Hold the widget and tap Edit Widget to pick a masjid.") { Demo3(pulse: pulse) }
            }
            .padding(.horizontal, 20).padding(.bottom, 24)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: false)) { pulse = true }
        }
    }

    private func step<D: View>(_ n: Int, _ title: String, _ text: String, @ViewBuilder demo: () -> D) -> some View {
        HStack(alignment: .center, spacing: 16) {
            demo().frame(width: 128, height: 210)
            VStack(alignment: .leading, spacing: 6) {
                Text("\(n)").font(.system(size: 13, weight: .bold)).foregroundStyle(.white).frame(width: 24, height: 24).background(Circle().fill(Palette.amber))
                Text(title).font(.system(size: 18, weight: .bold))
                Text(text).font(.system(size: 15)).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct MiniPhone<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(hex: 0xE9E1D2))
            RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Palette.navy, lineWidth: 3)
            content.padding(.horizontal, 10).padding(.top, 22).padding(.bottom, 10)
            Capsule().fill(Palette.navy).frame(width: 34, height: 6).frame(maxHeight: .infinity, alignment: .top).padding(.top, 7)
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
                        RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(hex: [0x9FB0C8, 0xE8A24A, 0x6B8F71, 0xC96B5A][(r + c) % 4]).opacity(0.85))
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
    var body: some View {
        ZStack {
            Circle().stroke(Palette.amber, lineWidth: 3).frame(width: 34, height: 34).scaleEffect(pulse ? 1.7 : 0.5).opacity(pulse ? 0 : 0.9)
            Image(systemName: "hand.point.up.left.fill").font(.system(size: 22)).foregroundStyle(Palette.navy).offset(x: 8, y: 14)
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
                    .background(Capsule().fill(Palette.navy))
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
                        RoundedRectangle(cornerRadius: 6).fill(Palette.navy).frame(width: 36, height: 36)
                        RoundedRectangle(cornerRadius: 6).fill(Palette.navy).frame(width: 60, height: 36)
                    }
                    .offset(x: pulse ? -12 : 12)
                    Text("Add Widget").font(.system(size: 9, weight: .bold)).foregroundStyle(.white).padding(.horizontal, 10).padding(.vertical, 4).background(Capsule().fill(Palette.amber))
                }
                .padding(8).frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white))
            }
        }
    }
}
