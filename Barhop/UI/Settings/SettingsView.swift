import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.autoCloseHoursKey) private var autoCloseHours = AppSettings.defaultAutoCloseHours
    #if DEBUG
    @AppStorage(AppSettings.autoCloseDebugMinutesKey) private var autoCloseDebugMinutes = false
    #endif
    @Environment(NightEngine.self) private var engine
    #if DEBUG
    @State private var hasSampleData = false
    #endif

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
            Section {
                Button("Add sample data") {
                    engine.addSampleData()
                    hasSampleData = engine.hasSampleData
                }
                .disabled(hasSampleData)
                .cardRow()
                Button("Remove sample data", role: .destructive) {
                    engine.removeSampleData()
                    hasSampleData = engine.hasSampleData
                }
                .disabled(!hasSampleData)
                .cardRow()
            } footer: {
                Text("Five made-up nights around Kazinczy utca, with their places and prices. Removing them leaves your own nights alone.")
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
        .onAppear { hasSampleData = engine.hasSampleData }
        #endif
    }
}
