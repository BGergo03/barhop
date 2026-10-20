# Barhop — POC Spec

A personal, native iOS "Strava for nights out". Start a night, log beers with one tap from the Lock Screen, watch your trail and bar stops build on a live map, and end with a shareable report (PNG card or transparent sticker). Over time the bars you visit become your own catalog of places, with their drinks and what they cost.

This spec is the outcome of a design interview. Every decision below is settled unless marked **OPEN**. Build in the milestone order in §11 and check each milestone's acceptance criteria before moving on.

---

## 1. Scope

**In the POC**
- One drink type: **Beer, 0.5 L**.
- Nights: start, live tracking, end, report, history list.
- Live breadcrumb trail + automatic venue (stop) detection and naming.
- One-tap logging from Lock Screen Live Activity, Dynamic Island, Control Center control, and in-app.
- Undo + edit/delete of entries.
- "Still out?" auto-close.
- Share as 9:16 PNG card or transparent PNG sticker.
- **Places** (added after M9): a lasting catalog of bars, seeded from Apple Maps and filled in by your nights; each with a drinks menu and the prices you've seen. Browsed through Home, Search, Map and Profile tabs (§7).

**Explicitly out of scope (future)**
- Logging drink types/sizes other than a 0.5 L beer, cigarettes, nicotine pouches, photos (the data model already allows them — see §4). Menus already list any drink.
- Food on menus; a price on a logged beer / "spent tonight" (the entry payload can take it later without a migration).
- A shared venue database: places, menus and prices stay on your phone, but are modeled so they can sync later (UUIDs, append-only prices).
- Opening hours and ratings (MapKit doesn't reliably expose them).
- BAC / intoxication estimates — **never** in the POC (App Store Guideline 1.4.3 risk, misleading).
- Aggregate stats (monthly/yearly totals).
- Accounts, backend, social feed, web share links, iCloud sync.
- Apple Watch app.
- Hungarian localization (but all strings go in a String Catalog).

**Product guardrails** (keeps a future App Store release possible): no "drink more" mechanics, no streaks/scores rewarding volume, copy frames it as "your night", not a challenge. Prices are information: showing them and sorting by price is fine; anything that counts beers per amount of money ("best value", "most beers for 5000 Ft") is not.

---

## 2. Platform & tooling

- Swift, SwiftUI, **iOS 26.1+** (raised from 18.0 in M10 for the native floating tab bar; 26.1 is the first that can hide the tab bar accessory when no night is active), iPhone only, portrait only.
- SwiftData for persistence (local only).
- ActivityKit + WidgetKit + App Intents for Live Activity and Control Center control.
- Core Location (`CLLocationUpdate.liveUpdates`, `CLBackgroundActivitySession`) + MapKit.
- Signing: **free Apple personal team** (installs expire after 7 days; reinstall from Xcode). Nothing in the POC needs push notifications or CloudKit.
- No third-party dependencies.

### Targets
| Target | Contents |
|---|---|
| `Barhop` (app) | App, models, location, night engine, UI, share rendering, App Intents |
| `BarhopWidgets` (widget extension) | Live Activity UI (Lock Screen + Dynamic Island), Control Center control |
| `Shared/` folder (member of both targets) | `NightActivityAttributes`, App Intents used by both, `Theme.swift` |

### Data sharing between app and extension
- Put the SwiftData store in an **App Group** container (`group.<bundle-id>.shared`) so both targets see the same data.
- The logging/undo intents must conform to **`LiveActivityIntent`** so they execute in the **app process** (which owns the location manager and night engine). Verify on device that the Control Center button also runs in the app process; if the free personal team refuses the App Group capability, rely on `LiveActivityIntent` running in-app and keep all writes in the app process.

### Info.plist / capabilities
- `NSLocationWhenInUseUsageDescription`: "Barhop maps your route and the places you visit during a night out."
- `UIBackgroundModes`: `location`
- `NSSupportsLiveActivities`: `YES`
- Local notifications permission (requested on first night start).
- Do **not** request "Always" location.

---

## 3. Core concepts (glossary)

- **Night**: one tracked outing, from start to end. Titled by its start date ("Sat 24 Oct") even if it crosses midnight.
- **Entry**: one logged thing at a moment in time. POC only has drink entries (beer).
- **Trail**: the breadcrumb of location points recorded during a night, split into **segments** (a new segment starts after a tracking gap).
- **Venue**: a detected stop during a night (a place you stayed), with a name and arrival/leave times. Belongs to one night.
- **Place**: a bar as a lasting thing, across nights: name, location, Apple Maps identity, menu. A venue (stop) links to at most one place; a place's stops are its **visits**.
- **Menu item**: a drink a place serves, identified by category + name + size.
- **Price observation**: one price you saw for a menu item on a given date. Never overwritten; the latest one is "the price".
- **Active night**: the (at most one) night that has started and not ended.

---

## 4. Data model (SwiftData)

```swift
@Model final class Night {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?            // nil = active
    var endReason: EndReason?     // .manual, .autoClosed
    var showMapOnShare: Bool = true
    @Relationship(deleteRule: .cascade) var entries: [Entry]
    @Relationship(deleteRule: .cascade) var trailPoints: [TrailPoint]
    @Relationship(deleteRule: .cascade) var venues: [Venue]
    var lastActivityAt: Date      // last entry, or start if none
}

@Model final class Entry {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var kind: EntryKind           // String-backed enum; POC: .drink only
    var latitude: Double?
    var longitude: Double?
    var horizontalAccuracy: Double?
    var payload: Data             // JSON-encoded, shape depends on kind
    var venue: Venue?
    var night: Night?
}

enum EntryKind: String, Codable { case drink /* future: cigarette, pouch, photo */ }

struct DrinkPayload: Codable {
    var drinkType: String   // "beer"
    var volumeMl: Int       // 500
}

@Model final class TrailPoint {
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var horizontalAccuracy: Double
    var segment: Int        // increments after a tracking gap
    var night: Night?
}

@Model final class Venue {
    @Attribute(.unique) var id: UUID
    var name: String            // auto-picked or user-picked
    var nameSource: NameSource  // .auto, .user, .address (fallback)
    var latitude: Double
    var longitude: Double
    var arrivedAt: Date
    var leftAt: Date?
    var night: Night?
    var place: Place?           // added with Places; nil = unlinked stop
}

@Model final class Place {
    @Attribute(.unique) var id: UUID
    var mapItemIdentifier: String?   // MKMapItem.identifier
    var name: String
    var address: String?
    var latitude: Double
    var longitude: Double
    var isSaved: Bool = false        // "want to go" bookmark
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var menuItems: [MenuItem]
    @Relationship(deleteRule: .nullify, inverse: \Venue.place) var stops: [Venue]
}

@Model final class MenuItem {
    @Attribute(.unique) var id: UUID
    var category: DrinkCategory      // beer, wine, shot, cocktail, soft
    var name: String
    var sizeMl: Int?
    @Relationship(deleteRule: .cascade) var prices: [PriceObservation]
    var place: Place?
}

@Model final class PriceObservation {
    @Attribute(.unique) var id: UUID
    var amount: Decimal
    var currency: String             // ISO code; UI offers only "HUF" for now
    var seenAt: Date
    var item: MenuItem?
}
```

Rules:
- Everything (timeline, map pins, report, share) works on generic `Entry`, so new kinds can be added without migrations of existing data.
- Save the context **after every entry and every venue change**; trail points can be batched (save at least every 30 s and on backgrounding).
- Settings via `@AppStorage`: `autoCloseHours` (default **3**).
- "Visited" and "last visited" are derived from `Place.stops`, never stored.
- A `Place` is stored only when you're detected there, add a price, or save it. Browsing Apple Maps results on Map or Search stores nothing.
- Adding a price for an existing (category, name, size) appends a `PriceObservation` to that `MenuItem`; it never edits an old one.
- Deleting a night leaves its places. Deleting a place (with confirm) removes its menu and prices and unlinks its stops, which keep their names.

---

## 5. Night lifecycle

- **Start**: tapping "Start night" on Home, **or** logging a beer (from any surface) when no night is active — this starts a night and logs the beer in one go.
- **Only one active night** at a time.
- **End**: "End night" button (Live night screen) → confirm → sets `endedAt = now`, `endReason = .manual`, ends Live Activity, stops location, opens the Report.
- **"Still out?" auto-close**:
  - Every entry (and night start) schedules a local notification at `lastActivityAt + autoCloseHours` ("Still out? Tap to keep your night going." with actions **Still out** / **End night**). Rescheduling replaces the previous one.
  - "Still out" bumps `lastActivityAt` to now (re-arms the timer).
  - If ignored: when the app next runs (location callback, any intent, or launch) and `now > lastActivityAt + autoCloseHours + 30 min grace`, end the night with `endedAt = lastActivityAt`, `endReason = .autoClosed`, and trim trail points after `endedAt`.
- **Recovery** (phone died, app force-quit, system kill): on launch, if an active night exists → apply auto-close check; if still active → restart location tracking and the Live Activity, start a **new trail segment**, open the Live night screen.

---

## 6. Location & venues

### Trail
- Use `CLLocationUpdate.liveUpdates()` inside a long-lived task while a night is active, and hold a `CLBackgroundActivitySession` for the night's duration (keeps updates flowing in background with only When-In-Use permission; shows the blue location indicator).
- **Reduced fidelity on purpose (battery)**: only record a point if it is ≥ 50 m from the last recorded point **or** ≥ 5 min since the last one; drop fixes with `horizontalAccuracy > 100 m`.
- A gap of > 10 min with no updates, or a recovery restart, starts a new `segment`. Gaps are drawn **dashed** between segments and **excluded** from walked distance. GPS drift while at a venue is excluded too: a fix taken during a stay and within the 75 m venue radius counts as being at the venue's center.

### Entry location
- When logging, take a **fresh precise fix** (one-shot, up to ~5 s timeout); fall back to the latest trail point if it times out.

### Stop (venue) detection
- A stop = the trail stays within **75 m** of its running centroid for **≥ 15 min**. Venue `arrivedAt` = first point in the cluster, `leftAt` = last point before leaving the radius.
- A beer logged when not inside an existing venue creates a **provisional venue** at the beer's location immediately (so "current venue" is available right away); it becomes a normal venue if the stay reaches 15 min, or is kept anyway since an entry references it.
- Entries attach to the venue they were logged in.

### Venue naming
- On venue creation, run `MKLocalPointsOfInterestRequest` (radius ~75 m) filtered to nightlife-ish categories: `.nightlife, .brewery, .winery, .restaurant, .cafe`. Auto-pick the nearest result (`nameSource = .auto`).
- If none: reverse-geocode to a street address (`nameSource = .address`).
- **Fix-up**: tapping a venue pin (Live night or Report) shows the nearest ~5 candidates + "Custom name…"; choosing one sets `nameSource = .user`. Renaming changes only that stop, never its place.

### Linking stops to places
- When a venue is named from a POI, link it to the `Place` with the same `mapItemIdentifier`, creating the place if none exists.
- Fallback when the POI has no identifier: an existing place within **75 m** with the same name.
- Stops named by address or with a custom name stay unlinked, until you pick a POI candidate in the venue sheet, which links them.
- **Backfill** (once, after the Places migration, in the background, best-effort): run a POI lookup for each past stop that isn't linked and link it by the rules above. Failed lookups leave the stop unlinked; a manual pick still works.

---

## 7. Screens

All UI dark-only, in the "Amber night" direction (§10).

### Navigation
- A native floating `TabView` with four equal tabs: **Home · Search · Map · Profile**. Search is a regular tab, not `role: .search`, so its field sits at the top of the Search screen. The app opens on Home.
- **Live night** is a full-screen cover over the tabs. It auto-opens when a night is active, as before, and the Report still opens when the night ends.
- **Night pill**: while a night is active, `.tabViewBottomAccessory` shows the elapsed timer, the 🍺 count and a small **+1** button. Tapping the pill reopens Live night.
- **Location permission**: requested at night start, and also the first time Map or Search opens if you haven't answered yet. If it's denied, Map centers on Budapest and Search leaves out the Nearby group.

1. **Home** (tab)
   - Big "Start night" button (becomes "Resume night" if one is active — though normally the app opens straight into Live night).
   - **Recent nights**: the last 3 (date title, duration, 🍺 count, venue count). Tap → Report. "See all" → Profile.
   - **Recent places**: the last 5 visited. Tap → Place detail. "See all" → Profile.
2. **Search** (tab)
   - One search field, results in three groups: **Your places** (by name), **Drinks** (menu items by name, each with its place and latest price), **Nearby on Maps** (Apple Maps nightlife results around you, not stored; tap → Place detail in a temporary state with Save and Add price).
   - Segment **All / Visited / Saved**; sort by **Distance** (default) or **0.5 L beer price**.
   - Empty field: your saved places, then recently visited ones.
3. **Map** (tab)
   - Your places as amber pins: visited filled, saved outlined.
   - Apple Maps nightlife places you haven't stored, as dimmer pins, fetched for the visible region on pan (debounced, capped at ~50).
   - Pin label: the latest 0.5 L beer price, when known.
   - Pin tap → Place detail as a sheet. No clustering, no past-night trails.
4. **Profile** (tab)
   - **Nights**: full history, newest first; tap → Report; swipe to delete (with confirm).
   - **Places**: visited and saved; tap → Place detail; swipe to delete (with confirm).
   - **Settings** (moved here from the gear on Home).
   - No aggregate stats.
5. **Place detail**
   - Name, address, small map, "Open in Maps", Save toggle.
   - Menu grouped by drink category; each item shows its latest price and age ("1 200 Ft · 3 weeks ago").
   - **Add drink / price**: category, name (suggested from names used at other places), size, price. HUF only.
   - **Your visits**: the nights you stopped here; tap → Report.
6. **Live night** (full-screen cover; auto-opens when a night is active)
   - Live map: trail (solid segments, dashed gaps), venue pins, user location. Pin tap → rename sheet.
   - Header: elapsed time (live), 🍺 count, current venue name. Tapping the venue name opens its place (if linked), where you can add a price.
   - Venue pin sheet: "Open place" when the stop is linked.
   - Big **"+1 Beer"** button.
   - Timeline of entries (time, venue); swipe to delete, tap to edit time.
   - "End night" button.
7. **Report** (for an ended night; opens from Home, Profile or a place's visits)
   - Stats: duration, beers, liters (beers × 0.5), pace (beers/hour over duration), longest gap between beers, distance walked, venues (ordered, each with time spent; a linked venue row → Place detail).
   - Map with trail + pins (pin tap → rename sheet, with "Open place" when linked).
   - Timeline (editable as above; edits update stats).
   - "Show map on share" toggle (stored as `showMapOnShare`).
   - **Share** menu → "Card (PNG)", "Sticker (PNG)", "Copy sticker".
8. **Settings** (in Profile)
   - "Auto-close after: 2 / 3 / 4 / 6 hours" (default 3).

Empty/edge states: night with 0 beers still produces a report; night with no location permission works (counts only, no map) and shows a one-line prompt to enable location.

---

## 8. Live Activity, Dynamic Island, Control Center

### `NightActivityAttributes`
```swift
struct NightActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var beerCount: Int
        var currentVenueName: String?
        var lastEntryID: UUID?
        var undoUntil: Date?
    }
    var nightID: UUID
    var startedAt: Date
}
```

### Lock Screen layout
- 🍺 count (large), elapsed time via `Text(startedAt, style: .timer)`, current venue name.
- **"+1 Beer"** button → `LogBeerIntent`.
- While `undoUntil > now`: "Added Beer · **Undo**" → `UndoLastEntryIntent`.

### Dynamic Island
- Compact: 🍺 count (leading), elapsed timer (trailing).
- Expanded: same as Lock Screen.
- Minimal: 🍺 count.

### Intents (in `Shared/`, conform to `LiveActivityIntent`)
- `LogBeerIntent`: starts a night if none active, adds a beer entry (with location fix), updates Live Activity with `undoUntil = now + 10 s`, reschedules auto-close notification.
- `UndoLastEntryIntent`: deletes the night's last entry **only if it was created < 60 s ago**; otherwise no-op. Updates the activity.
- After ~10 s the app updates the activity to clear the undo row (best effort; if it doesn't arrive, the 60 s rule keeps Undo safe).

### Control Center
- iOS 18 `ControlWidgetButton` "+1 Beer" → `LogBeerIntent`.

### 8-hour limit
- Live Activities end after ~8 h. On any app run (location callback, intent, foreground) during an active night, if the activity is gone, request a new one with the current state.
- **Known limitation**: ActivityKit only allows starting an activity while the app is in the foreground (background start needs push-to-start, which needs a paid account). If restarting fails in the background, it restarts the next time the app is opened. Note this in code comments; don't build workarounds.

---

## 9. Sharing

- Rendered with SwiftUI `ImageRenderer` at 3× scale.
- **Card**: 9:16 (1080×1920 px), opaque background. Content: Barhop wordmark, night date, big stats (duration, beers, liters, distance), venue count + ordered venue names (truncate after ~6 with "+N more"), and — if `showMapOnShare` — a map image from `MKMapSnapshotter` with the trail and venue pins drawn on top.
- **Sticker**: transparent PNG (`renderer.isOpaque = false`), stats + the trail drawn as a plain line shape (no map tiles; path normalized into a fixed box) if `showMapOnShare`, otherwise stats only. Designed to be legible over any photo (white text with subtle shadow).
- "Card (PNG)" / "Sticker (PNG)" → `ShareLink` / share sheet with the PNG file (named `Barhop-YYYY-MM-DD.png`).
- "Copy sticker" → `UIPasteboard.general.setData(png, forPasteboardType: UTType.png.identifier)` (paste into an Instagram story).
- No direct Instagram API integration.

---

## 10. UI, theme, strings

- **Visual direction: "Amber night"** (decided after M8): warm near-black canvas, a single beer-amber accent with a soft glow, warm white text, rounded type throughout. Lists are drawn as floating cards; the live night is a full-screen map with frosted panels. The tab bar and night pill are the system Liquid Glass ones, tinted with the amber accent from `Theme`. Every color, font, radius and spacing value still lives in **`Theme.swift`**; share card/sticker styling and the Live Activity read from it too.
- App icon: placeholder (simple 🍺-style glyph on solid background) until the visual direction is set.
- English only; **all user-facing strings in a String Catalog** (`Localizable.xcstrings`) for an easy Hungarian version later.

---

## 11. Build order (milestones)

Each milestone should build, run, and meet its acceptance check before the next.

1. **Skeleton + persistence**
   Project, both targets, App Group, SwiftData models, `Theme.swift`, String Catalog. Home + Live night with in-app "+1 Beer", start/end night, history list.
   ✅ Start a night, log 3 beers, kill the app, relaunch: night and beers are still there; end it; it shows in history.

2. **Location trail + live map**
   Permission flow, `liveUpdates` + `CLBackgroundActivitySession`, filtering rules, segments, map with trail.
   ✅ In the Simulator with a GPX route (create `Simulator/BudapestCrawl.gpx`: a walk between ~4 bars in District VII with 20–40 min dwell at each), the trail draws live, including while the app is backgrounded.

3. **Venues**
   Stop detection, provisional venues on beer log, POI naming, address fallback, pin fix-up sheet, entry→venue attachment.
   ✅ The GPX crawl yields ~4 venues with sensible names; renaming a pin persists.

4. **Report**
   All stats, map, editable timeline, share toggle (no export yet).
   ✅ Stats match a hand-calculation for the GPX crawl night.

5. **Live Activity + intents**
   Attributes, Lock Screen + Dynamic Island UI, `LogBeerIntent`, `UndoLastEntryIntent`, undo row, start-night-from-intent.
   ✅ On device, with the phone locked: tap +1 three times, undo once → app shows 2 beers.

6. **Control Center control**
   ✅ "+1 Beer" from Control Center logs a beer (and starts a night if none).

7. **Auto-close, recovery, 8 h restart**
   Notification scheduling/actions, auto-close check, recovery on launch, new segment after gaps, activity restart.
   ✅ With `autoCloseHours` temporarily set to 2 minutes in a debug build: ignoring the notification ends the night at the last beer's time.

8. **Sharing**
   Card + sticker rendering, map snapshot with overlays, share sheet, copy sticker.
   ✅ Both PNGs export; the sticker has a transparent background when pasted into an Instagram story; map toggle hides map on both.

9. **Polish**
   Empty states, no-location mode, all strings in the catalog, a final pass that no colors/fonts are hard-coded outside `Theme`.

### Places (after M9)

10. **Tab shell**
    iOS 26.1 deployment target, `TabView` with Home · Search · Map · Profile (Search and Map as placeholders), Live night as a full-screen cover, night pill in `.tabViewBottomAccessory`, Settings moved to Profile, nights list moved to Profile.
    ✅ Start a night from Home: Live night opens over the tabs; dismiss it: the pill shows the timer and count, its +1 logs a beer, tapping it reopens Live night; end the night: the Report opens and the pill is gone.
11. **Places**
    `Place` model and `Venue.place`, stop → place linking, venue sheet links on POI pick, one-time backfill of past nights, "Open place" links from Live night and Report (to a minimal Place detail).
    ✅ The GPX crawl, run twice as two nights, yields ~4 places, each with 2 visits; a stop renamed to a custom name stays unlinked; past nights from before the migration end up linked.
12. **Place detail + menu**
    `MenuItem`, `PriceObservation`, full Place detail, Add drink / price (from Place detail and the Live night venue header), name suggestions, Save toggle.
    ✅ Add a 0.5 L beer at 1 200 Ft, then the same beer at 1 300 Ft: the place shows one item at 1 300 Ft "today", and both observations are stored.
13. **Map tab**
    Your places (visited / saved), unsaved Apple Maps nightlife pins for the visible region, price labels, pin → Place detail sheet, permission prompt / Budapest fallback.
    ✅ Panning around District VII shows your places in amber and other bars dimmed; saving a dim one turns it into an outlined amber pin; a place with a beer price shows it on the pin.
14. **Search tab**
    The three result groups, All / Visited / Saved segment, distance / beer-price sort, empty-field state, temporary Place detail for Maps results.
    ✅ Searching a beer name lists every place that serves it with its price; sorting by price orders them cheapest first; a Nearby result can be saved and then appears under Your places.
15. **Home & Profile**
    Recent nights and recent places on Home with "See all", the Places list in Profile with delete, final polish (empty states for no places / no prices, strings in the catalog, no literals outside `Theme`).
    ✅ Deleting a place keeps its nights intact with the stop names unchanged; Home shows the newest 3 nights and 5 places.

---

## 12. Testing notes

- Use Xcode's location simulation with the GPX file for milestones 2–4 and 8.
- Live Activities, Control Center and background location must be verified on a real iPhone.
- Free personal team: the app expires every 7 days — reinstall from Xcode; data survives a reinstall over the existing app.
