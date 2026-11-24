import XCTest
@testable import Shared

final class TimeLogicTests: XCTestCase {
    private func fixture() throws -> PrayerResponse {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "markaz", withExtension: "json", subdirectory: "Fixtures"))
        return try JSONDecoder().decode(PrayerResponse.self, from: Data(contentsOf: url))
    }

    func testDecodesRealApiAnswer() throws {
        let r = try fixture()
        XCTAssertEqual(r.mosque.slug, "markaz-ibraheem")
        XCTAssertFalse(TimeLogic.rows(r).isEmpty)
    }

    func testInstantUsesMosqueZoneNotPhoneZone() throws {
        let zone = try XCTUnwrap(TimeZone(identifier: "Europe/London"))
        // 2026-07-01 is British Summer Time: 13:00 local = 12:00 UTC.
        let d = try XCTUnwrap(TimeLogic.instant("13:00", on: "2026-07-01", zone: zone))
        XCTAssertEqual(d.timeIntervalSince1970, 1_782_907_200, accuracy: 1) // 2026-07-01T12:00:00Z
    }

    func testRejectsMalformedTimes() {
        let z = TimeZone(identifier: "Europe/London")!
        XCTAssertNil(TimeLogic.instant("25:00", on: "2026-07-01", zone: z))
        XCTAssertNil(TimeLogic.instant("12", on: "2026-07-01", zone: z))
        XCTAssertNil(TimeLogic.instant("12:00", on: "bad", zone: z))
    }

    func testNextPrayerPrefersJamaahAndSkipsSunrise() throws {
        var r = try fixture()
        r = PrayerResponse(mosque: r.mosque, date: "2026-07-01",
                           beginning: Times(fajr: "03:00", sunrise: "04:50", dhuhr: "13:00"),
                           jamaah: Times(fajr: "03:30", dhuhr: "13:30"), jamaah2: nil, jumuah: [], freshness: r.freshness)
        let zone = TimeZone(identifier: r.mosque.timezone)!
        let now = TimeLogic.instant("04:00", on: "2026-07-01", zone: zone)!   // after Fajr, before Sunrise
        let n = try XCTUnwrap(TimeLogic.next(r, after: now))
        XCTAssertEqual(n.row.prayer, .dhuhr)           // sunrise is not a prayer
        XCTAssertEqual(n.row.main, "13:30")            // jama'ah beats start
        let late = TimeLogic.instant("23:00", on: "2026-07-01", zone: zone)!
        XCTAssertNil(TimeLogic.next(r, after: late))   // none left today
    }

    func testStaleNoteOnlyWhenNotFresh() {
        XCTAssertNil(TimeLogic.staleNote(Freshness(status: "fresh", ageHours: 2)))
        XCTAssertEqual(TimeLogic.staleNote(Freshness(status: "stale", ageHours: 40)), "Times last checked 40 h ago")
        XCTAssertEqual(TimeLogic.staleNote(Freshness(status: "unknown", ageHours: nil)), "Times not confirmed")
    }
}

final class DateStringTests: XCTestCase {
    func testDateInMosqueZone() {
        // 2026-07-01 23:30 UTC is already 2 July in Pakistan.
        let t = Date(timeIntervalSince1970: 1_782_948_600)
        XCTAssertEqual(TimeLogic.dateString(t, zoneId: "Asia/Karachi"), "2026-07-02")
        XCTAssertEqual(TimeLogic.dateString(t, zoneId: "Europe/London"), "2026-07-02")
    }
}
