import SwiftUI
import Shared

/// "Add Masjid" sheet: search the masjids we already have, or ask us to add a new one by name and web address.
struct AddMasjidSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    enum Route: Hashable { case manual, received, requests, detail(Mosque) }

    /// Opens straight on the "Add Manually" form (used by onboarding's "Request my masjid").
    var startManual = false

    @State private var query = ""
    @State private var city = "All"
    @State private var path = NavigationPath()

    private var cities: [String] { Directory.cities(app.mosques) }
    private var shown: [Mosque] { Directory.filter(app.mosques, city: city, query: query) }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("Add Masjid").font(.system(size: 30, weight: .bold))
                        Spacer(minLength: 8)
                        Button { Haptics.tap(); path.append(Route.requests) } label: {
                            Label("My requests", systemImage: "list.bullet").font(.system(size: 16, weight: .medium)).foregroundStyle(Palette.teal)
                        }
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.text)
                                .frame(width: 38, height: 38).background(Circle().fill(Palette.surface))
                        }
                        .accessibilityLabel("Close")
                    }
                    .padding(.top, 10)

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
                        TextField("Search masjids by name, city or postcode", text: $query).autocorrectionDisabled().submitLabel(.search)
                        if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.muted) } }
                    }
                    .font(.system(size: 16)).padding(.horizontal, 14).frame(height: 50)
                    .background(Capsule().fill(Color.white).overlay(Capsule().stroke(Palette.line)))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            chip("All")
                            ForEach(cities, id: \.self) { chip($0) }
                        }
                    }

                    VStack(spacing: 0) {
                        ForEach(shown) { m in
                            Button { Haptics.tap(); path.append(Route.detail(m)) } label: { row(m) }.buttonStyle(.plain)
                            Divider().overlay(Palette.line)
                        }
                        if shown.isEmpty {
                            Text(query.isEmpty ? "No masjids here yet." : "No masjid found for “\(query.trimmingCharacters(in: .whitespaces))”.")
                                .font(.system(size: 16)).foregroundStyle(Palette.muted).multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 24)
                        }
                    }

                    HStack(spacing: 6) {
                        Text("Can't find your masjid?").foregroundStyle(Palette.muted)
                        Button("Add manually") { Haptics.tap(); path.append(Route.manual) }.fontWeight(.semibold).foregroundStyle(Palette.teal)
                    }
                    .font(.system(size: 17)).frame(maxWidth: .infinity).padding(.top, 6)
                }
                .padding(.horizontal, 20).padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Palette.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { r in
                switch r {
                case .manual: RequestForm(onSent: { path = NavigationPath(); path.append(Route.received) })
                case .received: RequestReceived(done: { dismiss() })
                case .requests: RequestsPage()
                case .detail(let m): MasjidDetailView(mosque: m)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { if startManual && path.isEmpty { path.append(Route.manual) } }
    }

    private func chip(_ c: String) -> some View {
        Button { Haptics.tap(); withAnimation(.easeInOut(duration: 0.2)) { city = c } } label: {
            Text(c).font(.system(size: 16, weight: .medium)).padding(.horizontal, 18).padding(.vertical, 10)
                .background(Capsule().fill(city == c ? Palette.teal : Palette.surface))
                .foregroundStyle(city == c ? Color.white : Palette.text)
        }
    }

    private func row(_ m: Mosque) -> some View {
        HStack(spacing: 16) {
            MasjidLogo(mosque: m, size: 70)
            VStack(alignment: .leading, spacing: 3) {
                Text(m.name).font(.system(size: 20, weight: .bold)).foregroundStyle(Palette.text).multilineTextAlignment(.leading).lineLimit(2)
                Text(Directory.cityOf(m)).font(.system(size: 16)).foregroundStyle(Palette.muted)
                if !m.shortLine.isEmpty { Text(m.shortLine).font(.system(size: 15)).foregroundStyle(Palette.muted) }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.muted)
        }
        .padding(.vertical, 12).contentShape(Rectangle())
    }
}

/// Shown after a request is sent.
private struct RequestReceived: View {
    let done: () -> Void
    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "checkmark").font(.system(size: 52, weight: .medium)).foregroundStyle(Palette.teal)
                .frame(width: 130, height: 130).background(RoundedRectangle(cornerRadius: 38, style: .continuous).fill(Palette.tealSoft))
            Text("Request Received").font(.system(size: 34, weight: .bold)).padding(.top, 10)
            Text("We'll work on adding this masjid's prayer times to the app.")
                .font(.system(size: 19)).foregroundStyle(Palette.muted).multilineTextAlignment(.center).padding(.horizontal, 30)
            Spacer()
            Button("Done") { Haptics.tap(); done() }.buttonStyle(TealButtonStyle())
        }
        .padding(.horizontal, 20).padding(.bottom, 24)
        .background(Palette.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }
}

