import Foundation

struct WeightEntry: Identifiable, Codable {
    let id = UUID()
    let date: Date
    let weight: Double
    var synced: Bool = false
}
