import SwiftUI

enum LandingPhase { case approach, rollout, stopped, done }

struct RadarView: View {
    @ObservedObject var vm: TaskViewModel
    @State private var sweepAngle: Double = 0
    @State private var planeAngles: [UUID: Double] = [:]

    @State private var landingPhase: LandingPhase = .done
    @State private var landingProgress: Double = 0   // 0→1: radar pos → runway threshold
    @State private var rolloutProgress: Double = 0   // 0→1: threshold → stop point
    @State private var landingOpacity: Double = 1.0
    @State private var landingStartPos: CGPoint = .zero
    @State private var landingStartRotation: Double = 90  // start facing right by default
    @State private var landingColor: Color = .green

    let radarColor = Color(red: 0.0, green: 0.8, blue: 0.3)
    let bgColor    = Color(red: 0.04, green: 0.09, blue: 0.06)

    // Runway threshold — left entry point relative to center
    private let thresholdOffset: CGFloat = -44
    // How far the plane rolls along the runway before stopping
    private let rolloutDistance: CGFloat = 80

    var body: some View {
        GeometryReader { geo in
            let size   = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = size / 2 - 16

            ZStack {
                Circle()
                    .fill(bgColor)
                    .frame(width: size - 32, height: size - 32)
                    .position(center)

                // Range rings
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { f in
                    Circle()
                        .stroke(radarColor.opacity(0.2), lineWidth: 1)
                        .frame(width: radius * 2 * CGFloat(f),
                               height: radius * 2 * CGFloat(f))
                        .position(center)
                }

                ringLabel("1d", f: 0.25, center: center, radius: radius)
                ringLabel("3d", f: 0.50, center: center, radius: radius)
                ringLabel("5d", f: 0.75, center: center, radius: radius)
                ringLabel("7d", f: 1.00, center: center, radius: radius)

                // Crosshairs
                Path { p in
                    p.move(to: CGPoint(x: center.x - radius, y: center.y))
                    p.addLine(to: CGPoint(x: center.x + radius, y: center.y))
                    p.move(to: CGPoint(x: center.x, y: center.y - radius))
                    p.addLine(to: CGPoint(x: center.x, y: center.y + radius))
                }
                .stroke(radarColor.opacity(0.12), lineWidth: 1)

                // Radar sweep
                SweepShape(angle: sweepAngle)
                    .fill(AngularGradient(
                        gradient: Gradient(colors: [radarColor.opacity(0.0), radarColor.opacity(0.35)]),
                        center: .center,
                        startAngle: .degrees(sweepAngle - 60),
                        endAngle: .degrees(sweepAngle)
                    ))
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)
                    .clipShape(Circle().scale(CGFloat((size - 32) / size)))

                Path { p in
                    p.move(to: center)
                    p.addLine(to: CGPoint(
                        x: center.x + radius * CGFloat(cos(sweepAngle * .pi / 180)),
                        y: center.y + radius * CGFloat(sin(sweepAngle * .pi / 180))
                    ))
                }
                .stroke(radarColor.opacity(0.8), lineWidth: 1.5)

                RunwayView(radarColor: radarColor)
                    .position(center)

                // Static planes (not the one currently animating)
                ForEach(vm.sortedTasks.filter { $0.id != vm.landingAnimationID }) { task in
                    let angle = planeAngles[task.id] ?? stableAngle(for: task)
                    let dist  = radius * CGFloat(1.0 - task.approachFraction * 0.85)
                    let px    = center.x + dist * CGFloat(cos(angle * .pi / 180))
                    let py    = center.y + dist * CGFloat(sin(angle * .pi / 180))
                    PlaneMarker(task: task,
                                isSelected: vm.selectedTaskID == task.id,
                                approachAngle: angle + 180)
                        .position(x: px, y: py)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                vm.selectedTaskID = vm.selectedTaskID == task.id ? nil : task.id
                            }
                        }
                }