/// "My requests" page with a back button.
private struct RequestsPage: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("My requests").font(.system(size: 30, weight: .bold))
                MyRequestsList()
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 30)
        }
        .safeAreaInset(edge: .top, spacing: 0) { BackBar { dismiss() } }
        .background(Palette.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct BackBar: View {
    let action: () -> Void
    var body: some View {
        HStack {
            Button { Haptics.tap(); action() } label: { RoundIcon(system: "chevron.left", size: 44) }.accessibilityLabel("Back")
            Spacer()
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
    }
}

// MARK: - Request form

struct RequestForm: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    let onSent: () -> Void

    private enum Phase: Equatable { case idle, sending, failed(String) }
    @State private var name = ""
    @State private var url = ""
    @State private var phase: Phase = .idle
    @FocusState private var focused: Bool

    private var cleaned: String? { RequestURL.clean(url) }
    private var canSend: Bool { cleaned != nil && !name.trimmingCharacters(in: .whitespaces).isEmpty && phase != .sending }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Add Manually").font(.system(size: 30, weight: .bold)).padding(.top, 4)
                Text("Enter the masjid details to request that we add its prayer times.")
                    .font(.system(size: 17)).foregroundStyle(Palette.muted).multilineTextAlignment(.center).padding(.bottom, 8)

                field(icon: "dome") {
                    TextField("Masjid name", text: $name).textInputAutocapitalization(.words).focused($focused)
                }
                field(icon: "link") {
                    TextField("Prayer timetable website URL", text: $url).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                }

                if case .failed(let m) = phase { Label(m, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.system(size: 15)) }

                Button { Task { await send() } } label: {
                    if phase == .sending { ProgressView().tint(.white) } else { Text("Submit Request") }
                }
                .buttonStyle(TealButtonStyle(enabled: canSend)).disabled(!canSend).padding(.top, 8)

                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "info.circle").font(.system(size: 24)).foregroundStyle(Palette.teal)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Our team will work on adding the masjid's prayer times within 48 hours.").font(.system(size: 17))
                        Text("New masjids may take up to 48 hours to appear in the app.").font(.system(size: 16)).foregroundStyle(Palette.muted)
                    }
                }
                .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.nextRow.opacity(0.7)))
                .padding(.top, 8)
            }
            .padding(.horizontal, 20).padding(.bottom, 24)
        }
        .safeAreaInset(edge: .top, spacing: 0) { BackBar { dismiss() } }
        .background(Palette.bg.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func field<C: View>(icon: String, @ViewBuilder content: () -> C) -> some View {
        HStack(spacing: 16) {
            Group { if icon == "dome" { DomeGlyph(size: 26) } else { Image(systemName: icon).font(.system(size: 20)) } }
                .foregroundStyle(Palette.teal).frame(width: 30)
            content().font(.system(size: 18))
        }
        .padding(.horizontal, 18).frame(minHeight: 60)
        .background(Capsule().fill(Color.white).overlay(Capsule().stroke(Palette.line)))
    }

    private func send() async {
        guard let u = cleaned else { return }
        focused = false
        phase = .sending
        do {
            try await app.sendRequest(url: u, name: name.trimmingCharacters(in: .whitespaces))
            Haptics.success()
            app.showToast("Request sent. See My Requests")
            onSent()
        } catch API.Failure.http(let code) {
            Haptics.warning()
            phase = .failed(code == 429 ? "Too many requests. Please try again in an hour." : (code == 400 || code == 422) ? "That address does not look right. Check it and try again." : "Something went wrong. Please try again.")
        } catch {
            Haptics.warning()
            phase = .failed("No connection. Check your internet and try again.")
        }
    }
}

// MARK: - My requests

struct MyRequestsList: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            if app.requests.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray").font(.system(size: 34)).foregroundStyle(Palette.muted)
                    Text("No requests yet").font(.system(size: 19, weight: .semibold))
                    Text("When you ask us to add a masjid, it shows up here with what happened to it.").font(.system(size: 15)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                }
                .padding(.top, 40)
            } else {
                ForEach(app.requests) { r in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "building.columns").font(.system(size: 20)).foregroundStyle(Palette.teal)
                            .frame(width: 46, height: 46).background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.tealSoft))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(r.name).font(.system(size: 18, weight: .bold))
                            Text(URL(string: r.url)?.host ?? r.url).font(.system(size: 14)).foregroundStyle(Palette.muted).lineLimit(1)
                            statusChip(r.status)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 14)
                    Divider().overlay(Palette.line)
                }
            }
        }
        .task { await app.refreshRequests() }
    }

    private func statusChip(_ s: String) -> some View {
        let (text, tint, wash): (String, Color, Color) = {
            switch s {
            case "added": return ("Added: now in the app", Palette.teal, Palette.tealSoft)
            case "closed": return ("Could not be added", Palette.coral, Palette.coralSoft)
            default: return ("Received: we are looking at it", Palette.goldDeep, Palette.gold.opacity(0.18))
            }
        }()
        return Text(text).font(.system(size: 13, weight: .semibold)).foregroundStyle(tint)
            .padding(.horizontal, 10).padding(.vertical, 4).background(Capsule().fill(wash))
    }
}
