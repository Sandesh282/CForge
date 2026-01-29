import SwiftUI
import SDWebImageSwiftUI

import Charts


struct ProfileView: View {
    @State var profileData: CodeforcesUser?
    @State var errorMessage: String?
    @State var solvedProblemsCount: Int?
    @EnvironmentObject var userManager: UserManager
    @State private var showLogoutConfirm = false
    @AppStorage("userHandle") private var storedHandle: String?
    @State var ratingHistory: [RatingChange] = []
    
    var userHandle: String {
        userManager.userHandle
    }
    
    var body: some View {
        ScrollView {
            if let user = profileData {
                VStack(spacing: 20) {
                    profileHeader(user: user)
                    ratingSection(user: user)
                    statsSection(user: user)
                    ratingChart()
                }
                .padding()
            } else if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            } else {
                ProgressView("Fetching Profile...")
            }
            
        }
        .navigationTitle("Profile")
        .background(
            LinearGradient(
                colors: [.darkBackground, .darkestBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onAppear {
            fetchProfileData()
            fetchSolvedProblems()
            fetchRatingHistory()
        }
    }
    
    // MARK: - Profile Header (Avatar, Handle, Rank)
    private func profileHeader(user: CodeforcesUser) -> some View {
        HStack(spacing: 16) {
            
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.darkerBackground, .darkBackground],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.neonBlue, .neonPurple],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.neonBlue, .neonPurple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: .neonBlue.opacity(0.4), radius: 8)
            VStack(alignment: .leading, spacing: 4) {
                Text(user.handle)
                    .font(.title.bold())
                
                Text(user.rank ?? "Unranked")
                    .font(.headline)
                    .foregroundColor(rankColor(for: user.rank ?? ""))
            }
            
            Spacer()
            Button(action: {
                showLogoutConfirm = true
            }) {
                Image(systemName: "power")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.red)
                    .padding(10)
                    .background(Circle().fill(Color.red.opacity(0.2)))
            }
            .confirmationDialog(
                "Logout",
                isPresented: $showLogoutConfirm,
                titleVisibility: .visible
            ) {
                Button("Log Out", role: .destructive) {
                    storedHandle = nil
                    userManager.userHandle = ""
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to log out?")
            }
        }
        .padding(.vertical)
    }
    
    // MARK: - Rating Section
    private func ratingSection(user: CodeforcesUser) -> some View {
        
        let currentRating = user.rating ?? 0
        let maxRatingValue = user.maxRating ?? 1
        let progressPercentage = Int((Double(currentRating) / Double(maxRatingValue)) * 100)
        
        return VStack(spacing: 12) {
            HStack {
                Text("Rating:")
                    .font(.headline)
                    .foregroundColor(.textSecondary)
                Spacer()
                Text("\(currentRating)")
                    .font(.system(.title3).weight(.bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.neonBlue, .neonPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(rankColor(for: user.rank ?? ""))
            }
            .frame(height: 20)
            
            ProgressView(value: Double(currentRating), total: Double(maxRatingValue)) {
                
            } currentValueLabel: {
                
            }
            .progressViewStyle(NeonProgressStyle())
            .overlay(
                HStack {
                    Text("\(currentRating)/\(maxRatingValue)")
                        .font(.caption)
                    Spacer()
                    Text("\(progressPercentage)%")
                        .font(.caption)
                }
                    .foregroundColor(.textSecondary)
                    .padding(.horizontal, 4)
                    .offset(y: 14)
            )
            .frame(height: 20)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.darkerBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .neonBlue.opacity(0.4),
                                    .neonPurple.opacity(0.4)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .cornerRadius(12)
    }
    struct NeonProgressStyle: ProgressViewStyle {
        func makeBody(configuration: Configuration) -> some View {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .frame(height: 8)
                    .foregroundColor(.darkerBackground)
                
                RoundedRectangle(cornerRadius: 4)
                    .frame(
                        width: configuration.fractionCompleted.map { CGFloat($0) * UIScreen.main.bounds.width - 32 },
                        height: 8
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.neonBlue, .neonPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            
        }
    }
    // MARK: - Updated Statistics Section
    private func statsSection(user: CodeforcesUser) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("User Statistics")
                .font(.headline)
                .foregroundColor(.textSecondary)
            
            HStack(spacing: 10) {
                StatCard(value: "\(solvedProblemsCount ?? 0)", label: "Solved")
                StatCard(value: "\(user.contribution ?? 0)", label: "Contributions")
                StatCard(value: "\(user.rating ?? 0)", label: "Rating")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.darkerBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .neonBlue.opacity(0.4),
                                    .neonPurple.opacity(0.4)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .cornerRadius(12)
    }
    
    // MARK: - StatCard View
    struct StatCard: View {
        let value: String
        let label: String
        
        var body: some View {
            VStack {
                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.neonBlue, .neonPurple],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.darkerBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        .neonBlue.opacity(0.4),
                                        .neonPurple.opacity(0.4)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .cornerRadius(12)
        }
    }
    // MARK: - New Recent Activity Section
    private func recentActivitySection() -> some View {
        VStack(alignment: .leading) {
            Text("Recent Activity")
                .font(.headline)
            
            ForEach(0..<4, id: \.self) { _ in
                HStack {
                    Circle()
                        .frame(width: 8, height: 8)
                        .foregroundColor(.green)
                    Text("Solved Problem 123A")
                    Spacer()
                    Text("2h ago")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    
    // MARK: - API Fetch Function
    
    private func ratingChart() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rating Progress")
                .font(.headline)
                .foregroundColor(.textSecondary)
            
            if ratingHistory.isEmpty {
                ProgressView()
                    .frame(height: 150)
            } else {
                Chart {
                    ForEach(ratingHistory, id: \.contestId) { change in
                        LineMark(
                            x: .value("Date", Date(timeIntervalSince1970: Double(change.ratingUpdateTimeSeconds))),
                            y: .value("Rating", change.newRating)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.neonBlue, .neonPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 200)
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.darkerBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [.neonBlue.opacity(0.4), .neonPurple.opacity(0.4)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        ProfileView()
    }
    .environmentObject(UserManager(userHandle: "tourist"))
}

 
