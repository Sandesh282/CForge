//
//  ProblemListView.swift
//  CForge
//
//  Created by Sandesh Raj on 29/03/25.
//
import SwiftUI
import WebKit

struct ProblemListView: View {
  
    // MARK: - View State
    @State internal var allProblems: [Problem] = []
    @State internal var filteredProblems: [Problem] = []
    @State internal var searchText = ""
    @State internal var selectedTag: String?
    @State internal var isLoading = false
    @State internal var errorMessage = ""
    

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    SearchBar(text: $searchText, placeholder: "Search by name or rating")
                        .padding(.horizontal)
                        .onChange(of: searchText) { _ in
                                filterProblems()
                            }
                    
                    tagFilterBar
                        .padding(.bottom, 8)
                    
                    ForEach(filteredProblems) { problem in
                        ProblemRow(problem: problem)  
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Problems")
            .navigationDestination(for: Problem.self) { problem in
                ProblemDetailView(problem: problem)
                    .id(problem.id)
            }

            .background(
                LinearGradient(
                    colors: [.darkBackground, .darkestBackground],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
                        .task { await loadProblems() }
            
        }
    }
    
    
    private var problemListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                SearchBar(text: $searchText, placeholder: "Search by name or rating")
                    .padding(.horizontal)
                    .onChange(of: searchText) { filterProblems() }
                
                tagFilterBar
                    .padding(.bottom, 8)
                
                ForEach(filteredProblems) { problem in
                    ProblemRow(problem: problem)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    private var tagFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(Set(allProblems.flatMap { $0.tags })), id: \.self) { tag in
                    Button(action: {
                        selectedTag = selectedTag == tag ? nil : tag
                        filterProblems()
                    }) {
                        Text(tag.capitalized)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                    ZStack {
                                        if selectedTag == tag {
                                            LinearGradient(
                                                colors: [.neonBlue, .neonPurple],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        } else {
                                            Color.darkerBackground
                                        }
                                    }
                                )
                            .foregroundColor(selectedTag == tag ? .white : .primary)
                            .cornerRadius(12)
                            .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            LinearGradient(
                                                colors: [.neonBlue.opacity(0.4), .neonPurple.opacity(0.4)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
    // MARK: - Problem Row
    struct ProblemRow: View {
        let problem: Problem
        
        var body: some View {
            NavigationLink(value: problem) {
                VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(problem.title)
                                    .font(.headline)
                                    .foregroundColor(.textPrimary)
                                
                                Spacer()
                                
                                Text("#\(problem.contestId)\(problem.index)")
                                    .font(.system(size: 12, weight: .bold))
                                    .padding(6)
                                    .background(
                                        LinearGradient(
                                            colors: [.neonBlue.opacity(0.2), .neonPurple.opacity(0.2)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(6)
                            }
                            
                            if let rating = problem.rating {
                                HStack {
                                    Text("Rating:")
                                        .font(.subheadline)
                                        .foregroundColor(.textSecondary)
                                    
                                    Text("\(rating)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.neonBlue, .neonPurple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                }
                            }
                            
                            if !problem.tags.isEmpty {
                                tagsView
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
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        
        
        private var tagsView: some View {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(problem.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                       LinearGradient(
                                           colors: [.neonBlue.opacity(0.2), .neonPurple.opacity(0.2)],
                                           startPoint: .leading,
                                           endPoint: .trailing
                                       )
                                   )
                            .foregroundColor(.neonBlue)
                            .cornerRadius(8)
                    }
                }
            }
        }
    }
}

extension ProblemListView {
    struct ProblemDetailView: View {
        let problem: Problem
        @State private var selectedTab = 0
        
        var body: some View {
            VStack(spacing: 0) {
                // Problem header
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        Text(problem.title)
                            .font(.title2.bold())
                            .foregroundColor(.textPrimary)
                        
                        Spacer()
                        
                        Text("#\(problem.contestId)\(problem.index)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.neonBlue)
                            .padding(8)
                            .background(
                                LinearGradient( 
                                    colors: [.neonBlue.opacity(0.2), .neonPurple.opacity(0.2)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(8)
                    }
                    
                    if let rating = problem.rating {
                        HStack(spacing: 4) {
                            Text("Rating:")
                                .font(.subheadline)
                                .foregroundColor(.textSecondary)
                            
                            Text("\(rating)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.neonBlue, .neonPurple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                    }
                    
                    if !problem.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(problem.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            LinearGradient(
                                                colors: [.neonBlue.opacity(0.2), .neonPurple.opacity(0.2)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .foregroundColor(.neonBlue)
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                Picker("", selection: $selectedTab) {
                    Text("Description").tag(0)
                    Text("Submit").tag(1)
                    Text("Submissions").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.darkBackground)
                
                TabView(selection: $selectedTab) {
                    DescriptionTab(problem: problem)
                        .tag(0)
                    
                    SubmitTab(problem: problem)
                        .tag(1)
                    
                    SubmissionsTab(problem: problem)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Problem")
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
        

        struct SubmitTab: View {
            let problem: Problem
            @State private var selectedFile: URL?
            @State private var isFileImporterPresented = false
            @State private var submissionStatus: SubmissionStatus?
            @State private var selectedLanguage = "C++"
            let languages = ["C++", "Java", "Python", "Rust"]
            
            var body: some View {
                Form {
                    Section {
                        Picker("Language", selection: $selectedLanguage) {
                            ForEach(languages, id: \.self) { language in
                                Text(language)
                            }
                        }
                        
                        Button {
                            isFileImporterPresented = true
                        } label: {
                            HStack {
                                Image(systemName: "doc")
                                Text(selectedFile?.lastPathComponent ?? "Select Solution File")
                                Spacer()
                                if selectedFile != nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                    
                    if let selectedFile {
                        Section {
                            Button("Submit Solution") {
                                Task {
                                    await submitSolution(file: selectedFile)
                                }
                            }
                            .disabled(submissionStatus?.isInProgress == true)
                        }
                    }
                    
                    if let status = submissionStatus {
                        Section {
                            HStack {
                                if status.isInProgress {
                                    ProgressView()
                                }
                                Text(status.message)
                                    .foregroundColor(status.color)
                            }
                        }
                    }
                }
                .fileImporter(
                    isPresented: $isFileImporterPresented,
                    allowedContentTypes: [.plainText],
                    allowsMultipleSelection: false
                ) { result in
                    if case .success(let files) = result {
                        selectedFile = files.first
                        submissionStatus = nil
                    }
                }
            }
            
            private func submitSolution(file: URL) async {
                submissionStatus = .submitting
                // Simulate API call
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                
                let randomSuccess = Bool.random()
                submissionStatus = randomSuccess ?
                    .success(message: "Submitted successfully! ID: \(Int.random(in: 100000...999999))") :
                    .failure(message: "Submission failed: Time limit exceeded")
            }
            
            enum SubmissionStatus {
                case submitting
                case success(message: String)
                case failure(message: String)
                
                var message: String {
                    switch self {
                    case .submitting: return "Submitting..."
                    case .success(let message): return message
                    case .failure(let message): return message
                    }
                }
                
                var color: Color {
                    switch self {
                    case .submitting: return .blue
                    case .success: return .green
                    case .failure: return .red
                    }
                }
                
                var isInProgress: Bool {
                    if case .submitting = self { return true }
                    return false
                }
            }
        }
        
        // MARK: - Detail View Tabs
        struct DescriptionTab: View {
            let problem: Problem
            @State internal var problemStatement: String?
            @State internal var isLoading = false
            @State internal var errorMessage: String?
            
            var body: some View {
                ScrollView {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = errorMessage {
                        VStack {
                                ContentUnavailableView(
                                    "Error Loading Problem",
                                    systemImage: "exclamationmark.triangle",
                                    description: Text(error)
                                )
                                Button("Retry") {
                                    Task { await loadProblemStatement() }
                                }
                                .buttonStyle(.bordered)
                            }

                    } else if let statement = problemStatement {

                        HTMLView(htmlContent: statement)
                                           .frame(height: UIScreen.main.bounds.height)
                                           .padding()
                    } else {
                        ContentUnavailableView(
                            "No Problem Statement",
                            systemImage: "doc.text.magnifyingglass",
                            description: Text("Problem statement not available")
                        )
                    }
                }
                .task {
                    await loadProblemStatement()
                }

            }
            private var emptyView: some View {
                    ContentUnavailableView(
                        "No Problem Statement",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Problem statement not available")
                    )
                }
            private func errorView(error: String) -> some View {
                    VStack {
                        ContentUnavailableView(
                            "Error Loading Problem",
                            systemImage: "exclamationmark.triangle",
                            description: Text(error)
                        )
                        Button("Retry") {
                            Task { await loadProblemStatement() }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            struct HTMLView: UIViewRepresentable {
                    let htmlContent: String
                    
                    func makeUIView(context: Context) -> WKWebView {
                        return WKWebView()
                    }
                    
                    func updateUIView(_ uiView: WKWebView, context: Context) {
                        let header = """
                        <head>
                            <meta name="viewport" content="width=device-width, initial-scale=1">
                            <style>
                                body { font-family: -apple-system; font-size: 16px; }
                                img { max-width: 100%; height: auto; }
                            </style>
                        </head>
                        """
                        uiView.loadHTMLString(header + htmlContent, baseURL: nil)
                    }
                }
        }
        
        struct SubmissionsTab: View {
            let problem: Problem
            @State private var submissions: [Submission] = []
            @State private var isLoading = false
            
            var body: some View {
                Group {
                    if isLoading {
                        ProgressView()
                    } else if submissions.isEmpty {
                        ContentUnavailableView(
                            "No Submissions",
                            systemImage: "doc.text.magnifyingglass",
                            description: Text("You haven't submitted any solutions yet")
                        )
                    } else {
                        List(submissions) { submission in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(submission.verdict.rawValue)
                                        .foregroundColor(submission.verdict.color)
                                    Spacer()
                                    Text(submission.time)
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                
                                HStack {
                                    Text("Test \(submission.passedTestCount)/\(submission.testCount)")
                                        .font(.caption2)
                                        .padding(4)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(4)
                                    
                                    Text(submission.language)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .refreshable {
                            await loadSubmissions()
                        }
                    }
                }
                .task {
                    await loadSubmissions()
                }
            }
            
            private func loadSubmissions() async {
                isLoading = true
                // Simulate API call
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                
                submissions = [
                    Submission(
                        id: 1,
                        verdict: .accepted,
                        time: "2 minutes ago",
                        passedTestCount: 50,
                        testCount: 50,
                        language: "C++"
                    ),
                    Submission(
                        id: 2,
                        verdict: .wrongAnswer,
                        time: "5 minutes ago",
                        passedTestCount: 12,
                        testCount: 50,
                        language: "Python"
                    )
                ]
                isLoading = false
            }
            
            struct Submission: Identifiable {
                let id: Int
                let verdict: Verdict
                let time: String
                let passedTestCount: Int
                let testCount: Int
                let language: String
                
                enum Verdict: String {
                    case accepted = "Accepted"
                    case wrongAnswer = "Wrong Answer"
                    case timeLimitExceeded = "Time Limit Exceeded"
                    case compilationError = "Compilation Error"
                    case runtimeError = "Runtime Error"
                    
                    var color: Color {
                        switch self {
                        case .accepted: return .green
                        case .wrongAnswer, .compilationError, .runtimeError: return .red
                        case .timeLimitExceeded: return .orange
                        }
                    }
                }
            }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                            .foregroundColor(.neonBlue)
                            .padding(.leading, 12)

                        TextField("Search by name or rating", text: $text)
                            .foregroundColor(.textPrimary)
                            .autocapitalization(.none)
                            .textInputAutocapitalization(.never)

                        if !text.isEmpty {
                            Button(action: { text = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.neonPurple)
                            }
                            .padding(.trailing, 12)
                        }
        }
        .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.darkerBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
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
         .padding(.horizontal, 4)
    }
}
class SubmissionStore: ObservableObject {
    @Published var userSubmissions: [Submission] = []
    
    func addSubmission(_ submission: Submission) {
        userSubmissions.append(submission)
        saveSubmissions()
    }
    
    func getSubmissions(forProblem problemId: String) -> [Submission] {
        return userSubmissions
            .filter { $0.problemId == problemId }
            .sorted { $0.timestamp > $1.timestamp }
    }
    
    private let saveKey = "userSubmissions"
    
    init() {
        loadSubmissions()
    }
    
    func loadSubmissions() {
        if let data = UserDefaults.standard.data(forKey: saveKey) {
            do {
                userSubmissions = try JSONDecoder().decode([Submission].self, from: data)
            } catch {
                print("Error loading submissions: \(error)")
            }
        }
    }
    
    func saveSubmissions() {
        do {
            let data = try JSONEncoder().encode(userSubmissions)
            UserDefaults.standard.set(data, forKey: saveKey)
        } catch {
            print("Error saving submissions: \(error)")
        }
    }
}
struct Submission: Identifiable, Codable, Hashable {
    let id = UUID()
    let problemId: String
    let verdict: Verdict
    let time: String
    let passedTestCount: Int
    let testCount: Int
    let language: String
    let timestamp = Date()
    
    enum Verdict: String, Codable, CaseIterable {
        case accepted = "Accepted"
        case wrongAnswer = "Wrong Answer"
        case timeLimitExceeded = "Time Limit Exceeded"
        case runtimeError = "Runtime Error"
        case compilationError = "Compilation Error"
        case memoryLimitExceeded = "Memory Limit Exceeded"
        case unknown = "Unknown"
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            self = Verdict(rawValue: rawValue) ?? .unknown
        }
        
        var color: Color {
            switch self {
            case .accepted: return .green
            case .wrongAnswer, .compilationError, .runtimeError: return .red
            case .timeLimitExceeded, .memoryLimitExceeded: return .orange
            case .unknown: return .gray
            }
        }
    }
}


// MARK: - Preview
#Preview {
    ProblemListView()
}
