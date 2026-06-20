import Foundation
import Combine

class TaskViewModel: ObservableObject {
    @Published var tasks: [FlightTask] = []
    @Published var selectedTaskID: UUID? = nil

    let maxTasks = 5

    var canAddTask: Bool { tasks.count < maxTasks }

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

    func completeTask(_ task: FlightTask) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].isCompleted = true
        tasks[idx].isLanding = false
    }

    func setLanding(_ task: FlightTask) {
        for i in tasks.indices {
            tasks[i].isLanding = false
        }
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx].isLanding = true
        }
    }

    func deleteTask(_ task: FlightTask) {
        tasks.removeAll { $0.id == task.id }
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
