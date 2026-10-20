import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.autoCloseHoursKey) private var autoCloseHours = AppSettings.defaultAutoCloseHours
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
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }
}
