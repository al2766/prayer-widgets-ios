import SwiftUI
import Shared

/// "Add New Masjid" sheet: find a masjid we already have, search by location, or ask us to add one. Also holds My Requests.
struct AddMasjidSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    enum Tab { case find, requests }
    enum Route: Hashable {
        case location
        case results(city: String, area: String?)
        case request(name: String)
        case detail(Mosque)
    }

    @State private var tab: Tab = .find
    @State private var query = ""
    @State private var path = NavigationPath()

    private var matches: [Mosque] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.count < 2 ? [] : Directory.filter(app.mosques, query: q)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 10) {
                        DomeShape().stroke(Palette.teal, style: StrokeStyle(lineWidth: 3, lineJoin: .round)).frame(width: 46, height: 30)
                        Text("Add New Masjid").font(.system(size: 28, weight: .bold))
                        Text("Find your masjid or add it manually to request prayer times.").font(.system(size: 17)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                    }
                    .padding(.top, 6)

                    segmented

                    if tab == .find { find } else { MyRequestsList() }
                }
                .padding(.horizontal, 20).padding(.bottom, 30)
            }
            .background(Palette.bg.ignoresSafeArea())
            .overlay(alignment: .topTrailing) {
                Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.text).frame(width: 38, height: 38).background(Circle().fill(Palette.surface)) }
                    .padding(.top, 8).padding(.trailing, 16).accessibilityLabel("Close")
            }
            .navigationDestination(for: Route.self) { r in
                switch r {
                case .location: LocationSearchView(path: $path)
                case .results(let city, let area): ResultsView(city: city, area: area, path: $path)
                case .request(let name): RequestForm(prefillName: name, onSent: { path = NavigationPath(); tab = .requests })
                case .detail(let m): MasjidDetailView(mosque: m)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var segmented: some View {
        HStack(spacing: 4) {
            segment("Find Masjid", "magnifyingglass", .find)
            segment("My Requests", "list.bullet", .requests)
        }
        .padding(4).background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.surface))
    }

    private func segment(_ title: String, _ icon: String, _ t: Tab) -> some View {
        Button { Haptics.tap(); withAnimation(.easeInOut(duration: 0.2)) { tab = t } } label: {
            Label(title, systemImage: icon).font(.system(size: 17, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 46)
                .foregroundStyle(Palette.text)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(tab == t ? Color.white : Color.clear)
                    .shadow(color: Color.black.opacity(tab == t ? 0.08 : 0), radius: 4, y: 1))
        }
    }

    // MARK: Find

    private var find: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
                TextField("Search masjid name, city or postcode", text: $query).autocorrectionDisabled().submitLabel(.search)
                if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.muted) } }
            }
            .font(.system(size: 17)).padding(.horizontal, 16).frame(height: 54)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Palette.line)))

            if query.trimmingCharacters(in: .whitespaces).count >= 2 {
                if matches.isEmpty {
                    VStack(spacing: 12) {
                        Text("No masjid found for “\(query.trimmingCharacters(in: .whitespaces))”").font(.system(size: 16)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
                        Button { path.append(Route.request(name: query.trimmingCharacters(in: .whitespaces))) } label: { Label("Request this masjid", systemImage: "plus") }.buttonStyle(TealButtonStyle())
                    }
                    .padding(.top, 6)
                } else {
                    VStack(spacing: 0) {
                        ForEach(matches) { m in
                            Button { path.append(Route.detail(m)) } label: { MasjidResultRow(mosque: m, available: true) }.buttonStyle(.plain)
                            Divider().overlay(Palette.line)
                        }
                    }
                }
            } else {
                HStack { line; Text("or").foregroundStyle(Palette.muted); line }
                VStack(spacing: 0) {
                    navRow("Search by location", icon: "location") { path.append(Route.location) }
                    Divider().overlay(Palette.line)
                    navRow("Add manually", icon: "plus") { path.append(Route.request(name: "")) }
                }
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Palette.line)))
            }
        }
    }

    private var line: some View { Rectangle().fill(Palette.line).frame(height: 1) }

    private func navRow(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.system(size: 20)).foregroundStyle(Palette.teal).frame(width: 28)
                Text(title).font(.system(size: 18, weight: .medium)).foregroundStyle(Palette.text)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.muted)
            }
            .padding(.horizontal, 16).frame(height: 62).contentShape(Rectangle())
        }
    }
}

