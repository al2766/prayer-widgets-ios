import SwiftUI
import Shared

struct MasjidsView: View {
    @EnvironmentObject var app: AppState
    @State private var city = "All"
    @State private var query = ""
    @State private var searching = false
    @State private var showRequest = false
    @FocusState private var searchFocus: Bool

    private static let other = "Other"

    private var cities: [String] {
        let set = Set(app.mosques.map { $0.city?.isEmpty == false ? $0.city! : Self.other })
        let sorted = set.filter { $0 != Self.other }.sorted() + (set.contains(Self.other) ? [Self.other] : [])
        return ["All"] + sorted
    }

    private var shown: [Mosque] {
        app.mosques.filter { m in
            let c = m.city?.isEmpty == false ? m.city! : Self.other
            let cityOK = city == "All" || c == city
            let q = query.trimmingCharacters(in: .whitespaces)
            let queryOK = q.isEmpty || m.name.localizedCaseInsensitiveContains(q) || c.localizedCaseInsensitiveContains(q)
            return cityOK && queryOK
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                topBar
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if let msg = app.mosquesMessage, !app.mosques.isEmpty { Text(msg).font(.footnote).foregroundStyle(.orange).padding(.vertical, 6) }
                        if app.mosques.isEmpty {
                            emptyText(app.loadingMosques ? "Loading masjids…" : (app.mosquesMessage ?? "No masjids yet."))
                        } else if shown.isEmpty {
                            emptyText(query.isEmpty ? "No masjids in \(city) yet." : "No masjids match “\(query)”.")
                        }
                        ForEach(shown) { m in
                            NavigationLink(value: m) { row(m) }.buttonStyle(.plain)
                            Divider().overlay(Palette.line).padding(.leading, 56)
                        }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 90)
                }
                .refreshable { await app.loadMosques() }
            }
            .background(Palette.bg.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                Button { Haptics.tap(); showRequest = true } label: { Label("Request a New Masjid", systemImage: "plus") }
                    .buttonStyle(NavyButtonStyle())
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Palette.bg.opacity(0.95))
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Mosque.self) { MasjidDetailView(mosque: $0) }
            .navigationDestination(isPresented: $showRequest) { RequestView() }
        }
    }

    private var topBar: some View {
        VStack(spacing: 8) {
            HStack {
                if searching {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
                        TextField("Search masjids or cities", text: $query).focused($searchFocus).submitLabel(.search).autocorrectionDisabled()
                        if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.muted) } }
                    }
                    .padding(10).background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.surface))
                    Button("Cancel") { withAnimation { searching = false; query = ""; searchFocus = false } }.foregroundStyle(Palette.navy)
                } else {
                    Spacer()
                    Button { Haptics.tap(); withAnimation { searching = true }; searchFocus = true } label: {
                        Image(systemName: "magnifyingglass").font(.system(size: 20)).foregroundStyle(Palette.text).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Search")
                }
            }
            .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(cities, id: \.self) { c in
                        Button { Haptics.tap(); withAnimation(.easeInOut(duration: 0.2)) { city = c } } label: {
                            Text(c).font(.system(size: 15, weight: .medium))
                                .padding(.horizontal, 16).padding(.vertical, 8)
                                .background(Capsule().fill(city == c ? Palette.navy : Palette.surface))
                                .foregroundStyle(city == c ? Color.white : Palette.text)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 6).padding(.bottom, 8)
    }

    private func row(_ m: Mosque) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "building.columns").foregroundStyle(Palette.navy).frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(m.name).font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.text).multilineTextAlignment(.leading)
                Text(m.city ?? Self.other).font(.system(size: 14)).foregroundStyle(Palette.muted)
            }
            Spacer()
            if m.slug == app.defaultSlug { DefaultBadge() }
            Image(systemName: "chevron.right").font(.system(size: 14)).foregroundStyle(Palette.muted)
        }
        .padding(.vertical, 14).contentShape(Rectangle())
    }

    private func emptyText(_ s: String) -> some View {
        Text(s).foregroundStyle(Palette.muted).multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.top, 50)
    }
}

