import SwiftUI

struct FlightListView: View {
    @ObservedObject var vm: TaskViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("FLT")
                    .frame(width: 40, alignment: .leading)
                Text("DESTINATION")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("ETA")
                    .frame(width: 72, alignment: .trailing)
                Text("STATUS")
                    .frame(width: 64, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(.green.opacity(0.6))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.5))

            Divider().background(Color.green.opacity(0.3))

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(vm.sortedTasks.enumerated()), id: \.element.id) { index, task in
                        FlightRow(task: task, index: index + 1, vm: vm)
                        Divider().background(Color.green.opacity(0.15))
                    }
                }
            }
        }
        .background(Color(red: 0.04, green: 0.06, blue: 0.04))
    }
}

struct FlightRow: View {
    let task: FlightTask
    let index: Int
    @ObservedObject var vm: TaskViewModel
    @State private var showDetail = false

    var flightNumber: String { "FC\(String(format: "%03d", index))" }

    var etaText: String {
        let hours = task.hoursUntilDeadline
        if hours < 0 { return "OVERDUE" }
        if hours < 24 { return "\(Int(hours))h \(Int(hours.truncatingRemainder(dividingBy: 1) * 60))m" }
        let days = Int(hours / 24)
        let remHours = Int(hours.truncatingRemainder(dividingBy: 24))
        return "\(days)d \(remHours)h"
    }

    var statusText: String {
        if task.isLanding { return "LANDING" }
        if task.hoursUntilDeadline < 0 { return "OVERDUE" }
        if task.hoursUntilDeadline < 24 { return "FINAL" }
        if task.hoursUntilDeadline < 72 { return "APPROACH" }
        return "EN ROUTE"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(flightNumber)
                    .frame(width: 40, alignment: .leading)
                    .foregroundColor(.white.opacity(0.9))

                VStack(alignment: .leading, spacing: 1) {
                    Text(task.title)
                        .foregroundColor(.white)
                    if task.isLanding {
                        Text("ON RUNWAY")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.yellow)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(etaText)
                    .frame(width: 72, alignment: .trailing)
                    .foregroundColor(task.urgencyColor)

                Text(statusText)
                    .frame(width: 64, alignment: .trailing)
                    .foregroundColor(task.urgencyColor.opacity(0.8))
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                task.isLanding
                    ? Color.yellow.opacity(0.08)
                    : (vm.selectedTaskID == task.id ? task.urgencyColor.opacity(0.08) : Color.clear)
            )
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDetail.toggle()
                    vm.selectedTaskID = showDetail ? task.id : nil
                }
            }

            if showDetail {
                FlightDetailPanel(task: task, vm: vm)
            }
        }
    }
}

struct FlightDetailPanel: View {
    let task: FlightTask
    @ObservedObject var vm: TaskViewModel
    @StateObject private var cal = CalendarManager()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(task.description)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.75))

            // Deadline + calendar button
            HStack {
                Label(task.deadline.formatted(date: .abbreviated, time: .shortened),
                      systemImage: "clock")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(task.urgencyColor)

                Spacer()

                Button {
                    cal.requestAndPrepareEvent(for: task)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.plus")
                        Text("ADD TO CAL")
                    }
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.6))
                    .cornerRadius(4)
                }
            }

            // Inline error if calendar access denied
            if let err = cal.errorMessage {
                Text(err)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.orange)
                    .transition(.opacity)
            }

            // Action buttons
            HStack(spacing: 8) {
                if !task.isLanding {
                    Button("CLEAR FOR LANDING") {
                        vm.setLanding(task)
                    }
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(vm.landingTask == nil ? task.urgencyColor : Color.gray)
                    .cornerRadius(4)
                    .disabled(vm.landingTask != nil)
                } else {
                    Button("LANDED ✓  INITIATE") {
                        vm.initiateLanding(task)
                    }
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.yellow)
                    .cornerRadius(4)
                    .disabled(vm.landingAnimationID != nil)
                }

                Spacer()

                Button {
                    vm.deleteTask(task)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.3))
        .transition(.opacity.combined(with: .move(edge: .top)))
        // Native iOS Calendar editor — user picks calendar, edits, saves
        .sheet(isPresented: $cal.showEditor) {
            if let event = cal.pendingEvent {
                CalendarEventEditor(store: cal.store, event: event, isPresented: $cal.showEditor)
            }
        }
    }
}
