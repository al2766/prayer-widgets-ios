import XCTest
@testable import Shared

final class DisplayTests: XCTestCase {
    func testCountdownWording() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(TimeLogic.countdown(to: now.addingTimeInterval(8_100), from: now), "in 2h 15m")
        XCTAssertEqual(TimeLogic.countdown(to: now.addingTimeInterval(14 * 60 + 5), from: now), "in 14m")
        XCTAssertEqual(TimeLogic.countdown(to: now.addingTimeInterval(30), from: now), "in under a minute")
    }

    func testUpdatedTextUsesMosqueZone() {
        let f = Freshness(status: "fresh", ageHours: 1, lastSuccessAt: "2026-11-24T14:58:03.123Z", lastVerifiedAt: nil)
        let now = TimeLogic.parseISO("2026-11-24T20:00:00.000Z")!
        XCTAssertEqual(TimeLogic.updatedText(f, zoneId: "Europe/London", now: now), "Today, 14:58")
        let later = TimeLogic.parseISO("2026-11-25T09:00:00.000Z")!
        XCTAssertEqual(TimeLogic.updatedText(f, zoneId: "Europe/London", now: later), "Yesterday, 14:58")
        XCTAssertNil(TimeLogic.updatedText(Freshness(status: "unknown", ageHours: nil, lastSuccessAt: nil, lastVerifiedAt: nil), zoneId: "Europe/London", now: now))
    }

    func testLayoutsOnlyOfferedWhereTheyFit() {
        XCTAssertEqual(WidgetLayout.horizontal.resolved(for: .small), .compact)
        XCTAssertEqual(WidgetLayout.compact.resolved(for: .medium), .classic)
        XCTAssertEqual(WidgetLayout.nextFocus.resolved(for: .small), .nextFocus)
        for l in WidgetLayout.allCases { XCTAssertTrue(l.supports(l.previewSize)) }
    }

    func testThemeLookupFallsBack() {
        XCTAssertEqual(WidgetTheme.byId("nope").id, WidgetTheme.all[0].id)
        XCTAssertEqual(WidgetTheme.all.count, 7)
    }
}

final class QiblaTests: XCTestCase {
    func testKnownBearings() {
        // London is about 119 degrees; New York about 58 degrees (commonly published values).
        XCTAssertEqual(Qibla.bearing(lat: 51.5074, lon: -0.1278), 118.99, accuracy: 0.5)
        XCTAssertEqual(Qibla.bearing(lat: 40.7128, lon: -74.0060), 58.5, accuracy: 0.7)
    }
    func testDifferenceWrapsAround() {
        XCTAssertEqual(Qibla.difference(350, 10), -20, accuracy: 0.001)
        XCTAssertEqual(Qibla.difference(10, 350), 20, accuracy: 0.001)
    }
}
