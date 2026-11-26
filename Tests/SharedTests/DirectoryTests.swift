import XCTest
@testable import Shared

final class DirectoryTests: XCTestCase {
    private let list = [
        Mosque(slug: "a", name: "Markaz Ibraheem", timezone: "Europe/London", city: "Manchester", address: "39 Upper Lloyd Street, Manchester M14 4HY", area: "Moss Side", lat: 53.456973, lon: -2.235376),
        Mosque(slug: "b", name: "Wise High Wycombe", timezone: "Europe/London", city: "High Wycombe", address: "St Marks Close, High Wycombe HP13 6GN"),
        Mosque(slug: "c", name: "No City Masjid", timezone: "Europe/London"),
    ]

    func testCitiesSortedWithOtherLast() {
        XCTAssertEqual(Directory.cities(list), ["High Wycombe", "Manchester", "Other"])
    }

    func testAreasOnlyListRealOnes() {
        XCTAssertEqual(Directory.areas(list, city: "Manchester"), ["Moss Side"])
        XCTAssertEqual(Directory.areas(list, city: "High Wycombe"), [])
    }

    func testFilterMatchesNameAddressPostcodeAndCity() {
        XCTAssertEqual(Directory.filter(list, query: "ibraheem").map(\.slug), ["a"])
        XCTAssertEqual(Directory.filter(list, query: "HP13").map(\.slug), ["b"])
        XCTAssertEqual(Directory.filter(list, query: "manchester").map(\.slug), ["a"])
        XCTAssertEqual(Directory.filter(list, city: "Other").map(\.slug), ["c"])
        XCTAssertEqual(Directory.filter(list, city: "All").count, 3)
        XCTAssertEqual(Directory.filter(list, city: "Manchester", area: "Moss Side").map(\.slug), ["a"])
        XCTAssertTrue(Directory.filter(list, city: "Manchester", area: "Longsight").isEmpty)
    }

    func testDistanceManchesterToLondon() {
        let d = Directory.miles(fromLat: 53.4808, lon: -2.2426, toLat: 51.5074, lon: -0.1278)
        XCTAssertEqual(d, 163, accuracy: 6)   // straight line, not driving
        XCTAssertEqual(Directory.distanceText(0.44), "0.4 mi")
        XCTAssertEqual(Directory.distanceText(12.4), "12 mi")
    }

    func testMapLinksUseCoordinatesWhenKnown() {
        let withPos = list[0], noPos = list[1]
        XCTAssertTrue(MapLinks.apple(withPos)!.absoluteString.contains("ll=53.456973,-2.235376"))
        XCTAssertTrue(MapLinks.google(withPos)!.absoluteString.contains("query=53.456973,-2.235376"))
        XCTAssertTrue(MapLinks.waze(withPos)!.absoluteString.contains("ll=53.456973,-2.235376"))
        XCTAssertTrue(MapLinks.google(noPos)!.absoluteString.contains("Wise%20High%20Wycombe"))
    }

    func testAddressLineFallsBackToCity() {
        XCTAssertEqual(list[0].addressLine, "39 Upper Lloyd Street, Manchester M14 4HY")
        XCTAssertEqual(list[2].addressLine, "UK")
        XCTAssertEqual(Mosque(slug: "x", name: "X", timezone: "Europe/London", city: "Leeds").addressLine, "Leeds, UK")
    }

    func testQiblaBearingFromSuggestedCities() {
        let m = Place.suggested[0]
        XCTAssertEqual(Qibla.bearing(lat: m.lat, lon: m.lon), 118.7, accuracy: 1.5)
        let london = Place.suggested[1]
        XCTAssertEqual(Qibla.bearing(lat: london.lat, lon: london.lon), 118.9, accuracy: 1.5)
        XCTAssertEqual(Qibla.difference(350, 10), -20, accuracy: 0.001)
    }

    func testDecodesMosqueWithNullsAndOldCache() throws {
        let json = #"{"slug":"s","name":"N","city":null,"timezone":"Europe/London","address":null,"area":null,"lat":null,"lon":null,"logoPath":null}"#
        let m = try JSONDecoder().decode(Mosque.self, from: Data(json.utf8))
        XCTAssertNil(m.logoPath)
        let old = #"{"slug":"s","name":"N","timezone":"Europe/London"}"#   // saved by an older build
        XCTAssertNoThrow(try JSONDecoder().decode(Mosque.self, from: Data(old.utf8)))
    }

