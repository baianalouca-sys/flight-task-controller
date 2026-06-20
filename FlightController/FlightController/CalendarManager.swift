import EventKit
import SwiftUI

class CalendarManager: ObservableObject {
    let store = EKEventStore()
    @Published var pendingEvent: EKEvent? = nil
    @Published var showEditor = false
    @Published var errorMessage: String? = nil

    func requestAndPrepareEvent(for task: FlightTask) {
        errorMessage = nil
        if #available(iOS 17.0, *) {
            store.requestFullAccessToEvents { [weak self] granted, _ in
                DispatchQueue.main.async {
                    if granted { self?.prepareEvent(for: task) }
                    else { self?.errorMessage = "Calendar access denied — enable in Settings > Privacy > Calendars." }
                }
            }
        } else {
            store.requestAccess(to: .event) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    if granted { self?.prepareEvent(for: task) }
                    else { self?.errorMessage = "Calendar access denied — enable in Settings > Privacy > Calendars." }
                }
            }
        }
    }

    private func prepareEvent(for task: FlightTask) {
        let event = EKEvent(eventStore: store)
        event.title = task.title
        event.notes = task.description
        event.startDate = task.deadline
        event.endDate = task.deadline.addingTimeInterval(3600)
        event.addAlarm(EKAlarm(relativeOffset: -3600))
        pendingEvent = event
        showEditor = true
    }
}
