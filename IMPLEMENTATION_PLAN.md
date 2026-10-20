# Barhop — Implementation Plan

Derived from [SPEC.md](SPEC.md). The spec is the source of truth for *what*; this document fixes *how* and *in what order*. Milestones follow SPEC §11 one-to-one (M10–M15 are the Places work); each ends with the spec's acceptance check plus the extra checks listed here.

---

## 0. Conventions

### Git
- `main` is always buildable. One branch per milestone: `m1-skeleton`, `m2-trail`, … merged into `main` once its acceptance check passes.
- Small commits, imperative subject, prefixed with the milestone: `M2: Filter trail fixes by accuracy and distance`.
- **Commits are authored by the developer only — no `Co-Authored-By` trailers, no "Generated with" lines, no AI attribution of any kind.**

### Code
- Swift 6 language mode, strict concurrency. UI, `NightEngine` and SwiftData access on `@MainActor`.
- No third-party dependencies (SPEC §2).
- No literal colors, fonts or corner radii outside `Theme.swift`. No user-facing string literals outside `Localizable.xcstrings` (SwiftUI `Text("…")` keys are fine — they land in the catalog automatically; non-SwiftUI strings use `String(localized:)`).
- Logic that can be pure **is** pure (trail filter, stop detection, stats, segment/distance math) and lives in plain structs with no SwiftData/CoreLocation-manager dependencies, so it can be unit-tested with fixtures.

### Repo layout
```
Barhop.xcodeproj
Barhop/
  App/            BarhopApp.swift, AppRouter (tabs, paths, Live night cover), RootView
  Models/         Night, Entry, Venue, TrailPoint, Place, MenuItem, PriceObservation, enums, payloads, ModelContainer factory
  Engine/         NightEngine, AutoClose, Recovery
  Places/         PlaceStore, PlaceLinker, NearbyPlaces (from M11; the backfill is NightEngine+Places)
  Location/       LocationService, TrailFilter, StopDetector, VenueNamer
  Activity/       LiveActivityController
  Notifications/  NotificationService
  Report/         ReportStats
  Share/          ShareRenderer, CardView, StickerView, MapSnapshot
  UI/             Home/, Search/, Map/, Profile/, Place/, LiveNight/, Report/, Settings/, Components/ (Timeline, VenueSheet, TrailMap, NightPill)
  Resources/      Localizable.xcstrings, Assets.xcassets
BarhopWidgets/    BarhopWidgetsBundle, NightLiveActivity, LogBeerControl
Shared/           NightActivityAttributes, LogBeerIntent, UndoLastEntryIntent, Theme.swift, AppGroup.swift
BarhopTests/      Unit tests for the pure logic
Simulator/        BudapestCrawl.gpx
```
`BarhopTests` is an addition to the spec's target list — a unit-test target for the pure logic only, no UI tests.

---

## 1. Architecture

```
            ┌──────────────── app process ────────────────┐
 UI (SwiftUI) ─┐                                             │
 LogBeerIntent ┼──► NightEngine (@MainActor, single instance)│
 UndoIntent   ─┘     │  owns ModelContext (App Group store)  │
 Notification ──────►│                                       │
   actions           ├─► LocationService ─► TrailFilter ─► StopDetector ─► VenueNamer
                     ├─► LiveActivityController (ActivityKit)
                     └─► NotificationService (UNUserNotificationCenter)
            └─────────────────────────────────────────────┘
 BarhopWidgets extension: renders Live Activity + Control; never writes data.
```

