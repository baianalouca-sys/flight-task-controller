import SwiftUI

enum LandingPhase { case approach, rollout, done }

struct RadarView: View {
    @ObservedObject var vm: TaskViewModel
    @State private var sweepAngle: Double = 0
    @State private var planeAngles: [UUID: Double] = [:]

    // Landing animation
    @State private var landingPhase: LandingPhase = .done
    @State private var landingProgress: Double = 0   // 0→1: radar pos → left threshold
    @State private var rolloutProgress: Double = 0   // 0→1: threshold → right fade point
    @State private var landingOpacity: Double = 1.0
    @State private var landingStartPos: CGPoint = .zero

    let radarColor = Color(red: 0.0, green: 0.8, blue: 0.3)
    let bgColor = Color(red: 0.04, green: 0.09, blue: 0.06)

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = size / 2 - 16

            ZStack {
                Circle()
                    .fill(bgColor)
                    .frame(width: size - 32, height: size - 32)
                    .position(center)

                // Rings
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { f in
                    Circle()
                        .stroke(radarColor.opacity(0.2), lineWidth: 1)
                        .frame(width: radius * 2 * f, height: radius * 2 * f)
                        .position(center)
                }

                // Ring distance labels
                ForEach([("1d", 0.25), ("3d", 0.5), ("5d", 0.75), ("7d", 1.0)], id: \.0) { label, f in
                    Text(label)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(radarColor.opacity(0.3))
                        .position(x: center.x + radius * f - 4, y: center.y - 6)
                }

                // Crosshairs
                Path { p in
                    p.move(to: CGPoint(x: center.x - radius, y: center.y))
                    p.addLine(to: CGPoint(x: center.x + radius, y: center.y))
                    p.move(to: CGPoint(x: center.x, y: center.y - radius))
                    p.addLine(to: CGPoint(x: center.x, y: center.y + radius))
                }
                .stroke(radarColor.opacity(0.12), lineWidth: 1)

                // Sweep wedge
                SweepShape(angle: sweepAngle)
                    .fill(AngularGradient(
                        gradient: Gradient(colors: [radarColor.opacity(0.0), radarColor.opacity(0.35)]),
                        center: .center,
                        startAngle: .degrees(sweepAngle - 60),
                        endAngle: .degrees(sweepAngle)
                    ))
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)
                    .clipShape(Circle().scale((size - 32) / size))

                // Sweep line
                Path { p in
                    p.move(to: center)
                    p.addLine(to: CGPoint(
                        x: center.x + radius * CGFloat(cos(sweepAngle * .pi / 180)),
                        y: center.y + radius * CGFloat(sin(sweepAngle * .pi / 180))
                    ))
                }
                .stroke(radarColor.opacity(0.8), lineWidth: 1.5)

                // Horizontal runway at center
                RunwayView(radarColor: radarColor)
                    .position(center)

