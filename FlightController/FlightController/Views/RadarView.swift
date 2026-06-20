import SwiftUI

enum LandingPhase { case approach, rollout, stopped, done }

struct RadarView: View {
    @ObservedObject var vm: TaskViewModel
    @State private var sweepAngle: Double = 0
    @State private var planeAngles: [UUID: Double] = [:]

    // Landing animation state
    @State private var landingPhase: LandingPhase = .done
    @State private var landingProgress: Double = 0    // 0→1 along Bezier (approach)
    @State private var rolloutProgress: Double = 0    // 0→1 along runway
    @State private var landingOpacity: Double = 1.0
    @State private var landingColor: Color = .green

    // Bezier control points stored when animation starts
    @State private var bezierP0: CGPoint = .zero
    @State private var bezierP1: CGPoint = .zero
    @State private var bezierP2: CGPoint = .zero
    @State private var bezierP3: CGPoint = .zero  // runway threshold

    let radarColor = Color(red: 0.0, green: 0.8, blue: 0.3)
    let bgColor    = Color(red: 0.04, green: 0.09, blue: 0.06)

    // Runway threshold offset from radar center (left end of runway)
    private let thresholdOffset: CGFloat = -44
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

                // Static planes
                ForEach(vm.sortedTasks.filter { $0.id != vm.landingAnimationID }) { task in
                    let angle = planeAngles[task.id] ?? stableAngle(for: task)
                    let dist  = radius * CGFloat(1.0 - task.approachFraction * 0.85)
                    let px    = center.x + dist * CGFloat(cos(angle * .pi / 180))
                    let py    = center.y + dist * CGFloat(sin(angle * .pi / 180))
                    PlaneMarker(task: task,
                                isSelected: vm.selectedTaskID == task.id,
                                headingDegrees: headingTowardCenter(angle: angle))
                        .position(x: px, y: py)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                vm.selectedTaskID = vm.selectedTaskID == task.id ? nil : task.id
                            }
                        }
                }

                // Animated landing plane — position & heading from Bezier
                if vm.landingAnimationID != nil {
                    let pos     = currentLandingPosition()
                    let heading = currentLandingHeading()
                    Image(systemName: "airplane")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(landingColor)
                        .rotationEffect(.degrees(heading))
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

    // MARK: - Bezier helpers

    /// Position along cubic Bezier at parameter t (0–1)
    private func bezierPoint(t: Double) -> CGPoint {
        let t  = CGFloat(t)
        let mt = 1 - t
        return CGPoint(
            x: mt*mt*mt*bezierP0.x + 3*mt*mt*t*bezierP1.x + 3*mt*t*t*bezierP2.x + t*t*t*bezierP3.x,
            y: mt*mt*mt*bezierP0.y + 3*mt*mt*t*bezierP1.y + 3*mt*t*t*bezierP2.y + t*t*t*bezierP3.y
        )
    }

    /// First derivative (tangent) of cubic Bezier at parameter t — gives direction of travel
    private func bezierTangent(t: Double) -> CGPoint {
        let t  = CGFloat(t)
        let mt = 1 - t
        return CGPoint(
            x: 3*mt*mt*(bezierP1.x-bezierP0.x) + 6*mt*t*(bezierP2.x-bezierP1.x) + 3*t*t*(bezierP3.x-bezierP2.x),
            y: 3*mt*mt*(bezierP1.y-bezierP0.y) + 6*mt*t*(bezierP2.y-bezierP1.y) + 3*t*t*(bezierP3.y-bezierP2.y)
        )
    }

    // MARK: - Current position & heading (called from body, outside @ViewBuilder)

    private func currentLandingPosition() -> CGPoint {
        switch landingPhase {
        case .approach:
            return bezierPoint(t: landingProgress)
        case .rollout, .stopped, .done:
            return CGPoint(x: bezierP3.x + CGFloat(rolloutProgress) * rolloutDistance,
                           y: bezierP3.y)
        }
    }

    /// Heading in degrees — nose always follows the direction of travel.
    /// The SF Symbol "airplane" points UP (north); rotating +90° makes it point right.
    /// So heading = atan2(dy, dx) converted to degrees + 90.
    private func currentLandingHeading() -> Double {
        switch landingPhase {
        case .approach:
            let tan = bezierTangent(t: landingProgress)
            // Guard against zero-length tangent at t=0
            guard abs(tan.x) > 0.001 || abs(tan.y) > 0.001 else { return 90 }
            return atan2(Double(tan.y), Double(tan.x)) * 180 / .pi + 90
        case .rollout, .stopped, .done:
            return 90  // horizontal, nose right
        }
    }

    // MARK: - Animation sequence

    private func startLandingAnimation() {
        guard let lid = vm.landingAnimationID,
              let task = vm.tasks.first(where: { $0.id == lid }) else { return }

        // Mirror the GeometryReader sizing used in the view body
        let screenW   = UIScreen.main.bounds.width
        let radarH: CGFloat = 300
        let size      = min(screenW, radarH)
        let center    = CGPoint(x: screenW / 2, y: radarH / 2)
        let radius    = size / 2 - 16

        let angle = planeAngles[task.id] ?? stableAngle(for: task)
        let dist  = radius * CGFloat(1.0 - task.approachFraction * 0.85)

        // P0 — where the plane currently sits on the radar
        let p0 = CGPoint(
            x: center.x + dist * CGFloat(cos(angle * .pi / 180)),
            y: center.y + dist * CGFloat(sin(angle * .pi / 180))
        )

        // P3 — runway threshold (left end of runway, at center height)
        let p3 = CGPoint(x: center.x + thresholdOffset, y: center.y)

        // P1 — extend from P0 in the plane's current flight direction (toward center)
        // This makes the curve depart tangentially in the direction the plane is already flying
        let flightDX = center.x - p0.x
        let flightDY = center.y - p0.y
        let flightLen = max(hypot(flightDX, flightDY), 1)
        let segLen = hypot(p3.x - p0.x, p3.y - p0.y)
        let p1 = CGPoint(
            x: p0.x + (flightDX / flightLen) * segLen * 0.45,
            y: p0.y + (flightDY / flightLen) * segLen * 0.45
        )

        // P2 — arrive at P3 from the left, horizontally (final approach straight-in)
        let p2 = CGPoint(x: p3.x - segLen * 0.45, y: p3.y)

        bezierP0 = p0
        bezierP1 = p1
        bezierP2 = p2
        bezierP3 = p3

        landingColor    = task.urgencyColor
        landingPhase    = .approach
        landingProgress = 0
        rolloutProgress = 0
        landingOpacity  = 1.0

        // Phase 1 — curved approach to runway threshold (2.5s)
        withAnimation(.easeIn(duration: 2.5)) { landingProgress = 1.0 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            landingPhase = .rollout
            // Phase 2 — roll along runway decelerating (1.0s)
            withAnimation(.easeOut(duration: 1.0)) { rolloutProgress = 1.0 }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                landingPhase = .stopped
                // Phase 3 — fade out (0.7s)
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

    /// Converts a plane's radar orbit angle into a heading pointing toward center.
    /// The SF Symbol airplane points up; +90 makes it face right.
    /// Direction toward center from angle θ is θ+180° (opposite of outward ray).
    /// Heading = (θ + 180°) + 90° = θ + 270°.
    private func headingTowardCenter(angle: Double) -> Double {
        return angle + 270
    }

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
    let headingDegrees: Double  // nose direction in SwiftUI rotation degrees

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
                    .rotationEffect(.degrees(headingDegrees))
                    .shadow(color: task.urgencyColor.opacity(0.8),
                            radius: isSelected ? 7 : 3)
            }
        }
    }
}
