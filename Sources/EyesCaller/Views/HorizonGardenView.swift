import AppKit
import SwiftUI

struct HorizonGardenView: View {
    let phase: SessionPhase
    let progress: Double
    let appearance: AppearanceMode

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pointer = CGSize.zero
    @State private var lastPointerUpdate: TimeInterval = 0
    @State private var windowIsVisible = true

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 15.0,
                paused: reduceMotion || !windowIsVisible
            )
        ) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let breeze = reduceMotion ? 0 : sin(time * 0.75)
            let cloudDriftSlow = reduceMotion ? 0.35 : time.truncatingRemainder(dividingBy: 48) / 48
            let cloudDriftReverse = reduceMotion ? 0.62 : time.truncatingRemainder(dividingBy: 39) / 39

            GeometryReader { proxy in
                let size = proxy.size

                ZStack {
                    LinearGradient(
                        colors: skyColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .animation(themeAnimation, value: appearance)

                    if appearance == .night {
                        starField(size: size, time: time)
                            .offset(x: pointer.width * 1.4, y: pointer.height)
                            .transition(starTransition)
                    }

                    sun(size: size)
                        .offset(x: pointer.width * 2.5, y: pointer.height * 2)

                    moon(size: size)
                        .offset(x: pointer.width * 3, y: pointer.height * 2.4)

                    cloud(scale: 0.82)
                        .offset(
                            x: cloudOffset(
                                progress: cloudDriftSlow,
                                sceneWidth: size.width,
                                renderedCloudWidth: 68,
                                direction: 1
                            ),
                            y: -size.height * 0.28
                        )
                        .offset(x: pointer.width * 2, y: pointer.height * 1.5)
                        .opacity(appearance == .night ? 0.3 : 0.72)
                        .animation(themeAnimation, value: appearance)

                    cloud(scale: 0.58)
                        .offset(
                            x: cloudOffset(
                                progress: cloudDriftReverse,
                                sceneWidth: size.width,
                                renderedCloudWidth: 48,
                                direction: -1
                            ),
                            y: -size.height * 0.12
                        )
                        .offset(x: pointer.width * 2.8, y: pointer.height * 2)
                        .opacity(appearance == .night ? 0.22 : 0.46)
                        .animation(themeAnimation, value: appearance)

                    HillShape(height: 0.46, crest: 0.34)
                        .fill(farHillColor)
                        .scaleEffect(1.025)
                        .offset(
                            x: pointer.width * 3.5,
                            y: size.height * 0.29 + pointer.height * 2.5
                        )

                    HillShape(height: 0.55, crest: 0.67)
                        .fill(nearHillColor)
                        .scaleEffect(1.035)
                        .offset(
                            x: pointer.width * 5,
                            y: size.height * 0.42 + pointer.height * 3.5
                        )

                    Path { path in
                        path.move(to: CGPoint(x: size.width * 0.09, y: size.height * 0.79))
                        path.addCurve(
                            to: CGPoint(x: size.width * 0.92, y: size.height * 0.74),
                            control1: CGPoint(x: size.width * 0.35, y: size.height * 0.72),
                            control2: CGPoint(x: size.width * 0.65, y: size.height * 0.8)
                        )
                    }
                    .stroke(sceneLineColor, style: StrokeStyle(lineWidth: 1.5, dash: [3, 7]))
                    .offset(x: pointer.width * 5.5, y: pointer.height * 4)

                    if appearance == .night {
                        fireflies(size: size, time: time)
                            .offset(x: pointer.width * 6.5, y: pointer.height * 5)
                            .transition(fireflyTransition)
                    }

                    PlantSprig(breeze: breeze, appearance: appearance)
                        .frame(width: 54, height: 104)
                        .offset(
                            x: -size.width * 0.34 + pointer.width * 8,
                            y: size.height * 0.3 + pointer.height * 6
                        )

                    PlantSprig(breeze: -breeze * 0.75, appearance: appearance)
                        .frame(width: 42, height: 82)
                        .scaleEffect(x: -1, y: 1)
                        .offset(
                            x: size.width * 0.37 + pointer.width * 8,
                            y: size.height * 0.34 + pointer.height * 6
                        )

                    LookoutFriend(
                        isCelebrating: phase == .completed,
                        breeze: breeze,
                        appearance: appearance
                    )
                        .frame(width: 116, height: 116)
                        .offset(
                            x: 18 + pointer.width * 10,
                            y: size.height * 0.27 + pointer.height * 7
                        )

                    if phase == .resting {
                        gazeLine(size: size)
                            .offset(x: pointer.width * 6, y: pointer.height * 4)
                            .transition(.opacity)
                    }

                    RoundedRectangle(cornerRadius: 38, style: .continuous)
                        .stroke(GardenTheme.border, lineWidth: 1.5)
                        .padding(1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
                .rotation3DEffect(
                    .degrees(reduceMotion ? 0 : Double(-pointer.height * 1.35)),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.35
                )
                .rotation3DEffect(
                    .degrees(reduceMotion ? 0 : Double(pointer.width * 1.65)),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.35
                )
                .scaleEffect(reduceMotion ? 1 : 1 + parallaxMagnitude * 0.028)
                .contentShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
                .onContinuousHover { hoverPhase in
                    updatePointer(for: hoverPhase, in: size)
                }
            }
        }
        .shadow(color: GardenTheme.shadow, radius: 28, y: 14)
        .background(WindowOcclusionReader(isVisible: $windowIsVisible))
        .onChange(of: reduceMotion) { shouldReduceMotion in
            if shouldReduceMotion {
                pointer = .zero
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("一只举着望远镜、眺望远山的小伙伴")
    }

    private func updatePointer(for hoverPhase: HoverPhase, in size: CGSize) {
        guard !reduceMotion, size.width > 0, size.height > 0 else {
            pointer = .zero
            return
        }

        switch hoverPhase {
        case .active(let location):
            let now = ProcessInfo.processInfo.systemUptime
            guard now - lastPointerUpdate >= 1.0 / 30.0 else { return }
            lastPointerUpdate = now

            let normalizedX = min(max((location.x / size.width) * 2 - 1, -1), 1)
            let normalizedY = min(max((location.y / size.height) * 2 - 1, -1), 1)
            withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.86)) {
                pointer = CGSize(width: normalizedX, height: normalizedY)
            }

        case .ended:
            lastPointerUpdate = 0
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                pointer = .zero
            }
        }
    }

    private var parallaxMagnitude: CGFloat {
        min(max(abs(pointer.width), abs(pointer.height)), 1)
    }

    private func cloudOffset(
        progress: Double,
        sceneWidth: CGFloat,
        renderedCloudWidth: CGFloat,
        direction: CGFloat
    ) -> CGFloat {
        let hiddenEdge = sceneWidth / 2 + renderedCloudWidth / 2 + 16
        let leftToRight = -hiddenEdge + CGFloat(progress) * hiddenEdge * 2
        return leftToRight * direction
    }

    private var themeAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 1.25)
    }

    private var starTransition: AnyTransition {
        guard !reduceMotion else { return .identity }
        return .opacity.animation(
            appearance == .night
                ? .easeInOut(duration: 0.9).delay(0.35)
                : .easeOut(duration: 0.38)
        )
    }

    private var fireflyTransition: AnyTransition {
        guard !reduceMotion else { return .identity }
        return .opacity.animation(
            appearance == .night
                ? .easeInOut(duration: 0.8).delay(0.62)
                : .easeOut(duration: 0.3)
        )
    }

    private var skyColors: [Color] {
        if appearance == .night {
            switch phase {
            case .completed:
                return [Color(hex: 0x17333E), Color(hex: 0x21463D)]
            case .resting:
                return [Color(hex: 0x102936), Color(hex: 0x193B34)]
            case .focus, .ready:
                return [Color(hex: 0x102631), Color(hex: 0x19362F)]
            }
        }
        if phase == .completed {
            return [Color(hex: 0xBEE2E5), Color(hex: 0xE8F4D5)]
        }
        return [Color(hex: 0xDCEEEF), Color(hex: 0xEAF3DF)]
    }

    private var farHillColor: Color {
        appearance == .night ? Color(hex: 0x31594F) : Color(hex: 0xB6D9B7)
    }

    private var nearHillColor: Color {
        appearance == .night ? Color(hex: 0x24473E) : Color(hex: 0x83B691)
    }

    private var sceneLineColor: Color {
        appearance == .night ? Color(hex: 0xA9D6C7).opacity(0.2) : Color.white.opacity(0.32)
    }

    private func sun(size: CGSize) -> some View {
        let completionLift = phase == .completed ? 0.0 : (1 - progress) * 18
        let nightOffset = appearance == .night ? size.height * 0.7 : 0

        return Circle()
            .fill(GardenTheme.sunlight)
            .frame(width: phase == .completed ? 74 : 58, height: phase == .completed ? 74 : 58)
            .overlay(Circle().stroke(GardenTheme.border, lineWidth: 7))
            .shadow(color: GardenTheme.sunlight.opacity(0.48), radius: phase == .completed ? 28 : 14)
            .scaleEffect(appearance == .night ? 0.72 : 1)
            .opacity(appearance == .night ? 0 : 1)
            .offset(
                x: size.width * (appearance == .night ? 0.33 : 0.25),
                y: -size.height * 0.24 + completionLift + nightOffset
            )
            .animation(themeAnimation, value: appearance)
            .animation(
                reduceMotion ? nil : .spring(response: 0.9, dampingFraction: 0.72),
                value: phase
            )
    }

    private func moon(size: CGSize) -> some View {
        Image(systemName: "moon.fill")
            .font(.system(size: phase == .completed ? 68 : 58, weight: .medium))
            .foregroundStyle(Color(hex: 0xE7E4B7))
            .shadow(color: Color(hex: 0xC5E5DF).opacity(0.58), radius: phase == .completed ? 28 : 18)
            .scaleEffect(appearance == .night ? 1 : 0.72)
            .opacity(appearance == .night ? 1 : 0)
            .offset(
                x: -size.width * (appearance == .night ? 0.23 : 0.31),
                y: appearance == .night ? -size.height * 0.23 : size.height * 0.5
            )
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 1.35).delay(appearance == .night ? 0.14 : 0),
                value: appearance
            )
    }

    private func starField(size: CGSize, time: TimeInterval) -> some View {
        let stars: [(CGFloat, CGFloat, CGFloat, Double)] = [
            (0.13, 0.16, 3.0, 0.2), (0.29, 0.09, 2.0, 1.4),
            (0.47, 0.2, 2.5, 2.1), (0.68, 0.1, 2.0, 0.8),
            (0.83, 0.22, 3.0, 2.8), (0.2, 0.34, 1.8, 3.2),
            (0.58, 0.32, 2.2, 1.1), (0.76, 0.4, 1.7, 2.4)
        ]

        return ZStack {
            ForEach(Array(stars.enumerated()), id: \.offset) { _, star in
                Circle()
                    .fill(Color(hex: 0xD7EEE7))
                    .frame(width: star.2, height: star.2)
                    .opacity(reduceMotion ? 0.7 : 0.5 + sin(time * 1.15 + star.3) * 0.22)
                    .position(x: size.width * star.0, y: size.height * star.1)
            }
        }
    }

    private func fireflies(size: CGSize, time: TimeInterval) -> some View {
        let lights: [(CGFloat, CGFloat, Double)] = [
            (0.16, 0.68, 0.4), (0.31, 0.76, 1.9), (0.62, 0.7, 2.7),
            (0.76, 0.79, 1.2), (0.87, 0.64, 3.4)
        ]

        return ZStack {
            ForEach(Array(lights.enumerated()), id: \.offset) { _, light in
                Circle()
                    .fill(Color(hex: 0xF1D77C))
                    .frame(width: 4, height: 4)
                    .shadow(color: Color(hex: 0xF1D77C).opacity(0.8), radius: 5)
                    .opacity(reduceMotion ? 0.72 : 0.48 + sin(time * 1.5 + light.2) * 0.32)
                    .position(x: size.width * light.0, y: size.height * light.1)
            }
        }
    }

    private func cloud(scale: CGFloat) -> some View {
        HStack(spacing: -10) {
            Circle().frame(width: 30, height: 30)
            Circle().frame(width: 45, height: 45)
            Circle().frame(width: 28, height: 28)
        }
        .foregroundStyle(
            appearance == .night
                ? Color(hex: 0xB7D4D0).opacity(0.66)
                : Color.white.opacity(0.76)
        )
        .scaleEffect(scale)
    }

    private func gazeLine(size: CGSize) -> some View {
        Path { path in
            path.move(to: CGPoint(x: size.width * 0.57, y: size.height * 0.61))
            path.addLine(to: CGPoint(x: size.width * 0.86, y: size.height * 0.39))
        }
        .trim(from: 0, to: max(0.12, progress))
        .stroke(
            appearance == .night ? Color(hex: 0xC8E8DF).opacity(0.58) : Color.white.opacity(0.72),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 7])
        )
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.7), value: progress)
    }
}