- **`NightEngine`** is the single entry point for every mutation: `startNight()`, `logBeer(source:)`, `undoLastEntry()`, `deleteEntry(_:)`, `editEntryTime(_:_:)`, `renameVenue(_:to:source:)`, `endNight(reason:at:)`, `stillOut()`, `runMaintenance()` (auto-close check + activity restart; called on launch, foreground, every location callback, every intent).
- Intents reach it via `AppDependencyManager.shared.add { NightEngine.shared }` and `@Dependency`. Because the intents are `LiveActivityIntent`, they run in the app process, so the engine is the only writer.
- Views read via `@Query`; they never write to the context directly.
- **Enums in SwiftData**: store `EntryKind`, `EndReason`, `NameSource` as raw `String` properties with computed typed accessors, so `#Predicate` works and adding cases never needs a migration.
- **Relationships** (inverses made explicit): `Night.entries/trailPoints/venues` cascade ↔ `night`; `Venue.entries` (nullify) ↔ `Entry.venue`; `Place.stops` (nullify) ↔ `Venue.place`; `Place.menuItems` cascade ↔ `MenuItem.place`; `MenuItem.prices` cascade ↔ `PriceObservation.item`. `DrinkCategory` is stored raw like the other enums.
- **`PlaceStore`** (`@MainActor`, from M11) is the single writer for places, menu items and prices, the way `NightEngine` is for nights: `place(for:)` (find-or-create from a map item), `link(_ venue:, to:)`, `setSaved(_:_:)`, `addPrice(place:category:name:sizeMl:amount:)`, `delete(_:)`. `NightEngine` calls it after naming a venue; views call it for Save / Add price.
- `ModelContainer` built from one factory in `Shared/AppGroup.swift` pointing at the App Group container; falls back to the default app container if the App Group is unavailable (personal-team risk, SPEC §2) and logs which one it used.

---

## 2. Milestones

### M1 — Skeleton + persistence
**Setup (manual, in Xcode — signing for a free personal team has to be done there anyway)**
1. New iOS App `Barhop`, SwiftUI, iOS 18.0, iPhone only, portrait only, no Core Data/SwiftData template boilerplate.
2. Add Widget Extension target `BarhopWidgets` with "Include Live Activity" and "Include Control" checked.
3. Add App Group `group.<bundle-id>.shared` to both targets. **If the personal team refuses it**, remove it and continue — the fallback in the container factory covers it.
4. Create `Shared/` and add its files to both targets. Add `BarhopTests` unit-test target.
5. Info.plist keys from SPEC §2 (`NSLocationWhenInUseUsageDescription`, `UIBackgroundModes=location`, `NSSupportsLiveActivities=YES`).

**Code**
- Models exactly as SPEC §4 (+ `EndReason`, `NameSource`, `Venue.entries` inverse). `DrinkPayload` encode/decode helpers on `Entry`.
- `Theme.swift`: color, font, radius, spacing tokens (system defaults for now). App forced to dark mode.
- `Localizable.xcstrings` created; all strings go through it from day one.
- `NightEngine`: start, logBeer (no location yet), deleteEntry, editEntryTime, endNight(manual). Save after every mutation.
- Screens: Home (start/resume, history list, swipe-to-delete with confirm), Live night (elapsed timer, 🍺 count, +1 Beer, timeline with swipe-delete & tap-to-edit-time, End night with confirm), minimal Report stub (date + count), Settings (auto-close picker 2/3/4/6 h via `@AppStorage("autoCloseHours")`).
- Routing: app opens straight into Live night when a night is active.
- Night title formatter: start date, `"EEE d MMM"` via `Date.FormatStyle`.

**Tests**: payload round-trip; night title for a night crossing midnight.
✅ **Acceptance** (SPEC): start, log 3 beers, kill, relaunch → still there; end → in history.

---

### M2 — Location trail + live map
- `LocationService`: on night start, request When-In-Use (once), open a `CLBackgroundActivitySession`, run `for try await update in CLLocationUpdate.liveUpdates()` in a task owned by the engine; cancel both on end.
- `TrailFilter` (pure): drop `horizontalAccuracy > 100`; accept if ≥ 50 m from last accepted **or** ≥ 5 min since last accepted; assigns `segment`, incrementing when the gap since the last *received* update is > 10 min.
  - Exception: Core Location pauses `liveUpdates` once it reports the device as stationary (e.g. sitting in a bar). Silence after a stationary update is **not** a gap: when updates resume, a "hold" point is recorded at the last position just before the resuming fix, so the stay stays in one segment and stop detection (M3) sees its full length.