/// A masjid in a results list: logo, name, place and whether we already have its prayer times.
struct MasjidResultRow: View {
    let mosque: Mosque
    let available: Bool
    var body: some View {
        HStack(spacing: 14) {
            MasjidLogo(mosque: mosque, size: 58)
            VStack(alignment: .leading, spacing: 4) {
                Text(mosque.name).font(.system(size: 18, weight: .bold)).foregroundStyle(Palette.text).multilineTextAlignment(.leading)
                Text([mosque.area, mosque.city].compactMap { $0 }.joined(separator: ", ")).font(.system(size: 15)).foregroundStyle(Palette.muted)
                if available {
                    Label("Prayer times available", systemImage: "checkmark").font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.teal)
                } else {
                    Label("Request prayer times", systemImage: "plus").font(.system(size: 15)).foregroundStyle(Palette.muted)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: available ? "chevron.right" : "plus").font(.system(size: 17)).foregroundStyle(Palette.muted)
        }
        .padding(.vertical, 14).contentShape(Rectangle())
    }
}

// MARK: - Search by location

private struct LocationSearchView: View {
    @EnvironmentObject var app: AppState
    @Binding var path: NavigationPath
    enum Kind: String, Identifiable { case country, city, area; var id: String { rawValue } }
    @State private var city: String?
    @State private var area: String?
    @State private var picking: Kind?

    var body: some View {
        VStack(spacing: 18) {
            Text("Narrow down to find masjids in your area.").font(.system(size: 17)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
            VStack(spacing: 0) {
                selector("Country", icon: "globe", value: Directory.country) { picking = .country }
                Divider().overlay(Palette.line)
                selector("City", icon: "building.2", value: city ?? "Select city") { picking = .city }
                Divider().overlay(Palette.line)
                selector("Area", icon: "location", value: area ?? (city == nil ? "Select area" : "All Areas")) { if city != nil { picking = .area } }
            }
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Palette.line)))
            Spacer()
            Button("Show Masjids") { if let city { path.append(AddMasjidSheet.Route.results(city: city, area: area)) } }
                .buttonStyle(TealButtonStyle(enabled: city != nil)).disabled(city == nil)
        }
        .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 20)
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle("Search by Location").navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $picking) { kind in
            switch kind {
            case .country: OptionList(title: "Select Country", options: [Directory.country], selection: Directory.country, allLabel: nil) { _ in picking = nil }
            case .city: OptionList(title: "Select City", options: Directory.cities(app.mosques), selection: city, allLabel: nil) { v in city = v; area = nil; picking = nil }
            case .area: OptionList(title: "Select Area", options: Directory.areas(app.mosques, city: city), selection: area, allLabel: "All Areas") { v in area = v; picking = nil }
            }
        }
    }

    private func selector(_ title: String, icon: String, value: String, action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.system(size: 20)).foregroundStyle(Palette.teal).frame(width: 28)
                Text(title).font(.system(size: 18, weight: .semibold)).foregroundStyle(Palette.text)
                Spacer()
                Text(value).font(.system(size: 17)).foregroundStyle(Palette.muted).lineLimit(1)
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.muted)
            }
            .padding(.horizontal, 16).frame(height: 62).contentShape(Rectangle())
        }
    }
}

/// A searchable single-choice list with a tick on the current choice.
private struct OptionList: View {
    let title: String
    let options: [String]
    let selection: String?
    let allLabel: String?          // when set, a first row that clears the choice
    let choose: (String?) -> Void
    @State private var search = ""

    private var shown: [String] { search.isEmpty ? options : options.filter { $0.localizedCaseInsensitiveContains(search) } }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
                    TextField("Search…", text: $search).autocorrectionDisabled()
                }
                .padding(.horizontal, 14).frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white).overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Palette.line)))
                if let allLabel { row(allLabel, on: selection == nil) { choose(nil) } }
                ForEach(shown, id: \.self) { o in row(o, on: selection == o) { choose(o) } }
                if shown.isEmpty && allLabel == nil { Text("Nothing to choose yet.").foregroundStyle(Palette.muted).padding(.top, 30) }
            }
            .padding(.horizontal, 20).padding(.top, 8)
        }
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ text: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); action() } label: {
            HStack {
                Text(text).font(.system(size: 18, weight: on ? .semibold : .regular)).foregroundStyle(Palette.text)
                Spacer()
                Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.system(size: 24)).foregroundStyle(on ? Palette.teal : Palette.line)
            }
            .padding(.horizontal, 16).frame(height: 56)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(on ? Palette.tealSoft : Color.clear))
            .contentShape(Rectangle())
        }
    }
}