private struct HillShape: Shape {
    let height: CGFloat
    let crest: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height * height))
        path.addCurve(
            to: CGPoint(x: rect.width, y: rect.height * (height + 0.08)),
            control1: CGPoint(x: rect.width * crest, y: rect.height * (height - 0.24)),
            control2: CGPoint(x: rect.width * (crest + 0.1), y: rect.height * (height + 0.24))
        )
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

private struct PlantSprig: View {
    let breeze: Double
    let appearance: AppearanceMode

    var body: some View {
        ZStack(alignment: .bottom) {
            Capsule()
                .fill(GardenTheme.fern.opacity(0.72))
                .frame(width: 3, height: 82)

            ForEach(0..<4, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(leafColor(at: index))
                    .frame(width: 25, height: 12)
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -27 : 27))
                    .offset(
                        x: index.isMultiple(of: 2) ? -11 : 11,
                        y: CGFloat(-14 - index * 18)
                    )
            }
        }
        .rotationEffect(.degrees(breeze * 2.2), anchor: .bottom)
    }

    private func leafColor(at index: Int) -> Color {
        if appearance == .night {
            return index.isMultiple(of: 2) ? Color(hex: 0x789B72) : Color(hex: 0x5F896A)
        }
        return index.isMultiple(of: 2) ? Color(hex: 0xD8E9B6) : Color(hex: 0xBBD69E)
    }
}