- Trail saving: insert points as accepted, `save()` at most every 30 s and on `scenePhase == .background`.
- `currentFix(timeout: 5s)` one-shot helper for entry locations (fallback: latest trail point). Wire into `logBeer`.
- `TrailMap` component (MapKit for SwiftUI): solid `MapPolyline` per segment, dashed polyline between the last point of segment *n* and first of *n+1*, `UserAnnotation`.
- No-permission path: tracking silently off, Live night shows the one-line "enable location" prompt (SPEC §7), counts still work.
- Create `Simulator/BudapestCrawl.gpx`: ~4 real District VII bars (e.g. along Kazinczy u. / Király u.), walking legs between them with timestamped points every ~20 s, 20–40 min dwells with a little jitter (5–20 m) inside each bar. Attach it to the scheme.

**Tests**: TrailFilter accuracy/distance/time rules; segment increment on 10 min gap; walked distance excludes inter-segment gaps.
✅ **Acceptance** (SPEC): GPX route draws live, including in background.

---

### M3 — Venues
- `StopDetector` (pure, incremental): feed accepted points; maintain a candidate cluster with a running centroid; a point > 75 m from the centroid closes the cluster; a cluster spanning ≥ 15 min becomes a stop (`arrivedAt` = first point, `leftAt` = last point inside). Emits `.arrived(centroid, at)`, `.updated`, `.left(at)`.
- Engine reacts: create/update/close `Venue`; save on every venue change.
- **Provisional venues**: `logBeer` when not inside a venue → create a venue at the entry location immediately. When a confirmed stop forms within 75 m of a provisional venue, merge into it (keep the provisional one, update its coordinates/times) instead of creating a duplicate. Provisional venues referenced by entries are never removed.
- Entry → venue attachment at log time: the open venue (if any) else the new provisional one.
- `VenueNamer`: `MKLocalPointsOfInterestRequest(center:radius: 75)` with the SPEC category filter, nearest result → `.auto`; else `CLGeocoder` reverse-geocode → `.address`; runs async after creation, never blocks logging. Never overwrite a `.user` name.
- Venue sheet (pin tap, Live night + Report): nearest ~5 POI candidates + "Custom name…" → `.user`.
- Header shows current venue name.

**Tests**: StopDetector on a synthetic dwell (≥ 15 min yields a stop; 14 min doesn't; walking past doesn't); provisional→confirmed merge.
✅ **Acceptance** (SPEC): GPX crawl → ~4 venues with sensible names; rename persists.

---

### M4 — Report
- `ReportStats` (pure, input: entries, trail points, venues, start/end):
  - duration = `endedAt − startedAt`
  - beers; liters = Σ `volumeMl` / 1000 (= beers × 0.5 today, but computed from payload)
  - pace = beers / duration-hours (show "—" when duration < 1 min)
  - longest gap between consecutive beers ("—" with < 2 beers)
  - distance = Σ point-to-point distance **within** segments only, with fixes taken during a venue stay and within 75 m of it snapped to the venue center (so drift while sitting in a bar adds nothing, the walk in/out still counts)
  - venues ordered by `arrivedAt`, each with time spent (`leftAt ?? endedAt` − `arrivedAt`)
- Report screen: stats, `TrailMap` with pins (tap → rename), editable timeline (stats recompute via `@Query`), "Show map on share" toggle bound to `night.showMapOnShare`, Share menu placeholder.
- Zero-beer and no-location nights render without crashes or empty-looking holes.

