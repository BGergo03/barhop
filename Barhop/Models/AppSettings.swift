enum AppSettings {
    static let autoCloseHoursKey = "autoCloseHours"
    static let defaultAutoCloseHours = 3
    static let autoCloseHourOptions = [2, 3, 4, 6]
    /// Debug builds only: treat `autoCloseHours` as minutes to test auto-close quickly.
    static let autoCloseDebugMinutesKey = "autoCloseDebugMinutes"
    /// Set once the one-time linking of pre-Places stops has run (SPEC §6).
    static let placesBackfillDoneKey = "placesBackfillDone"
    /// Debug builds only: the nights and places the sample data added, so it can remove them.
    static let sampleDataIDsKey = "sampleDataIDs"
}
