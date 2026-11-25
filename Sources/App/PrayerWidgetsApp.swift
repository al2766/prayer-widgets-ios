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
            .tint(Palette.amber)
            .task { await app.bootstrap() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active && app.bootstrapped { Task { await app.refreshDefault() } }   // new day, new times
            }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        TabView(selection: $app.selectedTab) {
            HomeView().tabItem { Label("Home", systemImage: "house") }.tag(0)
            MasjidsView().tabItem { Label("Masjids", systemImage: "building.columns") }.tag(1)
            QiblaView().tabItem { Label("Qibla", systemImage: "safari") }.tag(2)
            WidgetTab().tabItem { Label("Widget", systemImage: "square.grid.2x2") }.tag(3)
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }.tag(4)
        }
        .overlay(alignment: .bottom) {
            if let t = app.toast {
                Text(t).font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Capsule().fill(Palette.navy))
                    .padding(.bottom, 96)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityAddTraits(.isStaticText)
            }
        }
    }
}
