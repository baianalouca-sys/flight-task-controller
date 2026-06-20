import SwiftUI

struct ContentView: View {
    @StateObject private var vm = TaskViewModel()
    @State private var showAddTask = false
    @State private var showArchive = false

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.06, blue: 0.04).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FLIGHT CONTROL")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundColor(.green)
                        Text("ATC TASK MANAGEMENT")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.green.opacity(0.5))
                    }

                    Spacer()

                    // Archive button
                    Button {
                        showArchive = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 12))
                            if !vm.archivedTasks.isEmpty {
                                Text("\(vm.archivedTasks.count)")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                            }
                        }
                        .foregroundColor(.green.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                    }

                    HStack(spacing: 6) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text("\(vm.sortedTasks.count)/\(vm.maxTasks)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.green.opacity(0.7))
                    }
                    .padding(.leading, 8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.4))

                // Radar
                RadarView(vm: vm)
                    .frame(height: 300)
                    .padding(.vertical, 8)

                // Legend
                HStack(spacing: 16) {
                    legendItem(color: .green, label: ">7d")
                    legendItem(color: .yellow, label: "3-7d")
                    legendItem(color: .orange, label: "1-3d")
                    legendItem(color: .red, label: "<24h")
                    Spacer()
                    if let landing = vm.landingTask {
                        HStack(spacing: 4) {
                            Image(systemName: vm.landingAnimationID != nil ? "airplane.arrival" : "airplane")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                            Text(landing.title)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.yellow)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                Divider().background(Color.green.opacity(0.3))

                // Flight list
                FlightListView(vm: vm)

                // Add / full indicator
                if vm.canAddTask {
                    Button(action: { showAddTask = true }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("FILE NEW FLIGHT PLAN")
                        }
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.green)
                    }
                } else {
                    Text("AIRSPACE FULL — LAND A FLIGHT TO ADD MORE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.red.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.1))
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showAddTask) {
            AddTaskView(vm: vm)
        }
        .sheet(isPresented: $showArchive) {
            ArchiveView(vm: vm)
        }
        .alert("LANDING COMPLETE",
               isPresented: Binding(
                   get: { vm.landingCompletedTitle != nil },
                   set: { if !$0 { vm.landingCompletedTitle = nil } }
               )) {
            Button("OK") { vm.landingCompletedTitle = nil }
        } message: {
            if let title = vm.landingCompletedTitle {
                Text("'\(title)' has landed successfully.\nMission accomplished.")
            }
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "airplane")
                .font(.system(size: 9))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(color.opacity(0.8))
        }
    }
}
