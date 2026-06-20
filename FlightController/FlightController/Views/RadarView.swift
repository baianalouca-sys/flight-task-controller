import SwiftUI

struct RadarView: View {
    @ObservedObject var vm: TaskViewModel
    @State private var sweepAngle: Double = 0
    @State private var planeAngles: [UUID: Double] = [:]

    let radarColor = Color(red: 0.0, green: 0.8, blue: 0.3)
    let bgColor = Color(red: 0.04, green: 0.09, blue: 0.06)

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = size / 2 - 16

            ZStack {
                // Background
                Circle()
                    .fill(bgColor)
                    .frame(width: size - 32, height: size - 32)
                    .position(center)

                // Radar rings
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { fraction in
                    Circle()
                        .stroke(radarColor.opacity(0.2), lineWidth: 1)
                        .frame(width: radius * 2 * fraction, height: radius * 2 * fraction)
                        .position(center)
                }

                // Crosshairs
                Path { p in
                    p.move(to: CGPoint(x: center.x - radius, y: center.y))
                    p.addLine(to: CGPoint(x: center.x + radius, y: center.y))
                    p.move(to: CGPoint(x: center.x, y: center.y - radius))
                    p.addLine(to: CGPoint(x: center.x, y: center.y + radius))
                }
                .stroke(radarColor.opacity(0.15), lineWidth: 1)

                // Sweep
                SweepShape(angle: sweepAngle)
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: [radarColor.opacity(0.0), radarColor.opacity(0.35)]),
                            center: .center,
                            startAngle: .degrees(sweepAngle - 60),
                            endAngle: .degrees(sweepAngle)
                        )
                    )
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)
                    .clipShape(Circle().scale((size - 32) / size))

                // Sweep leading edge
                Path { p in
                    p.move(to: center)
                    let rad = Double(radius)
                    let endX = center.x + CGFloat(rad * cos(sweepAngle * .pi / 180))
                    let endY = center.y + CGFloat(rad * sin(sweepAngle * .pi / 180))
                    p.addLine(to: CGPoint(x: endX, y: endY))
                }
                .stroke(radarColor.opacity(0.8), lineWidth: 1.5)

                // Planes
                ForEach(vm.sortedTasks) { task in
                    let angle = planeAngles[task.id] ?? stableAngle(for: task)
                    let distance = radius * (1.0 - task.approachFraction * 0.85)
                    let x = center.x + CGFloat(distance * cos(angle * .pi / 180))
                    let y = center.y + CGFloat(distance * sin(angle * .pi / 180))

                    PlaneMarker(
                        task: task,
                        isSelected: vm.selectedTaskID == task.id,
                        rotation: angle + 90
                    )
                    .position(x: x, y: y)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            vm.selectedTaskID = vm.selectedTaskID == task.id ? nil : task.id
                        }
                    }
                }

                // Center dot (runway)
                ZStack {
                    Circle()
                        .fill(radarColor.opacity(0.6))
                        .frame(width: 10, height: 10)
                    Text("RWY")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(radarColor)
                        .offset(y: 12)
                }
                .position(center)
            }
        }
        .onAppear {
            startSweep()
            assignAngles()
        }
        .onChange(of: vm.tasks.count) { _ in assignAngles() }
    }

    private func stableAngle(for task: FlightTask) -> Double {
        // Generate a stable angle from the task ID
        let hash = abs(task.id.hashValue)
        return Double(hash % 360)
    }

    private func assignAngles() {
        for task in vm.sortedTasks {
            if planeAngles[task.id] == nil {
                planeAngles[task.id] = stableAngle(for: task)
            }
        }
    }

    private func startSweep() {
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
            sweepAngle = 360
        }
    }
}

struct SweepShape: Shape {
    var angle: Double

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(angle - 60),
            endAngle: .degrees(angle),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

struct PlaneMarker: View {
    let task: FlightTask
    let isSelected: Bool
    let rotation: Double

    var body: some View {
        ZStack {
            // Glow when selected
            if isSelected {
                Circle()
                    .fill(task.urgencyColor.opacity(0.25))
                    .frame(width: 36, height: 36)
            }

            // Plane icon
            Image(systemName: "airplane")
                .font(.system(size: task.isLanding ? 20 : 16, weight: .bold))
                .foregroundColor(task.urgencyColor)
                .rotationEffect(.degrees(rotation))
                .shadow(color: task.urgencyColor.opacity(0.8), radius: isSelected ? 6 : 3)

            // Title label on tap
            if isSelected {
                Text(task.title)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(4)
                    .offset(y: -26)
            }
        }
    }
}