private struct LookoutFriend: View {
    let isCelebrating: Bool
    let breeze: Double
    let appearance: AppearanceMode

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Ellipse()
                .fill(GardenTheme.fern.opacity(0.12))
                .frame(width: 92, height: 18)
                .offset(y: 48)

            Circle()
                .fill(appearance == .night ? Color(hex: 0xD9D8BD) : Color(hex: 0xF7F1D8))
                .frame(width: 78, height: 78)
                .overlay(
                    Circle()
                        .fill(appearance == .night ? Color(hex: 0xBDA878) : Color(hex: 0xE8CFA1))
                        .frame(width: 27, height: 24)
                        .offset(x: -24, y: -24)
                )
                .offset(y: 8)

            Circle()
                .fill(appearance == .night ? Color(hex: 0x17312B) : GardenTheme.ink)
                .frame(width: 6, height: isCelebrating ? 3 : 7)
                .offset(x: 19, y: -1)

            HStack(spacing: 0) {
                Capsule()
                    .fill(GardenTheme.fern)
                    .frame(width: 34, height: 12)
                Circle()
                    .fill(GardenTheme.skyDeep)
                    .frame(width: 18, height: 18)
                Rectangle()
                    .fill(GardenTheme.sunlight)
                    .frame(width: 12, height: 8)
            }
            .rotationEffect(.degrees(-18 + breeze * 0.7))
            .offset(x: 39, y: -13)

