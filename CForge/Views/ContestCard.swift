import SwiftUI

struct ContestCard: View {
    
    @State private var timeRemaining: TimeInterval = 86400
    @State private var isRegistering = false
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    let contest: Contest = Contest(
        name: "Codeforces Round #999",
        isRated: true,
        startTime: Date().addingTimeInterval(86400),
        duration: 9000
    )
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "c.circle.fill")
                    .foregroundColor(.orange)
                
                Text(contest.name)
                    .font(.headline)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            
            HStack {
                Image(systemName: "clock")
                Text(timeString(time: timeRemaining))
                    .font(.system(.subheadline, design: .monospaced))
                    .onReceive(timer) { _ in
                        if timeRemaining > 0 {
                            timeRemaining -= 1
                        } else {
                            timer.upstream.connect().cancel()
                        }
                    }
            }
            .foregroundColor(timeRemaining < 3600 ? .red : .secondary)
            
            Divider()
            
            HStack {

                if contest.isRated {
                    Capsule()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 80, height: 24)
                        .overlay(
                            Text("Rated")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.orange)
                        )
                }
                
                Spacer()
                
                Button(action: registerAction) {
                    HStack(spacing: 6) {
                        if isRegistering {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isRegistering ? "Registering..." : "Register")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(RegisterButtonStyle())
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func registerAction() {
        isRegistering = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isRegistering = false
        }
    }
    
    private func timeString(time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

struct RegisterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(configuration.isPressed ? Color.blue.opacity(0.8) : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}


struct Contest {
    let name: String
    let isRated: Bool
    let startTime: Date
    let duration: TimeInterval
}

// Preview
#Preview {
    ContestCard()
        .padding()
}
