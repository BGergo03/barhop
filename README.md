# barhop

## On-device verification

Things the Simulator can't show, checked on a real iPhone (SPEC §12).

| Milestone | Check | Result |
|---|---|---|
| M5 | Phone locked, app killed: Live Activity "+1 Beer" ×3, "Undo" ×1 → app shows 2 beers | _not yet verified_ |
| M5 | Live Activity intents run in the app process with the app killed (entries get a location, the activity updates) | _not yet verified_ |
| M6 | Control Center "+1 Beer" logs a beer, and starts a night if none is active | _not yet verified_ |
| M6 | The control's intent runs in the app process (Console, subsystem `com.bgergo03.barhop`, category `Intents`: "LogBeerIntent running in app") | _not yet verified_ |