            Capsule()
                .fill(appearance == .night ? Color(hex: 0xBDA878) : Color(hex: 0xE8CFA1))
                .frame(width: 18, height: 7)
                .rotationEffect(.degrees(-24))
                .offset(x: 23, y: 18)

            if isCelebrating {
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(GardenTheme.sunlight)
                    .offset(x: -40, y: -35)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .rotationEffect(.degrees(breeze * 0.5), anchor: .bottom)
        .animation(
            reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.65),
            value: isCelebrating
        )
    }
}

private struct WindowOcclusionReader: NSViewRepresentable {
    @Binding var isVisible: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isVisible: $isVisible)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.attach(to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isVisible = $isVisible
        DispatchQueue.main.async {
            context.coordinator.attach(to: nsView.window)
        }
    }

    @MainActor
    final class Coordinator {
        var isVisible: Binding<Bool>
        private weak var window: NSWindow?
        private nonisolated(unsafe) var observation: NSObjectProtocol?

        init(isVisible: Binding<Bool>) {
            self.isVisible = isVisible
        }

        deinit {
            if let observation {
                NotificationCenter.default.removeObserver(observation)
            }
        }

        func attach(to window: NSWindow?) {
            guard self.window !== window else {
                updateVisibility()
                return
            }
            if let observation {
                NotificationCenter.default.removeObserver(observation)
            }
            self.window = window
            guard let window else { return }
            observation = NotificationCenter.default.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.updateVisibility()
                }
            }
            updateVisibility()
        }

        private func updateVisibility() {
            guard let window else { return }
            let visible = window.isVisible
                && !window.isMiniaturized
                && window.occlusionState.contains(.visible)
            if isVisible.wrappedValue != visible {
                isVisible.wrappedValue = visible
            }
        }
    }
}
