import SwiftUI

// Landing animation phases
enum LandingPhase {
    case approach   // plane drifts toward center
    case rollout    // plane rolls along runway and fades
    case done
}

struct RadarView: View {
    @ObservedObject var vm: TaskViewModel
    @State private var sweepAngle: Double = 0
    @State private var planeAngles: [UUID: Double] = [:]

    // Landing animation state
    @State private var landingPhase: LandingPhase = .done
    @State private var landingProgress: Double = 0   // 0→1 during approach
    @State private var rolloutProgress: Double = 0   // 0→1 during rollout
    @State private var landingOpacity: Double = 1.0

    let radarColor = Color(red: 0.0, green: 0.8, blue: 0.3)
    let bgColor = Color(red: 0.04, green: 0.09, blue: 0.06)
    let runwayAngle: Double = -90  // runway points upward

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

                // Radar rings with distance labels
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { fraction in
                    Circle()
                        .stroke(radarColor.opacity(0.2), lineWidth: 1)
                        .frame(width: radius * 2 * fraction, height: radius * 2 * fraction)
                        .position(center)
                }

                // Ring labels
                ringLabels(center: center, radius: radius)

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

                // Runway at center
                RunwayView(radarColor: radarColor, angle: runwayAngle)
                    .position(center)

                // Static planes (not landing)
                ForEach(vm.sortedTasks.filter { $0.id != vm.landingAnimationID }) { task in
                    staticPlane(task: task, center: center, radius: radius)
                }

                // Animated landing plane
                if let landingID = vm.landingAnimationID,
                   let task = vm.tasks.first(where: { $0.id == landingID }) {
                    animatedLandingPlane(task: task, center: center, radius: radius)
                }
            }
        }
        .onAppear {
            startSweep()
            assignAngles()
        }
        .onChange(of: vm.tasks.count) { _ in assignAngles() }
        .onChange(of: vm.landingAnimationID) { id in
            if id != nil { startLandingAnimation() }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func staticPlane(task: FlightTask, center: CGPoint, radius: CGFloat) -> some View {
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

    @ViewBuilder
    private func animatedLandingPlane(task: FlightTask, center: CGPoint, radius: CGFloat) -> some View {
        let angle = planeAngles[task.id] ?? stableAngle(for: task)
        let startDistance = radius * (1.0 - task.approachFraction * 0.85)

        // Approach: lerp from start position to center
        let currentDistance = startDistance * (1.0 - landingProgress)
        let planeX = center.x + CGFloat(currentDistance * cos(angle * .pi / 180))
        let planeY = center.y + CGFloat(currentDistance * sin(angle * .pi / 180))

        // Rollout: after reaching center, move along runway direction
        let runwayRad = runwayAngle * .pi / 180
        let runwayLength: CGFloat = 60
        let rollX = center.x + CGFloat(rolloutProgress) * runwayLength * CGFloat(cos(runwayRad))
        let rollY = center.y + CGFloat(rolloutProgress) * runwayLength * CGFloat(sin(runwayRad))

        let finalX = landingPhase == .rollout ? rollX : planeX
        let finalY = landingPhase == .rollout ? rollY : planeY
        let finalRotation = landingPhase == .rollout ? runwayAngle + 90 : angle + 90

        Image(systemName: "airplane")
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.yellow)
            .rotationEffect(.degrees(finalRotation))
            .shadow(color: Color.yellow.opacity(0.9), radius: 8)
            .position(x: finalX, y: finalY)
            .opacity(landingOpacity)
    }

    @ViewBuilder
    private func ringLabels(center: CGPoint, radius: CGFloat) -> some View {
        let labels: [(Double, String)] = [(0.25, "1d"), (0.5, "3d"), (0.75, "5d"), (1.0, "7d")]
        ForEach(labels, id: \.1) { fraction, label in
            Text(label)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(radarColor.opacity(0.35))
                .position(
                    x: center.x + radius * fraction - 4,
                    y: center.y - 6
                )
        }
    }

    // MARK: - Landing animation sequence

    private func startLandingAnimation() {
        landingPhase = .approach
        landingProgress = 0
        rolloutProgress = 0
        landingOpacity = 1.0

        // Phase 1: approach to center (2s)
        withAnimation(.easeIn(duration: 2.0)) {
            landingProgress = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            landingPhase = .rollout
            // Phase 2: roll down runway (1s)
            withAnimation(.linear(duration: 1.0)) {
                rolloutProgress = 1.0
            }
            // Phase 3: fade out during rollout
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                landingOpacity = 0
            }
            // Complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                landingPhase = .done
                if let id = vm.landingAnimationID,
                   let task = vm.tasks.first(where: { $0.id == id }) {
                    vm.completeTask(task)
                }
            }
        }
    }

    // MARK: - Helpers

    private func stableAngle(for task: FlightTask) -> Double {
        Double(abs(task.id.hashValue) % 360)
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

// MARK: - Runway graphic

struct RunwayView: View {
    let radarColor: Color
    let angle: Double

    var body: some View {
        ZStack {
            // Runway surface
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.08))
                .frame(width: 12, height: 60)

            // Runway edges
            RoundedRectangle(cornerRadius: 2)
                .stroke(radarColor.opacity(0.6), lineWidth: 1)
                .frame(width: 12, height: 60)

            // Center dashes
            VStack(spacing: 5) {
                ForEach(0..<4) { _ in
                    Rectangle()
                        .fill(radarColor.opacity(0.7))
                        .frame(width: 2, height: 6)
                }
            }

            // Threshold markings
            HStack(spacing: 4) {
                ForEach(0..<3) { _ in
                    Rectangle()
                        .fill(radarColor.opacity(0.5))
                        .frame(width: 2, height: 4)
                }
            }
            .offset(y: 26)

            // RWY label
            Text("RWY")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(radarColor.opacity(0.7))
                .offset(y: 40)
        }
        .rotationEffect(.degrees(angle))
    }
}

// MARK: - Sweep shape

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

// MARK: - Plane marker

struct PlaneMarker: View {
    let task: FlightTask
    let isSelected: Bool
    let rotation: Double

    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(task.urgencyColor.opacity(0.25))
                    .frame(width: 36, height: 36)
            }

            Image(systemName: "airplane")
                .font(.system(size: task.isLanding ? 20 : 16, weight: .bold))
                .foregroundColor(task.urgencyColor)
                .rotationEffect(.degrees(rotation))
                .shadow(color: task.urgencyColor.opacity(0.8), radius: isSelected ? 6 : 3)

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