struct DefaultBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill").font(.system(size: 11))
            Text("Default").font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(Color(hex: 0x8A5A12))
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(Palette.amberSoft.opacity(0.7)))
    }
}

struct MasjidDetailView: View {
    @EnvironmentObject var app: AppState
    let mosque: Mosque

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(mosque.name).font(.system(size: 28, weight: .bold))
                    Label([mosque.city, "UK"].compactMap { $0 }.joined(separator: ", "), systemImage: "mappin.and.ellipse").font(.system(size: 15)).foregroundStyle(Palette.muted)
                    if mosque.slug == app.defaultSlug { DefaultBadge() }
                }
                if let day = app.days[mosque.slug] {
                    TimelineView(.periodic(from: Date(), by: 30)) { ctx in
                        VStack(spacing: 14) {
                            if !TimeLogic.isToday(day, now: ctx.date) { OldTimesBanner(day: day) }
                            TimetableView(day: day, now: ctx.date)
                            FreshnessFooter(day: day, note: app.dayNotes[mosque.slug], now: ctx.date)
                        }
                    }
                } else {
                    Text(app.dayNotes[mosque.slug] ?? "Loading times…").foregroundStyle(Palette.muted)
                }
                if mosque.slug == app.defaultSlug {
                    Button("Default masjid") {}.buttonStyle(NavyButtonStyle(enabled: false)).disabled(true)
                } else {
                    Button("Set as Default") { Task { await app.setDefault(mosque) } }.buttonStyle(NavyButtonStyle())
                }
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
        }
        .background(Palette.bg.ignoresSafeArea())
        .toolbar(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .task { await app.loadDay(mosque.slug) }
        .refreshable { await app.loadDay(mosque.slug) }
    }
}

struct RequestView: View {
    private enum Phase: Equatable { case idle, sending, done, failed(String) }
    @State private var url = ""
    @State private var phase: Phase = .idle
    @FocusState private var focused: Bool

    /// Accepts "https://…" or "http://…". A bare "example.org/times" gets https:// added.
    private var cleaned: String? {
        let t = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !t.contains(" ") else { return nil }
        let full = t.contains("://") ? t : "https://\(t)"
        guard let u = URL(string: full), let scheme = u.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = u.host, host.contains(".") else { return nil }
        return full
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Request a New Masjid").font(.system(size: 28, weight: .bold))
                Text("Add a masjid by providing the URL to its prayer times page. We'll review it and add it to the app.").foregroundStyle(Palette.muted)
                HStack(spacing: 10) {
                    Image(systemName: "link").foregroundStyle(Palette.muted)
                    TextField("https://", text: $url).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled().focused($focused)
                    PasteButton(payloadType: String.self) { strings in if let s = strings.first { url = s; phase = .idle } }.labelStyle(.iconOnly).tint(Palette.navy)
                }
                .padding(14).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.surface))
                .disabled(phase == .sending)

                Button { Task { await submit() } } label: {
                    if phase == .sending { ProgressView().tint(.white) } else { Text("Submit Request") }
                }
                .buttonStyle(NavyButtonStyle(enabled: canSubmit))
                .disabled(!canSubmit)

                switch phase {
                case .done: Label("Request received. We'll review it, and the masjid is added if it works out.", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                case .failed(let m): Label(m, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                default: EmptyView()
                }
            }
            .padding(.horizontal, 20).padding(.top, 8)
        }
        .background(Palette.bg.ignoresSafeArea())
        .toolbar(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: url) { _, new in if !new.isEmpty, phase != .sending { phase = .idle } }
    }

    private var canSubmit: Bool { cleaned != nil && phase != .sending && phase != .done }

    private func submit() async {
        guard let u = cleaned else { return }
        focused = false
        phase = .sending
        do {
            try await API.requestMosque(url: u)
            Haptics.success()
            phase = .done
            url = ""
        } catch API.Failure.http(let code) {
            Haptics.warning()
            phase = .failed(code == 429 ? "Too many requests. Please try again in an hour." : (code == 400 || code == 422) ? "That address does not look right. Check it and try again." : "Something went wrong. Please try again.")
        } catch {
            Haptics.warning()
            phase = .failed("No connection. Check your internet and try again.")
        }
    }
}
