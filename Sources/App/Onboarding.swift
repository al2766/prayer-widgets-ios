import SwiftUI
import Shared

/// First-run questions, in plain words: which prayer times do you follow (a masjid, or calculated for your location),
/// then the masjid or the location, then reminders. Shown above the app until finished.
struct OnboardingView: View {
    @EnvironmentObject var app: AppState

    enum Step: Equatable { case choose, masjid, notFound, location, reminders, done }

    @State private var step: Step = .choose
    @State private var trail: [Step] = []
    @State private var query = ""
    @State private var showRequest = false
    @State private var reminders = true
    @State private var working = false

    private var dot: Int {
        switch step {
        case .choose: return 0
        case .masjid, .notFound, .location: return 1
        case .reminders: return 2
        case .done: return 3
        }
    }

    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                Group {
                    switch step {
                    case .choose: choose
                    case .masjid: masjid
                    case .notFound: notFound
                    case .location: location
                    case .reminders: remindersStep
                    case .done: done
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(step)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
        }
        .sheet(isPresented: $showRequest) { AddMasjidSheet(startManual: true).environmentObject(app) }
    }

    // MARK: Moving between steps

    private func go(_ next: Step) {
        Haptics.tap()
        trail.append(step)
        withAnimation(.easeInOut(duration: 0.25)) { step = next }
    }

    private func back() {
        Haptics.tap()
        guard let last = trail.popLast() else { return }
        withAnimation(.easeInOut(duration: 0.25)) { step = last }
    }