                // Static planes (skip the one currently animating)
                ForEach(vm.sortedTasks.filter { $0.id != vm.landingAnimationID }) { task in
                    let angle = planeAngles[task.id] ?? stableAngle(for: task)
                    let dist = radius * (1.0 - task.approachFraction * 0.85)
                    let x = center.x + dist * CGFloat(cos(angle * .pi / 180))
                    let y = center.y + dist * CGFloat(sin(angle * .pi / 180))
                    PlaneMarker(task: task, isSelected: vm.selectedTaskID == task.id,
                                approachAngle: angle + 180) // face toward center
                        .position(x: x, y: y)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                vm.selectedTaskID = vm.selectedTaskID == task.id ? nil : task.id
                            }
                        }
                }

                // Animated landing plane
                if let lid = vm.landingAnimationID,
                   let task = vm.tasks.first(where: { $0.id == lid }) {
                    landingPlaneView(task: task, center: center, radius: radius)
                }
            }
        }
        .onAppear { startSweep(); assignAngles() }
        .onChange(of: vm.tasks.count) { _ in assignAngles() }
        .onChange(of: vm.landingAnimationID) { id in
            if id != nil { startLandingAnimation() }
        }
    }

    // MARK: - Landing plane view

    @ViewBuilder
    private func landingPlaneView(task: FlightTask, center: CGPoint, radius: CGFloat) -> some View {
        // Threshold = left entry to runway
        let thresholdX = center.x - 44
        let thresholdY = center.y

        let currentX: CGFloat
        let currentY: CGFloat

        switch landingPhase {
        case .approach:
            // Lerp from saved start pos to threshold
            currentX = landingStartPos.x + (thresholdX - landingStartPos.x) * landingProgress
            currentY = landingStartPos.y + (thresholdY - landingStartPos.y) * landingProgress
        case .rollout, .done:
            // Roll along runway rightward past center
            currentX = thresholdX + rolloutProgress * 120
            currentY = thresholdY
        }

        Image(systemName: "airplane")
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.yellow)
            .rotationEffect(.degrees(90)) // pointing right
            .shadow(color: Color.yellow.opacity(0.9), radius: 8)
            .position(x: currentX, y: currentY)
            .opacity(landingOpacity)
    }

    // MARK: - Animation sequence

    private func startLandingAnimation() {
        guard let lid = vm.landingAnimationID,
              let task = vm.tasks.first(where: { $0.id == lid }) else { return }

        // Compute screen position from angle + approachFraction.
        // We estimate the radar radius from the screen width (matches GeometryReader logic).
        let screenW = UIScreen.main.bounds.width
        let radarSize = min(screenW, 300.0)   // matches .frame(height: 300) in ContentView
        let center = CGPoint(x: screenW / 2, y: radarSize / 2)
        let radius = radarSize / 2 - 16

        let angle = planeAngles[task.id] ?? stableAngle(for: task)
        let dist = radius * (1.0 - task.approachFraction * 0.85)
        landingStartPos = CGPoint(
            x: center.x + dist * CGFloat(cos(angle * .pi / 180)),
            y: center.y + dist * CGFloat(sin(angle * .pi / 180))
        )

        landingPhase = .approach
        landingProgress = 0
        rolloutProgress = 0
        landingOpacity = 1.0

        // Phase 1: glide to runway threshold (2s)
        withAnimation(.easeIn(duration: 2.0)) {
            landingProgress = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            landingPhase = .rollout
            // Phase 2: roll along runway rightward + fade
            withAnimation(.linear(duration: 1.2)) {
                rolloutProgress = 1.0
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.4)) {
                landingOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                landingPhase = .done
                if let t = vm.tasks.first(where: { $0.id == vm.landingAnimationID }) {
                    vm.completeTask(t)
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

// MARK: - Runway (horizontal)

struct RunwayView: View {
    let radarColor: Color

    var body: some View {
        ZStack {
            // Surface
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.07))
                .frame(width: 88, height: 12)

            // Edges
            RoundedRectangle(cornerRadius: 2)
                .stroke(radarColor.opacity(0.55), lineWidth: 1)
                .frame(width: 88, height: 12)

            // Centre dashes
            HStack(spacing: 6) {
                ForEach(0..<4) { _ in
                    Rectangle()
                        .fill(radarColor.opacity(0.65))
                        .frame(width: 8, height: 2)
                }
            }

            // Threshold bars (left end)
            VStack(spacing: 2) {
                ForEach(0..<3) { _ in
                    Rectangle()
                        .fill(radarColor.opacity(0.5))
                        .frame(width: 2, height: 4)
                }
            }
            .offset(x: -40)

            Text("RWY")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(radarColor.opacity(0.6))
                .offset(y: 14)
        }
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
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        p.move(to: c)
        p.addArc(center: c, radius: r,
                 startAngle: .degrees(angle - 60), endAngle: .degrees(angle), clockwise: false)
        p.closeSubpath()
        return p
    }
}

// MARK: - Plane marker (title always visible)

struct PlaneMarker: View {
    let task: FlightTask
    let isSelected: Bool
    let approachAngle: Double  // direction plane faces (toward center)

    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(task.urgencyColor.opacity(0.25))
                    .frame(width: 40, height: 40)
            }

            VStack(spacing: 3) {
                // Title always visible
                Text(task.title)
                    .font(.system(size: isSelected ? 11 : 9,
                                  weight: isSelected ? .bold : .semibold,
                                  design: .monospaced))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(isSelected ? 0.9 : 0.55))
                    .cornerRadius(3)
                    .lineLimit(1)
                    .fixedSize()

                Image(systemName: "airplane")
                    .font(.system(size: task.isLanding ? 20 : 15, weight: .bold))
                    .foregroundColor(task.urgencyColor)
                    .rotationEffect(.degrees(approachAngle + 90))
                    .shadow(color: task.urgencyColor.opacity(0.8), radius: isSelected ? 7 : 3)
                    .animation(.easeInOut(duration: 2.0), value: task.urgencyColor)
            }
        }
    }
}