                // Animated landing plane
                if vm.landingAnimationID != nil {
                    let pos = landingPosition(center: center)
                    let rot = landingRotation()
                    Image(systemName: "airplane")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(landingColor)
                        .rotationEffect(.degrees(rot))
                        .shadow(color: landingColor.opacity(0.9), radius: 8)
                        .position(pos)
                        .opacity(landingOpacity)
                }
            }
        }
        .onAppear { startSweep(); assignAngles() }
        .onChange(of: vm.tasks.count) { _ in assignAngles() }
        .onChange(of: vm.landingAnimationID) { id in
            if id != nil { startLandingAnimation() }
        }
    }

    // MARK: - Position & rotation (imperative, outside ViewBuilder)

    private func landingPosition(center: CGPoint) -> CGPoint {
        let thresholdX = center.x + thresholdOffset
        let thresholdY = center.y
        switch landingPhase {
        case .approach:
            return CGPoint(
                x: landingStartPos.x + (thresholdX - landingStartPos.x) * CGFloat(landingProgress),
                y: landingStartPos.y + (thresholdY - landingStartPos.y) * CGFloat(landingProgress)
            )
        case .rollout, .stopped, .done:
            return CGPoint(
                x: thresholdX + CGFloat(rolloutProgress) * rolloutDistance,
                y: thresholdY
            )
        }
    }

    // Smoothly rotates from the plane's original approach angle to 90° (facing right)
    private func landingRotation() -> Double {
        // The plane icon points up by default; +90 makes it face right
        let targetRotation = 90.0
        switch landingPhase {
        case .approach:
            return landingStartRotation + (targetRotation - landingStartRotation) * landingProgress
        case .rollout, .stopped, .done:
            return targetRotation
        }
    }

    // MARK: - Animation sequence

    private func startLandingAnimation() {
        guard let lid = vm.landingAnimationID,
              let task = vm.tasks.first(where: { $0.id == lid }) else { return }

        // Capture plane's current radar position & color
        let screenW   = UIScreen.main.bounds.width
        let radarSize = min(screenW, 300.0)
        let center    = CGPoint(x: screenW / 2, y: radarSize / 2)
        let radius    = radarSize / 2 - 16

        let angle = planeAngles[task.id] ?? stableAngle(for: task)
        let dist  = radius * CGFloat(1.0 - task.approachFraction * 0.85)

        landingStartPos      = CGPoint(
            x: center.x + dist * CGFloat(cos(angle * .pi / 180)),
            y: center.y + dist * CGFloat(sin(angle * .pi / 180))
        )
        // Starting visual rotation matches what PlaneMarker uses: approachAngle + 90
        landingStartRotation = (angle + 180) + 90
        landingColor         = task.urgencyColor

        landingPhase    = .approach
        landingProgress = 0
        rolloutProgress = 0
        landingOpacity  = 1.0

        // Phase 1 — glide to runway threshold, rotating to horizontal (2.2s)
        withAnimation(.easeIn(duration: 2.2)) { landingProgress = 1.0 }

        // Phase 2 — roll along runway (1.0s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            landingPhase = .rollout
            withAnimation(.easeOut(duration: 1.0)) { rolloutProgress = 1.0 }

            // Phase 3 — stop & fade (0.8s after rollout)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                landingPhase = .stopped
                withAnimation(.easeIn(duration: 0.7)) { landingOpacity = 0 }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    landingPhase = .done
                    if let t = vm.tasks.first(where: { $0.id == vm.landingAnimationID }) {
                        vm.completeTask(t)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func ringLabel(_ text: String, f: CGFloat, center: CGPoint, radius: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 8, design: .monospaced))
            .foregroundColor(radarColor.opacity(0.3))
            .position(x: center.x + radius * f - 4, y: center.y - 6)
    }

    private func stableAngle(for task: FlightTask) -> Double {
        Double(abs(task.id.hashValue) % 360)
    }

    private func assignAngles() {
        for task in vm.sortedTasks where planeAngles[task.id] == nil {
            planeAngles[task.id] = stableAngle(for: task)
        }
    }

    private func startSweep() {
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
            sweepAngle = 360
        }
    }
}

// MARK: - Runway

struct RunwayView: View {
    let radarColor: Color
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.07))
                .frame(width: 88, height: 12)
            RoundedRectangle(cornerRadius: 2)
                .stroke(radarColor.opacity(0.55), lineWidth: 1)
                .frame(width: 88, height: 12)
            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { _ in
                    Rectangle()
                        .fill(radarColor.opacity(0.65))
                        .frame(width: 8, height: 2)
                }
            }
            VStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { _ in
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
                 startAngle: .degrees(angle - 60),
                 endAngle: .degrees(angle),
                 clockwise: false)
        p.closeSubpath()
        return p
    }
}

// MARK: - Plane marker

struct PlaneMarker: View {
    let task: FlightTask
    let isSelected: Bool
    let approachAngle: Double

    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(task.urgencyColor.opacity(0.25))
                    .frame(width: 40, height: 40)
            }
            VStack(spacing: 3) {
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
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(task.urgencyColor)
                    .rotationEffect(.degrees(approachAngle + 90))
                    .shadow(color: task.urgencyColor.opacity(0.8),
                            radius: isSelected ? 7 : 3)
            }
        }
    }
}