    private var topBar: some View {
        ZStack {
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { i in
                    Circle().fill(i == dot ? Palette.teal : Palette.teal.opacity(0.18)).frame(width: 9, height: 9)
                }
            }
            HStack {
                if !trail.isEmpty && step != .done {
                    Button { back() } label: { RoundIcon(system: "chevron.left", size: 44) }.accessibilityLabel("Back")
                }
                Spacer()
            }
        }
        .frame(height: 52).padding(.horizontal, 20).padding(.top, 8)
    }

    // MARK: Screens

    private func heading(_ title: String, _ sub: String) -> some View {
        VStack(spacing: 10) {
            Text(title).font(.system(size: 31, weight: .bold)).multilineTextAlignment(.center).foregroundStyle(Palette.text)
            Text(sub).font(.system(size: 18)).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
    }

    private func tile<Icon: View>(@ViewBuilder _ icon: () -> Icon) -> some View {
        icon().frame(width: 92, height: 92).background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Palette.tealSoft))
    }

    private var choose: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 10)
            DomeGlyph(size: 64).foregroundStyle(Palette.teal)
            heading("Which prayer times do you follow?", "Choose how you'd like to get your prayer times in the app.")
            VStack(spacing: 14) {
                optionCard(icon: AnyView(DomeGlyph(size: 34).foregroundStyle(Palette.teal)), title: "My masjid",
                           text: "Use your masjid's own timetable, including Jama'ah times.") { go(.masjid) }
                optionCard(icon: AnyView(Image(systemName: "location").font(.system(size: 28)).foregroundStyle(Palette.teal)), title: "Local prayer times",
                           text: "Automatically calculated for your location.") { go(.location) }
            }
            .padding(.horizontal, 20)
            Spacer(minLength: 30)
        }
    }

    private func optionCard(icon: AnyView, title: String, text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                icon.frame(width: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 20, weight: .bold)).foregroundStyle(Palette.text)
                    Text(text).font(.system(size: 16)).foregroundStyle(Palette.muted).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(Palette.muted)
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white).overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Palette.line)))
        }
        .buttonStyle(.plain)
    }

    private var matches: [Mosque] {
        let all = Directory.filter(app.mosques, query: query)
        return query.trimmingCharacters(in: .whitespaces).isEmpty ? Array(all.prefix(12)) : all
    }

    private var masjid: some View {
        VStack(spacing: 14) {
            DomeGlyph(size: 50).foregroundStyle(Palette.teal).padding(.top, 4)
            heading("Choose your masjid", "Find your masjid from the list below.")
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.muted)
                TextField("Search by name, city or postcode", text: $query).autocorrectionDisabled().submitLabel(.search)
            }
            .font(.system(size: 17)).padding(.horizontal, 16).frame(height: 52)
            .background(Capsule().fill(Color.white).overlay(Capsule().stroke(Palette.line)))
            .padding(.horizontal, 20)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(matches) { m in
                        Button {
                            guard !working else { return }
                            working = true
                            Task { await app.setDefault(m); working = false; go(.reminders) }
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(m.name).font(.system(size: 18, weight: .semibold)).foregroundStyle(Palette.text).multilineTextAlignment(.leading)
                                    Text([Directory.cityOf(m), m.shortLine].filter { !$0.isEmpty }.joined(separator: " · ")).font(.system(size: 15)).foregroundStyle(Palette.muted)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").foregroundStyle(Palette.muted)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 13).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(Palette.line).padding(.horizontal, 12)
                    }
                    if matches.isEmpty {
                        Text(app.mosques.isEmpty ? (app.mosquesMessage ?? "Loading masjids…") : "No masjid found for “\(query.trimmingCharacters(in: .whitespaces))”.")
                            .foregroundStyle(Palette.muted).multilineTextAlignment(.center).padding(24)
                    }
                }
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white).overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Palette.line)))
                .padding(.horizontal, 20)
            }

            Button { go(.notFound) } label: {
                HStack(spacing: 14) {
                    Image(systemName: "plus").font(.system(size: 18, weight: .semibold)).foregroundStyle(Palette.teal)
                        .frame(width: 40, height: 40).background(Circle().fill(Palette.tealSoft))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Can't find your masjid?").font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.teal)
                        Text("Request it and we'll aim to add it within 48 hours.").font(.system(size: 14)).foregroundStyle(Palette.muted).multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14).background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.surface))
            }
            .buttonStyle(.plain).padding(.horizontal, 20).padding(.bottom, 16)
        }
    }

    private var notFound: some View {
        VStack(spacing: 24) {
            Spacer()
            tile { DomeGlyph(size: 46).foregroundStyle(Palette.teal) }
            heading("We couldn't find your masjid", "You can request that we add it, or use local prayer times for now.")
            VStack(spacing: 12) {
                Button("Request my masjid") { Haptics.tap(); showRequest = true }.buttonStyle(TealButtonStyle())
                Button("Use local prayer times instead") { go(.location) }.buttonStyle(SoftButtonStyle())
            }
            .padding(.horizontal, 24)
            Spacer(); Spacer()
        }
    }

    private var location: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 10)
            Image(systemName: "location").font(.system(size: 54, weight: .regular)).foregroundStyle(Palette.teal)
            heading("What's your location?", "We'll use this to calculate your prayer times and show nearby masjids.")
            LocationChoice(current: app.place) { p in app.setPlace(p) }.padding(.horizontal, 24)
            if let p = app.place {
                Label(p.name, systemImage: "checkmark.circle.fill").font(.system(size: 18, weight: .semibold)).foregroundStyle(Palette.teal)
            }
            Spacer(minLength: 0)
            Button("Continue") {
                guard !working else { return }
                working = true
                Task { await app.useLocalTimes(); working = false; go(.reminders) }
            }
            .buttonStyle(TealButtonStyle(enabled: app.place != nil)).disabled(app.place == nil)
            .padding(.horizontal, 24).padding(.bottom, 24)
        }
    }

    private var remindersStep: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 10)
            Image(systemName: "bell").font(.system(size: 52, weight: .regular)).foregroundStyle(Palette.teal)
            heading("Prayer reminders", "Get notified at your prayer times so you never miss a prayer.")
            Toggle("Enable reminders", isOn: $reminders).tint(Palette.teal)
                .font(.system(size: 18)).padding(.horizontal, 18).frame(minHeight: 60)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white).overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Palette.line)))
                .padding(.horizontal, 24)
            Spacer(minLength: 0)
            Button("Continue") {
                guard !working else { return }
                working = true
                Task {
                    if reminders {
                        var s = await Planner.status()
                        if s == .notDetermined { _ = await Planner.requestAuthorization(); s = await Planner.status() }
                        if s == .authorized || s == .provisional { Store.notifyPrayers = true }
                    }
                    await Planner.reschedule(for: app.activeDay())
                    working = false
                    go(.done)
                }
            }
            .buttonStyle(TealButtonStyle()).padding(.horizontal, 24).padding(.bottom, 24)
        }
    }

    private var done: some View {
        VStack(spacing: 24) {
            Spacer()
            tile { Image(systemName: "checkmark").font(.system(size: 40, weight: .semibold)).foregroundStyle(Palette.teal) }
            heading("You're all set", "Your prayer times are ready.")
            Spacer()
            Button("Get started") { Haptics.success(); withAnimation(.easeInOut(duration: 0.3)) { app.finishOnboarding() } }
                .buttonStyle(TealButtonStyle()).padding(.horizontal, 24).padding(.bottom, 24)
        }
    }
}
