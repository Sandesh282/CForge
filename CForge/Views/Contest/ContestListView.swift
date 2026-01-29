import SwiftUI
import EventKit
import EventKitUI

struct ContestListView: View {
    // MARK: - Models
    // MARK: - State
    @State internal var contests: [CFContest] = []
    @State internal var searchText = ""
    @State internal var isRefreshing = false
    @State internal var errorMessage: String?
    @State internal var showError = false
    
    // MARK: - Main View
    var body: some View {
        NavigationStack {
            Group {
                if contests.isEmpty && !isRefreshing {
                    ProgressView()
                        .onAppear { Task { await loadContests() } }
                } else {
                    contentView
                }
            }
            .navigationTitle("Contests")
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }
    
    // MARK: - View Components

    private var contentView: some View {
        ScrollView {
            SearchBar(text: $searchText, placeholder: "Search contests...")
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .shadow(radius: 1)
            LazyVStack(spacing: 0) {
                ForEach(filteredContests) { contest in
                    NavigationLink {
                        ContestDetailView(contest: contest)
                    } label: {
                        contestCard(contest: contest)
                            .padding(.bottom, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }

        .background(
            LinearGradient(
                colors: [.darkBackground, .darkestBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .refreshable { await refreshContests() }
    }

    private func contestCard(contest: CFContest) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            
            VStack(alignment: .leading, spacing: 6) {
                Text(contest.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 16) {
                    Label(contest.startTime.formatted(date: .omitted, time: .shortened),
                          systemImage: "clock")
                    Label(contest.duration, systemImage: "hourglass")
                }
                .font(.subheadline)
                .foregroundColor(.textSecondary)
                .labelStyle(NeonLabelStyle())
            }
            

            Divider()
                .padding(.vertical, 4)
            

            HStack {
                if contest.isRated {
                    Text("Rated")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
                
                Spacer()
                
                NavigationLink(destination: ContestDetailView(contest: contest)) {
                                Text("Register")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                            }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.darkerBackground.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .neonBlue.opacity(0.5),
                                    .neonPurple.opacity(0.5)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .cornerRadius(12)
        .shadow(color: .neonBlue.opacity(0.2), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }
    struct NeonLabelStyle: LabelStyle {
        func makeBody(configuration: Configuration) -> some View {
            HStack(spacing: 4) {
                configuration.icon
                    .foregroundColor(.neonBlue)
                configuration.title
            }
        }
    }
}

// MARK: - Subviews
struct ContestRow: View {
    let contest: ContestListView.CFContest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(contest.name)
                    .font(.headline)
                Spacer()
                if contest.isRated {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }
            }
            
            HStack {
                Image(systemName: "calendar")
                Text(contest.startTime.formatted(date: .abbreviated, time: .shortened))
                Spacer()
                Image(systemName: "clock")
                Text(contest.duration)
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

struct ContestDetailView: View {
    let contest: ContestListView.CFContest
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                countdownSection
                Divider()
                infoSection
                Divider()
                actionButtons
                
            }
            .padding()
        }
        .navigationTitle("Contest Details")
        .navigationBarTitleDisplayMode(.inline)
        .background(
                    LinearGradient(
                        colors: [.darkBackground, .darkerBackground],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
    }
    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Label {
                Text(title)
                    .foregroundColor(.secondary)
            } icon: {
                Image(systemName: icon)
                    .foregroundColor(.blue)
            }
            .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(contest.name)
                .font(.title.bold())
                .foregroundColor(.textPrimary)
            
            HStack(spacing: 8) {
                if contest.isRated {
                    pillLabel(text: "Rated", colors: [.neonBlue, .neonPurple])
                }
                pillLabel(text: contest.type, colors: [.darkBackground, .darkerBackground])
            }
        }
    }

    
    private func pillLabel(text: String, colors: [Color]) -> some View {
           Text(text)
               .font(.caption.weight(.semibold))
               .padding(.horizontal, 12)
               .padding(.vertical, 6)
               .background(
                   LinearGradient(
                       colors: colors,
                       startPoint: .leading,
                       endPoint: .trailing
                   )
               )
               .foregroundColor(.white)
               .cornerRadius(8)
       }
    
    private var countdownSection: some View {
            VStack(spacing: 8) {
                Text("Starts in")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                
                HStack(spacing: 4) {
                    Text(contest.timeUntilStart)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.neonBlue, .neonPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                
                Text("Days    Hours    Minutes")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.darkerBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [.neonBlue.opacity(0.4), .neonPurple.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
    
        private var infoSection: some View {
           VStack(spacing: 16) {
               infoRow(icon: "calendar", title: "Start Time",
                      value: contest.startTime.formatted(date: .complete, time: .shortened))
               
               infoRow(icon: "clock", title: "Duration",
                      value: contest.duration)
               
               infoRow(icon: "person.2.fill", title: "Participants",
                      value: "12,345 registered")
           }
           .padding()
           .background(
               RoundedRectangle(cornerRadius: 16)
                   .fill(Color.darkerBackground)
                   .overlay(
                       RoundedRectangle(cornerRadius: 16)
                           .stroke(
                               LinearGradient(
                                   colors: [.neonBlue.opacity(0.4), .neonPurple.opacity(0.4)],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing
                               ),
                               lineWidth: 1
                           )
                   )
           )
       }
    
    private func infoRow(icon: String, title: String, value: String) -> some View {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.neonBlue)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .foregroundColor(.textSecondary)
                        .font(.subheadline)
                    
                    Text(value)
                        .foregroundColor(.textPrimary)
                        .font(.body.weight(.medium))
                }
                
                Spacer()
            }
        }
    
        private var actionButtons: some View {
            VStack(spacing: 12) {
                
                if let registrationUrl = contest.registrationUrl {
                    Link(destination: contest.registrationUrl ?? URL(string: "https://codeforces.com")!) {
                                Text("Register Now")
                                    .font(.headline.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        LinearGradient(
                                            colors: [.neonBlue, .neonPurple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(.white.opacity(0.2), lineWidth: 1)
                                        )
                                    )
                                    .foregroundColor(.white)
                                    .shadow(color: .neonBlue.opacity(0.4), radius: 8, x: 0, y: 4)
                            }
                } else {
                    Button("Registration Closed") {
                        
                    }
                    .disabled(true)
                    .buttonStyle(PrimaryButtonStyle())
                }
                
            }
            .padding(.top, 8)
        }

    private func showAlert(title: String, message: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        rootViewController.present(alert, animated: true)
    }
    
}

// MARK: - Styles
struct ContestRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemBackground))
            .foregroundColor(.primary)
            .cornerRadius(10)
    }
}

// MARK: - Preview
#Preview {
    ContestListView()
}
