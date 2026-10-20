#if DEBUG
import Foundation
import SwiftData

/// Debug builds only: a month of made-up nights around District VII, with their places, menus
/// and prices, to look at the app without going out. It remembers what it added, so removing
/// it never touches real nights.
///
/// Settings → Debug, or launch with `-seedSampleData YES`.
extension NightEngine {
    static let seedSampleDataArgument = "seedSampleData"

    private var sampleDataIDs: [UUID] {
        get { (UserDefaults.standard.stringArray(forKey: AppSettings.sampleDataIDsKey) ?? []).compactMap(UUID.init(uuidString:)) }
        set { UserDefaults.standard.set(newValue.map(\.uuidString), forKey: AppSettings.sampleDataIDsKey) }
    }

    var hasSampleData: Bool { !sampleDataIDs.isEmpty }

    func addSampleData(now: Date = .now) {
        guard !hasSampleData else { return }
        var random = SampleRandom(seed: 7)
        let places = SamplePlace.all.map { insertPlace($0, now: now) }
        let nights = SampleNight.all.map { insertNight($0, places: places, now: now, random: &random) }
        save()
        sampleDataIDs = places.map(\.id) + nights.map(\.id)
    }

    func removeSampleData() {
        let ids = sampleDataIDs
        guard !ids.isEmpty else { return }
        // One by one rather than a batch delete, which can't apply the relationship delete rules.
        let nights = (try? context.fetch(FetchDescriptor<Night>(predicate: #Predicate { ids.contains($0.id) }))) ?? []
        let places = (try? context.fetch(FetchDescriptor<Place>(predicate: #Predicate { ids.contains($0.id) }))) ?? []
        nights.forEach(context.delete)
        places.forEach(context.delete)
        save()
        sampleDataIDs = []
    }

    private func insertPlace(_ sample: SamplePlace, now: Date) -> Place {
        let place = Place(mapItemIdentifier: nil, name: sample.name, address: sample.address, latitude: sample.latitude, longitude: sample.longitude, createdAt: now.addingTimeInterval(-40 * 86_400))
        place.isSaved = sample.isSaved
        context.insert(place)
        for menu in sample.menu {
            let item = MenuItem(category: menu.category, name: menu.name, sizeMl: menu.sizeMl)
            context.insert(item)
            item.place = place
            for (daysAgo, amount) in menu.prices {
                let price = PriceObservation(amount: Decimal(amount), currency: "HUF", seenAt: now.addingTimeInterval(-Double(daysAgo) * 86_400))
                context.insert(price)
                price.item = item
            }
        }
        return place
    }

    /// Walks in from a block away, stays at each place for a while with a few beers, walks on.
    private func insertNight(_ sample: SampleNight, places: [Place], now: Date, random: inout SampleRandom) -> Night {
        let day = now.addingTimeInterval(-Double(sample.daysAgo) * 86_400)
        let start = Calendar.current.date(bySettingHour: sample.startHour, minute: sample.startMinute, second: 0, of: day) ?? day
        let night = Night(startedAt: start)
        context.insert(night)

        var time = start
        var segment = 0
        let first = places[sample.route[0]]
        var position = offset(latitude: first.latitude, longitude: first.longitude, north: -120, east: -90)
        var lastBeer = start

        func addPoint(latitude: Double, longitude: Double) {
            let point = TrailPoint(timestamp: time, latitude: latitude, longitude: longitude, horizontalAccuracy: 12, segment: segment)
            context.insert(point)
            point.night = night
        }

        for (index, placeIndex) in sample.route.enumerated() {
            let place = places[placeIndex]
            if sample.gapBefore == index {
                // Phone in a pocket with no fix: the walk there is missing, drawn dashed.
                segment += 1
                time += 6 * 60
            } else {
                // Walking at ~1.3 m/s, a point a minute.
                let distance = distanceMeters(position, (place.latitude, place.longitude))
                let steps = max(1, Int(distance / 78))
                for step in 1...steps {
                    let t = Double(step) / Double(steps)
                    time += 60
                    addPoint(
                        latitude: position.latitude + (place.latitude - position.latitude) * t + random.jitter(4) / 111_000,
                        longitude: position.longitude + (place.longitude - position.longitude) * t + random.jitter(4) / 75_000
                    )
                }
            }

            let venue = Venue(name: place.name, nameSource: .auto, latitude: place.latitude, longitude: place.longitude, arrivedAt: time)
            context.insert(venue)
            venue.night = night
            venue.place = place

            let stay = Double(random.int(in: 35...80)) * 60
            let beers = random.int(in: 1...3)
            let arrived = time
            for beer in 0..<beers {
                let at = arrived + stay * (Double(beer) + 0.3) / Double(beers)
                let entry = Entry(drink: .beer, at: at)
                entry.latitude = place.latitude + random.jitter(10) / 111_000
                entry.longitude = place.longitude + random.jitter(10) / 75_000
                entry.horizontalAccuracy = 8
                context.insert(entry)
                entry.night = night
                entry.venue = venue
                lastBeer = max(lastBeer, at)
            }
            // A point every 5 minutes while sitting there, drifting a little.
            for _ in 0..<Int(stay / 300) {
                time += 300
                addPoint(latitude: place.latitude + random.jitter(12) / 111_000, longitude: place.longitude + random.jitter(12) / 75_000)
            }
            time = arrived + stay
            venue.leftAt = time
            position = (place.latitude, place.longitude)
        }

        night.lastActivityAt = lastBeer
        if sample.autoClosed {
            night.endedAt = lastBeer
            night.endReason = .autoClosed
            night.trailPoints.filter { $0.timestamp > lastBeer }.forEach(context.delete)
            night.venues.forEach { $0.leftAt = min($0.leftAt ?? lastBeer, lastBeer) }
        } else {
            let home = offset(latitude: position.latitude, longitude: position.longitude, north: 160, east: 140)
            for step in 1...3 {
                time += 60
                let t = Double(step) / 3
                addPoint(latitude: position.latitude + (home.latitude - position.latitude) * t, longitude: position.longitude + (home.longitude - position.longitude) * t)
            }
            night.endedAt = time
            night.endReason = .manual
        }
        return night
    }

    private func offset(latitude: Double, longitude: Double, north: Double, east: Double) -> (latitude: Double, longitude: Double) {
        (latitude + north / 111_000, longitude + east / (111_000 * cos(latitude * .pi / 180)))
    }

    private func distanceMeters(_ a: (latitude: Double, longitude: Double), _ b: (latitude: Double, longitude: Double)) -> Double {
        let from = LocationFix(timestamp: .distantPast, latitude: a.latitude, longitude: a.longitude, horizontalAccuracy: 0)
        return from.distance(to: LocationFix(timestamp: .distantPast, latitude: b.latitude, longitude: b.longitude, horizontalAccuracy: 0))
    }
}

private struct SamplePlace {
    struct Menu {
        var category: DrinkCategory
        var name: String
        var sizeMl: Int?
        /// (days ago, HUF), oldest first.
        var prices: [(Int, Int)]
    }

    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var isSaved = false
    var menu: [Menu]

    static let all: [SamplePlace] = [
        SamplePlace(name: "Szimpla Kert", address: "Kazinczy utca 14.", latitude: 47.49695, longitude: 19.06330, menu: [
            Menu(category: .beer, name: "Dreher", sizeMl: 500, prices: [(38, 1490), (4, 1690)]),
            Menu(category: .beer, name: "Szimpla IPA", sizeMl: 400, prices: [(4, 1990)]),
            Menu(category: .wine, name: "Fröccs", sizeMl: 300, prices: [(4, 1290)]),
            Menu(category: .shot, name: "Unicum", sizeMl: 40, prices: [(18, 1590)]),
            Menu(category: .soft, name: "Coca-Cola", sizeMl: 330, prices: [(4, 990)]),
        ]),
        SamplePlace(name: "Kisüzem", address: "Kis Diófa utca 2.", latitude: 47.49880, longitude: 19.06115, menu: [
            Menu(category: .beer, name: "Soproni", sizeMl: 500, prices: [(32, 1190), (18, 1290)]),
            Menu(category: .cocktail, name: "Aperol Spritz", sizeMl: nil, prices: [(18, 2990)]),
        ]),
        SamplePlace(name: "Instant-Fogas", address: "Akácfa utca 49-51.", latitude: 47.50020, longitude: 19.06600, menu: [
            Menu(category: .beer, name: "Dreher", sizeMl: 500, prices: [(4, 1890)]),
            Menu(category: .shot, name: "Jägermeister", sizeMl: 40, prices: [(4, 1790)]),
            Menu(category: .cocktail, name: "Gin Tonic", sizeMl: nil, prices: [(18, 3290)]),
        ]),
        SamplePlace(name: "Ellátó Kert", address: "Kazinczy utca 48.", latitude: 47.49960, longitude: 19.06205, menu: [
            Menu(category: .beer, name: "Pilsner Urquell", sizeMl: 500, prices: [(32, 1590), (18, 1650)]),
        ]),
        SamplePlace(name: "Mazel Tov", address: "Akácfa utca 47.", latitude: 47.49930, longitude: 19.06550, menu: [
            Menu(category: .beer, name: "Dreher", sizeMl: 330, prices: [(4, 1390)]),
            Menu(category: .wine, name: "Kékfrankos", sizeMl: 150, prices: [(4, 1890)]),
        ]),
        SamplePlace(name: "Füge Udvar", address: "Klauzál utca 19.", latitude: 47.49870, longitude: 19.06430, menu: [
            Menu(category: .beer, name: "Soproni", sizeMl: 500, prices: [(10, 1390)]),
            Menu(category: .shot, name: "Pálinka", sizeMl: 40, prices: [(10, 1490)]),
        ]),
        SamplePlace(name: "Telep", address: "Madách Imre utca 8.", latitude: 47.49770, longitude: 19.05900, isSaved: true, menu: []),
        SamplePlace(name: "Mika Tivadar Mulató", address: "Kazinczy utca 47.", latitude: 47.49940, longitude: 19.06280, isSaved: true, menu: [
            Menu(category: .beer, name: "Dreher", sizeMl: 500, prices: [(25, 1590)]),
        ]),
    ]
}

private struct SampleNight {
    var daysAgo: Int
    var startHour: Int
    var startMinute: Int
    /// Indexes into `SamplePlace.all`, in visiting order.
    var route: [Int]
    var autoClosed = false
    /// A tracking gap on the walk to this stop of the route.
    var gapBefore: Int?

    static let all: [SampleNight] = [
        SampleNight(daysAgo: 3, startHour: 20, startMinute: 30, route: [0, 4, 2]),
        SampleNight(daysAgo: 10, startHour: 21, startMinute: 0, route: [5, 0]),
        SampleNight(daysAgo: 17, startHour: 19, startMinute: 45, route: [3, 1, 2, 0], gapBefore: 2),
        SampleNight(daysAgo: 24, startHour: 21, startMinute: 30, route: [4], autoClosed: true),
        SampleNight(daysAgo: 31, startHour: 20, startMinute: 0, route: [1, 5, 3]),
    ]
}

/// SplitMix64, so every seeding produces the same nights.
private struct SampleRandom {
    var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }

    mutating func int(in range: ClosedRange<Int>) -> Int {
        range.lowerBound + Int(unit() * Double(range.count))
    }

    /// Meters, between -`meters` and `meters`.
    mutating func jitter(_ meters: Double) -> Double { (unit() * 2 - 1) * meters }
}
#endif
