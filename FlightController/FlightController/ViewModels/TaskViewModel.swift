import Foundation
import Combine

class TaskViewModel: ObservableObject {
    @Published var tasks: [FlightTask] = []
    @Published var archivedTasks: [FlightTask] = []
    @Published var selectedTaskID: UUID? = nil
    @Published var landingAnimationID: UUID? = nil
    @Published var landingCompletedTitle: String? = nil  // triggers completion popup

    let maxTasks = 15

    var canAddTask: Bool { tasks.filter { !$0.isCompleted }.count < maxTasks }

    var sortedTasks: [FlightTask] {
        tasks.filter { !$0.isCompleted }
             .sorted { $0.deadline < $1.deadline }
    }

    var landingTask: FlightTask? {
        tasks.first { $0.isLanding && !$0.isCompleted }
    }

    init() { loadSampleTasks() }

    func addTask(_ task: FlightTask) {
        guard canAddTask else { return }
        tasks.append(task)
    }

    // Single entry point — sets landing flag AND kicks off radar animation
    func initiateLanding(_ task: FlightTask) {
        guard landingAnimationID == nil else { return }
        for i in tasks.indices { tasks[i].isLanding = false }
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx].isLanding = true
        }
        landingAnimationID = task.id
        selectedTaskID = nil
    }

    // Called by RadarView after animation finishes
    func completeTask(_ task: FlightTask) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        var completed = tasks[idx]
        completed.isCompleted = true
        completed.isLanding = false
        completed.completedAt = Date()
        tasks.remove(at: idx)
        archivedTasks.insert(completed, at: 0)
        landingAnimationID = nil
        landingCompletedTitle = completed.title
    }

    func deleteTask(_ task: FlightTask) {
        tasks.removeAll { $0.id == task.id }
    }

    func clearArchive() {
        archivedTasks.removeAll()
    }

    private func loadSampleTasks() {
        let now = Date()
        tasks = [
            FlightTask(title: "Q2 Report",     description: "Compile and submit Q2 financial report", deadline: now.addingTimeInterval(3600 * 4)),
            FlightTask(title: "Design Review",  description: "Review new app designs with team",       deadline: now.addingTimeInterval(3600 * 28)),
            FlightTask(title: "Client Call",    description: "Weekly sync with Acme Corp",             deadline: now.addingTimeInterval(3600 * 96)),
            FlightTask(title: "Update Docs",    description: "Update API documentation",               deadline: now.addingTimeInterval(3600 * 130)),
            FlightTask(title: "Code Audit",     description: "Security audit of auth module",          deadline: now.addingTimeInterval(3600 * 160)),
        ]
    }
}
