import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.autoCloseHoursKey) private var autoCloseHours = AppSettings.defaultAutoCloseHours
    #if DEBUG
    @AppStorage(AppSettings.autoCloseDebugMinutesKey) private var autoCloseDebugMinutes = false
    #endif
    @Environment(NightEngine.self) private var engine

    var body: some View {
        Form {
            Section {
                Picker("Auto-close after", selection: $autoCloseHours) {
                    ForEach(AppSettings.autoCloseHourOptions, id: \.self) { hours in
                        Text("\(hours) hours").tag(hours)
                    }
                }
                .cardRow()
            } footer: {
                Text("If you haven't logged anything for this long, Barhop asks whether you're still out.")
            }
            #if DEBUG
            Section {
                Toggle("Treat hours as minutes", isOn: $autoCloseDebugMinutes)
                    .cardRow()
            } header: {
                SectionLabel("Debug")
            } footer: {
                Text("Also shortens the 30 minute grace period to 30 seconds.")
            }
            #endif
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: autoCloseHours) { engine.rescheduleStillOutReminder() }
        #if DEBUG
        .onChange(of: autoCloseDebugMinutes) { engine.rescheduleStillOutReminder() }
        #endif
    }
}
