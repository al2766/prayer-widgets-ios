import SwiftUI
import Shared

@main
struct PrayerWidgetsApp: App {
    @StateObject private var app = AppState()
    @State private var showLaunch = true
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                if showLaunch {
                    LaunchView(ready: app.bootstrapped) { withAnimation(.easeInOut(duration: 0.45)) { showLaunch = false } }
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .environmentObject(app)
            .preferredColorScheme(.light)
            .tint(Palette.teal)
            .task { await app.bootstrap() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active && app.bootstrapped { Task { await app.refreshDefault() } }   // new day, new times
            }
        }
    }
}

private struct TabSpec: Identifiable {
    let id: Int
    let title: String
    let icon: String
    let tint: Color
    let wash: Color
}

private let tabs: [TabSpec] = [
    TabSpec(id: 0, title: "Home", icon: "house.fill", tint: Palette.teal, wash: Palette.tealSoft),
    TabSpec(id: 1, title: "Masjids", icon: "building.columns", tint: Palette.coral, wash: Palette.coralSoft),
    TabSpec(id: 2, title: "Qibla", icon: "safari.fill", tint: Palette.teal, wash: Palette.tealSoft),
    TabSpec(id: 3, title: "Widget", icon: "square.grid.2x2.fill", tint: Palette.teal, wash: Palette.tealSoft),
    TabSpec(id: 4, title: "Settings", icon: "gearshape.fill", tint: Palette.teal, wash: Palette.tealSoft),
]

struct RootView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        TabView(selection: $app.selectedTab) {
            HomeView().toolbar(.hidden, for: .tabBar).tag(0)
            MasjidsView().toolbar(.hidden, for: .tabBar).tag(1)
            QiblaView().toolbar(.hidden, for: .tabBar).tag(2)
            WidgetTab().toolbar(.hidden, for: .tabBar).tag(3)
            SettingsView().toolbar(.hidden, for: .tabBar).tag(4)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
        .overlay(alignment: .bottom) {
            if let t = app.toast {
                Text(t).font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Capsule().fill(Palette.teal))
                    .padding(.bottom, 104)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityAddTraits(.isStaticText)
            }
        }
    }

    /// Floating pill, as in the mockups: the chosen tab sits in a tinted capsule.
    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(tabs) { t in
                let on = app.selectedTab == t.id
                Button {
                    if !on { Haptics.tap(); withAnimation(.easeInOut(duration: 0.2)) { app.selectedTab = t.id } }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: t.icon).font(.system(size: 22)).frame(height: 26)
                        Text(t.title).font(.system(size: 12, weight: on ? .semibold : .medium))
                    }
                    .foregroundStyle(on ? t.tint : Palette.text)
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background(Capsule().fill(on ? t.wash : Color.clear))
                    .contentShape(Capsule())
                }
                .accessibilityLabel(t.title)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(6)
        .background(Capsule().fill(Color.white).shadow(color: Color.black.opacity(0.10), radius: 14, y: 4))
        .padding(.horizontal, 14).padding(.bottom, 4)
    }
}
