enum AppSettings {
    static let autoCloseHoursKey = "autoCloseHours"
    static let defaultAutoCloseHours = 3
    static let autoCloseHourOptions = [2, 3, 4, 6]
    /// Debug builds only: treat `autoCloseHours` as minutes to test auto-close quickly.
    static let autoCloseDebugMinutesKey = "autoCloseDebugMinutes"
}
