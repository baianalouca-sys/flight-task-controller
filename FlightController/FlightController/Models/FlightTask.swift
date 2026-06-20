import Foundation
import SwiftUI

struct FlightTask: Identifiable, Codable {
    var id = UUID()
    var title: String
    var description: String
    var deadline: Date
    var isLanding: Bool = false
    var isCompleted: Bool = false
    var completedAt: Date? = nil

    var hoursUntilDeadline: Double {
        deadline.timeIntervalSinceNow / 3600
    }

    var urgencyColor: Color {
        let hours = hoursUntilDeadline
        if hours < 0 { return .red }
        if hours < 24 { return .red }
        if hours < 72 { return Color.orange }
        if hours < 168 { return Color.yellow }
        return Color.green
    }

    // 0.0 = just departed (far from deadline), 1.0 = at threshold (overdue)
    var approachFraction: Double {
        let maxHours: Double = 168 // 7 days = outer ring
        let hours = max(0, hoursUntilDeadline)
        let clamped = min(hours, maxHours)
        return 1.0 - (clamped / maxHours)
    }
}