**Tests**: ReportStats against a hand-computed fixture of the GPX crawl night (same numbers used for the acceptance check).
✅ **Acceptance** (SPEC): stats match the hand-calculation.

---

### M5 — Live Activity + intents
- `NightActivityAttributes` in `Shared/` exactly as SPEC §8.
- `LiveActivityController`: `start(for night)`, `update(state)`, `end()`, `ensureRunning()` (restart if missing; wrap in do/catch — background start fails without push-to-start; comment this as the known limitation, no workaround).
- `NightLiveActivity` UI: Lock Screen (🍺 large, `Text(startedAt, style: .timer)`, venue, "+1 Beer" `Button(intent:)`, undo row while `undoUntil > now`), Dynamic Island compact/expanded/minimal per SPEC.
- `LogBeerIntent` / `UndoLastEntryIntent` (`LiveActivityIntent`, `@Dependency var engine`): call engine → engine updates activity. Log sets `undoUntil = now + 10 s` and schedules a best-effort clear after 10 s. Undo deletes the last entry only if created < 60 s ago.
- Logging a beer with no active night starts one (engine already does this — intents just call `logBeer`).
- Verify on device and record the result in the README: do the intents actually run in the app process with the app killed?

✅ **Acceptance** (SPEC, on device, locked): +1 ×3, undo ×1 → app shows 2.

---

### M6 — Control Center control
- `LogBeerControl`: `ControlWidget` with `ControlWidgetButton(action: LogBeerIntent())`, label "+1 Beer".
- Verify on device it runs in the app process and writes to the same store; if not, fall back per SPEC §2.

✅ **Acceptance** (SPEC): Control Center "+1 Beer" logs (and starts a night if none).

---

### M7 — Auto-close, recovery, 8 h restart
- `NotificationService`: permission on first night start; category `STILL_OUT` with actions **Still out** / **End night**; one pending request with a fixed identifier per night (rescheduling replaces it) at `lastActivityAt + autoCloseHours`. `UNUserNotificationCenterDelegate` routes actions to `engine.stillOut()` / `engine.endNight(.manual)`.
- Every entry and night start bumps `lastActivityAt` and reschedules.
- `runMaintenance()` auto-close: if `now > lastActivityAt + autoCloseHours + 30 min` → `endNight(.autoClosed, at: lastActivityAt)`, delete trail points after `endedAt`, close any open venue at `endedAt`, end activity, cancel notification. Called from launch, foreground, each location callback, each intent.
- Recovery on launch: auto-close check → if still active: restart location with a **new segment**, `ensureRunning()` the activity, open Live night.
- Debug-only override: `#if DEBUG` setting to treat `autoCloseHours` as minutes for testing.

**Tests**: auto-close decision function (boundary at exactly +grace); trail trimming.
✅ **Acceptance** (SPEC): 2-minute debug setting, notification ignored → night ends at last beer's time.

---

### M8 — Sharing
- `MapSnapshot`: `MKMapSnapshotter` over the trail's bounding region (padded), then draw segments (solid/dashed) and venue pins onto the snapshot image with `UIGraphicsImageRenderer` using `snapshot.point(for:)`.
- `CardView` (1080×1920 px → 360×640 pt at 3×, opaque): wordmark, date, duration/beers/liters/distance, venue count + ordered names (max 6, then "+N more"), map if `showMapOnShare`.
- `StickerView` (transparent): stats + trail as a normalized `Path` in a fixed box if `showMapOnShare`; white text with subtle shadow. All styling from `Theme`.
- `ShareRenderer`: `ImageRenderer` scale 3, `isOpaque` false for sticker; writes `Barhop-YYYY-MM-DD.png` to a temp dir; `ShareLink` for card/sticker; "Copy sticker" → `UIPasteboard.general.setData(_, forPasteboardType: UTType.png.identifier)`.

✅ **Acceptance** (SPEC): both PNGs export; sticker transparent in an Instagram story; toggle hides map on both.

---

