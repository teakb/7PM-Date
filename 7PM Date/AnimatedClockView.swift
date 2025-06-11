import SwiftUI

// MARK: - Main View
struct AnimatedClockView: View {
    let startDate: Date
    let endDate: Date

    @State private var animationProgress: CGFloat = 0.0
    @State private var timer: Timer? = nil
    @State private var hasAnimated = false

    init(targetHour: Int = 19, targetMinute: Int = 0) {
        let calendar = Calendar.current
        
        // Prepare components for a fixed date (arbitrary)
        var components = DateComponents()
        components.year = 2025 // An arbitrary, fixed year
        components.month = 1   // An arbitrary, fixed month
        components.day = 1     // An arbitrary, fixed day
        components.timeZone = TimeZone.current // Use current time zone for consistency
        
        // Set the target time (e.g., 7 PM)
        components.hour = targetHour
        components.minute = targetMinute
        let end = calendar.date(from: components)!
        
        // Calculate start date exactly one hour before the end date
        let start = calendar.date(byAdding: .hour, value: -1, to: end)!
        
        self.startDate = start
        self.endDate = end
    }

    // This computed property calculates the time to display based on the animation's progress.
    private var currentTimeDisplayed: Date {
        let interval = endDate.timeIntervalSince(startDate)
        let secondsToAdd = interval * animationProgress
        return startDate.addingTimeInterval(secondsToAdd)
    }
    
    // MARK: - Angle Calculations
    private var hourAngle: Angle {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTimeDisplayed) % 12
        let minute = calendar.component(.minute, from: currentTimeDisplayed)
        let totalHours = Double(hour) + Double(minute) / 60.0
        return Angle.degrees(totalHours * 30.0)
    }

    private var minuteAngle: Angle {
        let calendar = Calendar.current
        let minute = calendar.component(.minute, from: currentTimeDisplayed)
        let second = calendar.component(.second, from: currentTimeDisplayed)
        let totalMinutes = Double(minute) + Double(second) / 60.0
        return Angle.degrees(totalMinutes * 6.0)
    }

    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            
            ZStack {
                Circle().fill(Color.gray.opacity(0.1))
                HourMarkersView(clockRadius: size / 2)
                HourHandView(hourAngle: hourAngle, clockRadius: size / 2)
                MinuteHandView(minuteAngle: minuteAngle, clockRadius: size / 2)
                Circle()
                    .fill(Color.primary)
                    .frame(width: max(4, size * 0.05), height: max(4, size * 0.05))
            }
            .frame(width: size, height: size)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .onAppear(perform: animateClock)
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    // MARK: - Animation Logic
    private func animateClock() {
        guard !hasAnimated else { return }
        hasAnimated = true
        let duration: TimeInterval = 4.0
        let startTime = Date()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { t in
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(elapsed / duration, 1.0)
            animationProgress = progress
            if progress >= 1.0 {
                t.invalidate()
                timer = nil
            }
        }
    }
}


// MARK: - Reusable View Components (Unchanged)
struct HourMarkersView: View {
    let clockRadius: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<12) { i in
                let angle = .pi / 6 * Double(i) - .pi / 2
                Path { path in
                    let startPoint = CGPoint(
                        x: cos(angle) * (clockRadius * 0.9),
                        y: sin(angle) * (clockRadius * 0.9)
                    )
                    let endPoint = CGPoint(
                        x: cos(angle) * (clockRadius * 0.95),
                        y: sin(angle) * (clockRadius * 0.95)
                    )
                    path.move(to: startPoint)
                    path.addLine(to: endPoint)
                }
                .stroke(Color.primary.opacity(0.5), lineWidth: 1)
            }
        }
        .offset(x: clockRadius, y: clockRadius)
    }
}

struct HourHandView: View {
    let hourAngle: Angle
    let clockRadius: CGFloat

    var body: some View {
        let hourHandLength = clockRadius * 0.5
        let endPoint = CGPoint(
            x: cos(hourAngle.radians - .pi / 2) * hourHandLength,
            y: sin(hourAngle.radians - .pi / 2) * hourHandLength
        )
        return Path { path in
            path.move(to: .zero)
            path.addLine(to: endPoint)
        }
        .stroke(Color.primary, style: StrokeStyle(lineWidth: max(3, clockRadius * 0.03), lineCap: .round))
        .offset(x: clockRadius, y: clockRadius)
    }
}

struct MinuteHandView: View {
    let minuteAngle: Angle
    let clockRadius: CGFloat
    
    var body: some View {
        let minuteHandLength = clockRadius * 0.7
        let endPoint = CGPoint(
            x: cos(minuteAngle.radians - .pi / 2) * minuteHandLength,
            y: sin(minuteAngle.radians - .pi / 2) * minuteHandLength
        )
        return Path { path in
            path.move(to: .zero)
            path.addLine(to: endPoint)
        }
        .stroke(Color.primary, style: StrokeStyle(lineWidth: max(2, clockRadius * 0.02), lineCap: .round))
        .offset(x: clockRadius, y: clockRadius)
    }
}


// MARK: - Previews
struct AnimatedClockView_Previews: PreviewProvider {
    static var previews: some View {
        AnimatedClockView(targetHour: 19, targetMinute: 0)
            // The frame size has been doubled to make the clock larger in the preview.
            .frame(width: 1200, height: 1200)
            .padding()
            .background(Color(white: 0.95))
            .previewDisplayName("7 PM Animation")
    }
}
