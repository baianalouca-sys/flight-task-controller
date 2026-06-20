import SwiftUI

struct ArchiveView: View {
    @ObservedObject var vm: TaskViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.04, green: 0.06, blue: 0.04).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Column header
                    HStack {
                        Text("FLT")
                            .frame(width: 44, alignment: .leading)
                        Text("MISSION")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("LANDED")
                            .frame(width: 90, alignment: .trailing)
                    }
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.green.opacity(0.5))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.4))

                    Divider().background(Color.green.opacity(0.3))

                    if vm.archivedTasks.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "airplane.arrival")
                                .font(.system(size: 40))
                                .foregroundColor(.green.opacity(0.3))
                            Text("NO FLIGHTS LOGGED")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.green.opacity(0.4))
                            Text("Completed tasks will appear here")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.green.opacity(0.25))
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(Array(vm.archivedTasks.enumerated()), id: \.element.id) { index, task in
                                    ArchivedFlightRow(task: task, index: index + 1)
                                    Divider().background(Color.green.opacity(0.15))
                                }
                            }
                        }

                        Button(action: { vm.clearArchive() }) {
                            Text("CLEAR FLIGHT LOG")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.red.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.red.opacity(0.08))
                        }
                    }
                }
            }
            .navigationTitle("FLIGHT LOG")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("CLOSE") { dismiss() }
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct ArchivedFlightRow: View {
    let task: FlightTask
    let index: Int
    @State private var expanded = false

    var flightNumber: String {
        "FC\(String(format: "%03d", index))"
    }

    var landedText: String {
        guard let date = task.completedAt else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM HH:mm"
        return formatter.string(from: date)
    }

    var onTimeStatus: String {
        guard let completed = task.completedAt else { return "" }
        return completed <= task.deadline ? "ON TIME" : "DELAYED"
    }

    var onTimeColor: Color {
        guard let completed = task.completedAt else { return .gray }
        return completed <= task.deadline ? .green : .orange
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(flightNumber)
                    .frame(width: 44, alignment: .leading)
                    .foregroundColor(.white.opacity(0.5))

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .foregroundColor(.white.opacity(0.8))
                    Text(onTimeStatus)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(onTimeColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(landedText)
                    .frame(width: 90, alignment: .trailing)
                    .foregroundColor(.green.opacity(0.6))
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation { expanded.toggle() } }

            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text(task.description)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.55))

                    HStack {
                        Label("Deadline: \(task.deadline.formatted(date: .abbreviated, time: .shortened))",
                              systemImage: "flag.checkered")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                        Spacer()
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green.opacity(0.6))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.25))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