### M9 — Polish
- Empty states: no nights yet (Home), zero-beer night (Live/Report), no location (prompt + counts-only report and share).
- Placeholder app icon.
- Audit: `grep` for `Color(`, `.font(.system`, `cornerRadius:` literals outside `Theme.swift`; Xcode "Stale/missing" check on the String Catalog is clean.
- Guardrail copy review (SPEC §1): no streaks, scores, or "drink more" phrasing.
- README: build/install steps for a free personal team, the 7-day reinstall note, on-device verification results from M5/M6.

---

### M10 — Tab shell
- Raise `IPHONEOS_DEPLOYMENT_TARGET` to 26.1 on all targets (see risks first); 26.1 brings `tabViewBottomAccessory(isEnabled:)`, which the pill needs to hide between nights. Drop any `#available(iOS 18…)` / pre-26 branches that become dead.
- `RootView`: `TabView` with `Tab` for Home · Search · Map · Profile (plain tabs, no `role: .search`), each with its own `NavigationStack` and `Route` path. Search and Map are placeholders for now.
- Live night moves from a pushed route to `.fullScreenCover(item:)` driven by the active night; the existing `onChange` routing keeps auto-opening it and presents the Report (pushed on the Home stack) when the night ends.
- `NightPill` in `.tabViewBottomAccessory(isEnabled:)`, shown only while a night is active: `Text(startedAt, style: .timer)`, 🍺 count, +1 → `engine.logBeer(source: .app)`; tap → reopen the cover.
- Profile: nights list (moved from Home, with swipe-to-delete) and a Settings row (the Home gear goes away). Home keeps Start/Resume and shows the last 3 nights.
- Tint the tab bar and pill with the `Theme` accent.
✅ **Acceptance** (SPEC M10).

---

### M11 — Places
- Models `Place`, `MenuItem`, `PriceObservation`, `DrinkCategory`; `Venue.place`. Lightweight migration only (new models, one optional relationship).
- `VenueCandidate` gains `mapItemIdentifier: String?` (from `MKMapItem.identifier?.rawValue`) and `address`.
- `PlaceLinker` (pure): given a candidate and the existing places, return `.existing(Place.ID)` by identifier, else by same name within 75 m, else `.create`. Unit-tested.
- `NightEngine+Venues`: after auto-naming from a POI, call `PlaceStore` to link. Venue sheet POI pick → relink; custom name → leave the link as it is (renaming a stop never touches its place); address names → no link.
- Backfill (`NightEngine+Places`): once per install (`placesBackfillDone` in `UserDefaults`), serially walks unlinked, non-address venues of ended nights, looks up every POI within 75 m (not just the nearest 5: in Kazinczy u. "Szimpla Kert" is the 9th result) and links the one with the same name. 1.5 s between lookups, resumable, never blocks launch; runs again next launch if every lookup came back empty.
- "Open place" in the venue sheet and Report venue rows; Live night header venue name → place. A minimal `PlaceDetailView` (name, address, visits) as the target.
**Tests**: `PlaceLinker` identifier match, name+distance fallback, 76 m miss, different-name miss, different identifiers; engine linking, shared place across nights, address/custom-name rules, backfill.
- `VenueNamer` moves off the APIs deprecated in iOS 26 (`MKMapItem.placemark`, `CLGeocoder`) to `MKMapItem.location` / `.address` and `MKReverseGeocodingRequest`, and refuses invalid coordinates (MapKit throws an exception for them).
✅ **Acceptance** (SPEC M11).

---

