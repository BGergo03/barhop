# Barhop — Implementation Plan

Derived from [SPEC.md](SPEC.md). The spec is the source of truth for *what*; this document fixes *how* and *in what order*. Milestones follow SPEC §11 one-to-one; each ends with the spec's acceptance check plus the extra checks listed here.

---

## 0. Conventions

### Git
- `main` is always buildable. One branch per milestone: `m1-skeleton`, `m2-trail`, … merged into `main` once its acceptance check passes.
- Small commits, imperative subject, prefixed with the milestone: `M2: Filter trail fixes by accuracy and distance`.
- **Commits are authored by the developer only — no `Co-Authored-By` trailers, no "Generated with" lines, no AI attribution of any kind.**
- Tag each milestone on merge: `m1`, `m2`, …

### Code
- Swift 6 language mode, strict concurrency. UI, `NightEngine` and SwiftData access on `@MainActor`.
- No third-party dependencies (SPEC §2).
- No literal colors, fonts or corner radii outside `Theme.swift`. No user-facing string literals outside `Localizable.xcstrings` (SwiftUI `Text("…")` keys are fine — they land in the catalog automatically; non-SwiftUI strings use `String(localized:)`).
- Logic that can be pure **is** pure (trail filter, stop detection, stats, segment/distance math) and lives in plain structs with no SwiftData/CoreLocation-manager dependencies, so it can be unit-tested with fixtures.

### Repo layout
```
Barhop.xcodeproj
Barhop/
  App/            BarhopApp.swift, AppModel (routing: Home vs Live night), RootView
  Models/         Night, Entry, Venue, TrailPoint, enums, payloads, ModelContainer factory
  Engine/         NightEngine, AutoClose, Recovery
  Location/       LocationService, TrailFilter, StopDetector, VenueNamer
  Activity/       LiveActivityController
  Notifications/  NotificationService
  Report/         ReportStats
  Share/          ShareRenderer, CardView, StickerView, MapSnapshot
  UI/             Home/, LiveNight/, Report/, Settings/, Components/ (Timeline, VenueSheet, TrailMap)
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
- **Relationships** (inverses made explicit): `Night.entries/trailPoints/venues` cascade ↔ `night`; `Venue.entries` (nullify) ↔ `Entry.venue`.
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
  - distance = Σ point-to-point distance **within** segments only
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

## 3. Risks & decisions to watch

| Risk | Where | Plan |
|---|---|---|
| Personal team rejects App Group | M1 | Container factory falls back to the app container; all writes already happen in the app process via `LiveActivityIntent`. |
| Control Center intent runs in the extension, not the app | M6 | Verify on device; if so, the App Group store becomes mandatory for that path — revisit before continuing. |
| Live Activity can't restart in background after 8 h | M7 | Accepted limitation (SPEC §8); restart on next foreground. |
| Background location stops when app is killed by user | M2/M7 | Accepted; recovery on next launch starts a new segment. |
| POI search returns poor names in Budapest | M3 | Address fallback + manual fix-up sheet. |
| Visual direction (SPEC §10, **OPEN**) | all | Everything routes through `Theme.swift`; no rework needed when decided. |