    func testRequestURLCleaning() {
        XCTAssertEqual(RequestURL.clean(" example.org/times "), "https://example.org/times")
        XCTAssertEqual(RequestURL.clean("http://example.org"), "http://example.org")
        XCTAssertNil(RequestURL.clean("not a url"))
        XCTAssertNil(RequestURL.clean("localhost"))
        XCTAssertNil(RequestURL.clean("ftp://example.org"))
        XCTAssertNil(RequestURL.clean(""))
    }
}

final class PostcodeTests: XCTestCase {
    func testPostcodeFromAddress() {
        let m = Mosque(slug: "a", name: "A", timezone: "Europe/London", city: "Manchester", address: "39 Upper Lloyd Street, Manchester M14 4HY")
        XCTAssertEqual(m.postcode, "M14 4HY")
        XCTAssertEqual(m.shortLine, "M14 4HY")
    }
    func testNoPostcodeFallsBackToArea() {
        let m = Mosque(slug: "a", name: "A", timezone: "Europe/London", city: "Leeds", address: "Main Road", area: "Headingley")
        XCTAssertNil(m.postcode)
        XCTAssertEqual(m.shortLine, "Headingley")
    }
    func testLowercaseAndNoSpace() {
        let m = Mosque(slug: "a", name: "A", timezone: "Europe/London", address: "1 High St, hp13 6gn")
        XCTAssertEqual(m.postcode, "HP13 6GN")
    }
}

final class LocalTimesTests: XCTestCase {
    private func date(_ s: String) -> Date {
        let f = DateFormatter(); f.timeZone = TimeZone(identifier: "Europe/London"); f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: s)!
    }
    private let london = Place(name: "London, UK", lat: 51.5074, lon: -0.1278)
    private let edinburgh = Place(name: "Edinburgh, UK", lat: 55.9533, lon: -3.1883)

    func testOrderAndFormat() throws {
        let d = try XCTUnwrap(LocalTimes.day(place: london, now: date("2026-11-26 10:00"), hanafiAsr: false))
        let t = d.beginning
        let all = [t.fajr, t.sunrise, t.dhuhr, t.asr, t.maghrib, t.isha].compactMap { $0 }
        XCTAssertEqual(all.count, 6)
        XCTAssertEqual(all, all.sorted())                       // 24-hour HH:mm strings sort in time order
        XCTAssertTrue(all.allSatisfy { $0.count == 5 && $0.contains(":") })
        XCTAssertEqual(d.date, "2026-11-26")
        XCTAssertEqual(d.mosque.name, "London")
        XCTAssertNil(d.jamaah.fajr)
    }

    func testMidwinterLondonSunriseAndSunset() throws {
        let d = try XCTUnwrap(LocalTimes.day(place: london, now: date("2025-12-21 10:00"), hanafiAsr: false))
        let sunrise = try XCTUnwrap(d.beginning.sunrise), maghrib = try XCTUnwrap(d.beginning.maghrib)
        XCTAssertTrue(("08:00"..."08:08").contains(sunrise), sunrise)      // real sunrise about 08:04
        XCTAssertTrue(("15:50"..."16:02").contains(maghrib), maghrib)      // real sunset about 15:53, method adds 3 minutes
    }

    func testHanafiAsrIsLater() throws {
        let a = try XCTUnwrap(LocalTimes.day(place: london, now: date("2026-11-26 10:00"), hanafiAsr: false)?.beginning.asr)
        let b = try XCTUnwrap(LocalTimes.day(place: london, now: date("2026-11-26 10:00"), hanafiAsr: true)?.beginning.asr)
        XCTAssertLessThan(a, b)
    }

    func testScottishMidsummerStillGivesTimes() throws {
        let d = try XCTUnwrap(LocalTimes.day(place: edinburgh, now: date("2026-06-21 10:00"), hanafiAsr: false))
        XCTAssertNotNil(d.beginning.fajr); XCTAssertNotNil(d.beginning.isha)
        XCTAssertGreaterThan(try XCTUnwrap(d.beginning.isha), try XCTUnwrap(d.beginning.maghrib))
        XCTAssertLessThan(try XCTUnwrap(d.beginning.fajr), try XCTUnwrap(d.beginning.sunrise))
    }

    func testSourceDefaults() {
        XCTAssertEqual(LocalTimes.shortName(london), "London")
    }
}
