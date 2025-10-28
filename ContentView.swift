import SwiftUI

struct ContentView: View {

    @StateObject var syncManager = WeightSyncManager()

    var body: some View {
        NavigationView {
            List(syncManager.weightHistory) { entry in
                HStack {
                    Text(String(format: "%.2f kg", entry.weight))
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(entry.date, style: .date)
                        Text(entry.date, style: .time)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
            .overlay {
                if syncManager.isScanning {
                    ProgressView("Skanowanie wagi…")
                        .padding()
                }
            }
            .navigationTitle("Historia")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        syncManager.startSync()
                    } label: {
                        if syncManager.isScanning {
                            ProgressView()
                        } else {
                            Text("Sync")
                        }
                    }
                    .disabled(syncManager.isScanning)
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
