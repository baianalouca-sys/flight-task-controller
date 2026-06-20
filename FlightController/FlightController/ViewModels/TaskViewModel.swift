import Foundation
import Combine

class TaskViewModel: ObservableObject {
    @Published var tasks: [FlightTask] = []
    @Published var archivedTasks: [FlightTask] = []
    @Published var selectedTaskID: UUID? = nil
    @Published var landingAnimationID: UUID? = nil  // triggers radar landing sequence

    let maxTasks = 5

    var canAddTask: Bool { tasks.filter { !$0.isCompleted }.count < maxTasks }

    var sortedTasks: [FlightTask] {
        tasks.filter { !$0.isCompleted }
             .sorted { $0.deadline < $1.deadline }
    }

    var landingTask: FlightTask? {
        tasks.first { $0.isLanding && !$0.isCompleted }
    }

    init() {
        loadSampleTasks()
    }

    func addTask(_ task: FlightTask) {
        guard canAddTask else { return }
        tasks.append(task)
    }

    // Called by radar after animation completes
    func completeTask(_ task: FlightTask) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        var completed = tasks[idx]
        completed.isCompleted = true
        completed.isLanding = false
        completed.completedAt = Date()
        tasks.remove(at: idx)
        archivedTasks.insert(completed, at: 0)
        landingAnimationID = nil
        selectedTaskID = nil
    }

    // Called from UI — triggers the radar animation, which then calls completeTask
    func initiateLanding(_ task: FlightTask) {
        landingAnimationID = task.id
    }

    func setLanding(_ task: FlightTask) {
        guard landingTask == nil || landingTask?.id == task.id else { return }
        for i in tasks.indices { tasks[i].isLanding = false }
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx].isLanding = true
        }
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
            FlightTask(title: "Q2 Report", description: "Compile and submit Q2 financial report", deadline: now.addingTimeInterval(3600 * 4)),
            FlightTask(title: "Design Review", description: "Review new app designs with team", deadline: now.addingTimeInterval(3600 * 28)),
            FlightTask(title: "Client Call", description: "Weekly sync with Acme Corp", deadline: now.addingTimeInterval(3600 * 96)),
            FlightTask(title: "Update Docs", description: "Update API documentation", deadline: now.addingTimeInterval(3600 * 130)),
            FlightTask(title: "Code Audit", description: "Security audit of auth module", deadline: now.addingTimeInterval(3600 * 160)),
        ]
    }
}
