import EventKit
import SwiftUI

class CalendarManager: ObservableObject {
    private let store = EKEventStore()
    @Published var permissionStatus: EKAuthorizationStatus = .notDetermined
    @Published var lastResult: CalendarResult? = nil

    enum CalendarResult: Equatable {
        case success(String)
        case failure(String)
    }

    func requestAccessAndAddEvent(for task: FlightTask) {
        if #available(iOS 17.0, *) {
            store.requestFullAccessToEvents { [weak self] granted, error in
                DispatchQueue.main.async {
                    if granted {
                        self?.addEvent(for: task)
                    } else {
                        self?.lastResult = .failure("Calendar access denied. Enable in Settings > Privacy > Calendars.")
                    }
                }
            }
        } else {
            store.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    if granted {
                        self?.addEvent(for: task)
                    } else {
                        self?.lastResult = .failure("Calendar access denied. Enable in Settings > Privacy > Calendars.")
                    }
                }
            }
        }
    }

    private func addEvent(for task: FlightTask) {
        let event = EKEvent(eventStore: store)
        event.title = "✈ \(task.title)"
        event.notes = task.description
        event.startDate = task.deadline
        event.endDate = task.deadline.addingTimeInterval(3600)
        event.calendar = store.defaultCalendarForNewEvents

        // 1 hour warning alarm
        let alarm = EKAlarm(relativeOffset: -3600)
        event.addAlarm(alarm)

        do {
            try store.save(event, span: .thisEvent)
            lastResult = .success("'\(task.title)' added to Calendar with a 1h reminder.")
        } catch {
            lastResult = .failure("Could not save to Calendar: \(error.localizedDescription)")
        }
    }
}