### M12 — Place detail + menu
- Full `PlaceDetailView`: header, small `Map` with the pin, "Open in Maps" (`MKMapItem.openInMaps`, or the identifier when there is one), Save toggle, menu grouped by `DrinkCategory` with the latest price and `RelativeDateTimeFormatter`-style age, visits → Report.
- Add drink / price sheet: category picker, name field with suggestions (distinct `MenuItem.name` across places for that category), size picker (0.33 / 0.4 / 0.5 L / custom, none for shots), amount with a HUF formatter. `PlaceStore.addPrice` finds-or-creates the item by (category, name normalized for case and whitespace, size) and appends an observation.
- A temporary detail mode for an unstored map item: Save and Add price call `PlaceStore.place(for:)` first, then continue.
- `Place.latestBeerPrice` helper (0.5 L beer with the newest observation), used by Map and Search.
**Tests**: item find-or-create normalization; latest price picks the newest `seenAt`, not the newest insert.
✅ **Acceptance** (SPEC M12).

---

### M13 — Map tab
- `NearbyPlaces`: `MKLocalPointsOfInterestRequest(coordinateRegion:)` with the SPEC §6 category filter, run on `onMapCameraChange(frequency: .onEnd)`, debounced, cancelling the previous request, capped at ~50. Results whose identifier matches a stored place are dropped (that place is already drawn).
- Annotations: stored places as amber pins (visited = has stops: filled; saved only: outlined), Maps results dimmed; label shows `latestBeerPrice` when present. Pin tap → `PlaceDetailView` in a sheet (temporary mode for Maps results).
- Permission: request When-In-Use on first appearance if not determined; denied → initial camera on central Budapest.
✅ **Acceptance** (SPEC M13).

---

### M14 — Search tab
- `.searchable` on the Search tab's stack. Results:
  - Your places: `@Query` filtered by name (`localizedStandardContains`).
  - Drinks: `MenuItem`s by name, grouped per place, with the latest price.
  - Nearby on Maps: `MKLocalSearch` with a natural-language query, `resultTypes: .pointOfInterest`, nightlife filter, around the user; debounced; hidden without location permission.
- All / Visited / Saved segment filters the first two groups; sort by distance (from the current location; falls back to name without one) or by `latestBeerPrice` (places without one go last).
- Empty field: saved places, then recently visited.
✅ **Acceptance** (SPEC M14).

---

### M15 — Home & Profile
- Home: Recent places (last 5 by latest stop `arrivedAt`) with "See all" → Profile.
- Profile: Places list (Visited / Saved), swipe-to-delete with confirm → `PlaceStore.delete`.
- Empty states: no places yet, a place with no menu, a Search with no results.
- Polish pass as in M9: strings in the catalog, no literals outside `Theme`, guardrail copy check for the price UI (no "value" or "per beer" wording).
✅ **Acceptance** (SPEC M15).

---

## 3. Risks & decisions to watch

| Risk | Where | Plan |
|---|---|---|
| Personal team rejects App Group | M1 | Container factory falls back to the app container; all writes already happen in the app process via `LiveActivityIntent`. |
| Control Center intent runs in the extension, not the app | M6 | Verify on device; if so, the App Group store becomes mandatory for that path — revisit before continuing. |
| Live Activity can't restart in background after 8 h | M7 | Accepted limitation (SPEC §8); restart on next foreground. |
| Background location stops when app is killed by user | M2/M7 | Accepted; recovery on next launch starts a new segment. |
| POI search returns poor names in Budapest | M3 | Address fallback + manual fix-up sheet. |
| Visual direction (SPEC §10) | all | Decided after M8: "Amber night". Everything still routes through `Theme.swift`. |
| Your iPhone isn't on iOS 26.1+ | M10 | Checked: it's on iOS 27.0.1. Otherwise: if it isn't, stay on 18.0 with a plain `TabView` and a custom pill overlay instead of `.tabViewBottomAccessory`. |
| `MKMapItem.identifier` is nil for some POIs | M11 | Fallback match: same name within 75 m (SPEC §6). |
| MapKit throttles search requests (roughly 50 per minute per app) | M11, M13, M14 | Debounce map pans and search typing (~0.5 s); the backfill runs serially with a pause between lookups and resumes where it left off. |
