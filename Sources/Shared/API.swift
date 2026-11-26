import Foundation

public enum API {
    /// The live Prayer Widgets Studio. Public endpoints only; nothing here needs a login.
    public static let base = URL(string: "https://prayer-widgets-studio.vercel.app")!

    public enum Failure: Error { case http(Int), offline }

    private static func get<T: Decodable>(_ path: String, as: T.Type) async throws -> (T, Data) {
        var req = URLRequest(url: base.appendingPathComponent(path))
        req.timeoutInterval = 15
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let data: Data, resp: URLResponse
        do { (data, resp) = try await URLSession.shared.data(for: req) } catch { throw Failure.offline }
        guard let h = resp as? HTTPURLResponse else { throw Failure.offline }
        guard (200..<300).contains(h.statusCode) else { throw Failure.http(h.statusCode) }
        return (try JSONDecoder().decode(T.self, from: data), data)
    }

    /// Sends a "please add this mosque" request. The Studio only adds it to a list for the admin; nothing is fetched or added automatically.
    /// Returns the request id, which the phone keeps so it can ask later what happened.
    public static func requestMosque(url: String, name: String? = nil) async throws -> String? {
        var req = URLRequest(url: base.appendingPathComponent("api/requests"))
        req.httpMethod = "POST"
        req.timeoutInterval = 15
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body = ["url": url]
        if let n = name?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty { body["mosqueName"] = String(n.prefix(100)) }
        req.httpBody = try JSONEncoder().encode(body)
        let data: Data, resp: URLResponse
        do { (data, resp) = try await URLSession.shared.data(for: req) } catch { throw Failure.offline }
        guard let h = resp as? HTTPURLResponse else { throw Failure.offline }
        guard (200..<300).contains(h.statusCode) else { throw Failure.http(h.statusCode) }
        return (try? JSONDecoder().decode(RequestReceipt.self, from: data))?.id
    }

    struct RequestReceipt: Codable { let ok: Bool; let id: String? }
    public struct RequestState: Codable, Equatable { public let id: String; public let status: String; public let slug: String? }
    struct RequestStates: Codable { let requests: [RequestState] }

    /// What happened to requests this phone made: received (still waiting), added, or closed.
    public static func requestStates(ids: [String]) async throws -> [RequestState] {
        guard !ids.isEmpty else { return [] }
        var c = URLComponents(url: base.appendingPathComponent("api/requests/status"), resolvingAgainstBaseURL: false)!
        c.queryItems = [URLQueryItem(name: "ids", value: ids.prefix(20).joined(separator: ","))]
        var req = URLRequest(url: c.url!)
        req.timeoutInterval = 15
        let data: Data, resp: URLResponse
        do { (data, resp) = try await URLSession.shared.data(for: req) } catch { throw Failure.offline }
        guard let h = resp as? HTTPURLResponse else { throw Failure.offline }
        guard (200..<300).contains(h.statusCode) else { throw Failure.http(h.statusCode) }
        return try JSONDecoder().decode(RequestStates.self, from: data).requests
    }

    /// The saved logo of a masjid, when the admin saved one.
    public static func logoURL(_ m: Mosque) -> URL? {
        guard let p = m.logoPath, p.hasPrefix("/") else { return nil }
        return URL(string: p, relativeTo: base)?.absoluteURL
    }

    public static func mosques() async throws -> [Mosque] {
        try await get("api/mosques", as: MosqueList.self).0.mosques
    }

    /// Returns the decoded day and the raw bytes (so the caller can cache exactly what the server said).
    public static func prayerTimes(slug: String) async throws -> (PrayerResponse, Data) {
        try await get("api/mosques/\(slug)/prayer-times", as: PrayerResponse.self)
    }
}

/// Keeps the last good answer so a failed fetch shows old real data with its age, never made-up times.
public struct Cache {
    let defaults: UserDefaults
    public init(defaults: UserDefaults = Store.defaults) { self.defaults = defaults }

    public func saveTimes(_ data: Data, slug: String) { defaults.set(data, forKey: "times.\(slug)") }
    public func times(slug: String) -> PrayerResponse? {
        defaults.data(forKey: "times.\(slug)").flatMap { try? JSONDecoder().decode(PrayerResponse.self, from: $0) }
    }
    public func saveMosques(_ list: [Mosque]) { defaults.set(try? JSONEncoder().encode(list), forKey: "mosques") }
    public func mosques() -> [Mosque] {
        defaults.data(forKey: "mosques").flatMap { try? JSONDecoder().decode([Mosque].self, from: $0) } ?? []
    }
}