// MARK: - Results

private struct ResultsView: View {
    @EnvironmentObject var app: AppState
    let city: String
    let area: String?
    @Binding var path: NavigationPath
    @State private var query = ""

    private var found: [Mosque] { Directory.filter(app.mosques, city: city, area: area, query: query) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        tag(Directory.country)
                        tag(city)
                        tag(area ?? "All Areas")
                    }
                }
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
                    TextField("Search within results...", text: $query).autocorrectionDisabled()
                }
                .padding(.horizontal, 14).frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white).overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Palette.line)))
                Text("\(found.count) masjid\(found.count == 1 ? "" : "s") found").font(.system(size: 16)).foregroundStyle(Palette.muted)
                VStack(spacing: 0) {
                    ForEach(found) { m in
                        Button { path.append(AddMasjidSheet.Route.detail(m)) } label: { MasjidResultRow(mosque: m, available: true) }.buttonStyle(.plain)
                        Divider().overlay(Palette.line)
                    }
                }
                VStack(spacing: 10) {
                    Text("Can't find yours?").font(.system(size: 16)).foregroundStyle(Palette.muted)
                    Button { path.append(AddMasjidSheet.Route.request(name: "")) } label: { Label("Request a masjid", systemImage: "plus") }.buttonStyle(SoftButtonStyle())
                }
                .frame(maxWidth: .infinity).padding(.top, 10)
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
        }
        .background(Palette.bg.ignoresSafeArea())
        .navigationTitle("Masjids").navigationBarTitleDisplayMode(.inline)
    }

    private func tag(_ t: String) -> some View {
        Text(t).font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.teal)
            .padding(.horizontal, 14).padding(.vertical, 8).background(Capsule().fill(Palette.tealSoft))
    }
}

// MARK: - Request form

struct RequestForm: View {
    @EnvironmentObject var app: AppState
    let prefillName: String
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
                ZStack {
                    Circle().fill(Palette.tealSoft)
                    DomeShape().stroke(Palette.teal, style: StrokeStyle(lineWidth: 2.6, lineJoin: .round)).frame(width: 34, height: 22)
                }
                .frame(width: 76, height: 76)

                Text("Request this masjid").font(.system(size: 26, weight: .bold))

                HStack(spacing: 12) {
                    Image(systemName: "info.circle").foregroundStyle(Palette.teal)
                    Text("Prayer times aren't available for this masjid yet. You can request that we add it.").font(.system(size: 16)).foregroundStyle(Palette.text)
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.tealSoft))

                field("Masjid name", icon: "building.columns") {
                    TextField("e.g. Al-Hikmah Centre", text: $name).textInputAutocapitalization(.words).focused($focused)
                }
                field("Website with its prayer times", icon: "link") {
                    HStack {
                        TextField("https://", text: $url).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        PasteButton(payloadType: String.self) { strings in if let s = strings.first { url = s } }.labelStyle(.iconOnly).tint(Palette.teal)
                    }
                }

                if case .failed(let m) = phase { Label(m, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.system(size: 15)) }

                Button { Task { await send() } } label: {
                    if phase == .sending { ProgressView().tint(.white) } else { Text("Request Prayer Times") }
                }
                .buttonStyle(TealButtonStyle(enabled: canSend)).disabled(!canSend)
                Text("We read the masjid's own timetable page. Nothing is added until we have checked it.").font(.system(size: 13)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 24)
        }
        .background(Palette.bg.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if name.isEmpty { name = prefillName } }
    }

    private func field<C: View>(_ title: String, icon: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.text)
            content().font(.system(size: 17)).padding(.horizontal, 14).frame(minHeight: 52)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white).overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Palette.line)))
        }
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
