import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.autoCloseHoursKey) private var autoCloseHours = AppSettings.defaultAutoCloseHours
    #if DEBUG
    @AppStorage(AppSettings.autoCloseDebugMinutesKey) private var autoCloseDebugMinutes = false
    #endif
    @Environment(NightEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Auto-close after", selection: $autoCloseHours) {
                        ForEach(AppSettings.autoCloseHourOptions, id: \.self) { hours in
                            Text("\(hours) hours").tag(hours)
                        }
                    }
                } footer: {
                    Text("If you haven't logged anything for this long, Barhop asks whether you're still out.")
                }
                #if DEBUG
                Section {
                    Toggle("Treat hours as minutes", isOn: $autoCloseDebugMinutes)
                } header: {
                    Text("Debug")
                } footer: {
                    Text("Also shortens the 30 minute grace period to 30 seconds.")
                }
                #endif
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") { dismiss() }
            }
            .onChange(of: autoCloseHours) { engine.rescheduleStillOutReminder() }
            #if DEBUG
            .onChange(of: autoCloseDebugMinutes) { engine.rescheduleStillOutReminder() }
            #endif
        }
    }
}
