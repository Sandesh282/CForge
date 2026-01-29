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
            ZStack {
                if isLoading && allProblems.isEmpty {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.neonBlue)
                        Text("Loading Problems...")
                            .font(.headline)
                            .foregroundColor(.textSecondary)
                            .padding(.top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            SearchBar(text: $searchText, placeholder: "Search by name or rating")
                                .padding(.horizontal)
                            
                            tagFilterBar
                                .padding(.bottom, 8)
                            
                            ForEach(filteredProblems) { problem in
                                ProblemRow(problem: problem)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                }
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
            .task(id: searchText) {
                // Debounce search
                do {
                    try await Task.sleep(nanoseconds: 300_000_000) // 300ms
                    filterProblems()
                } catch {}
            }
            .task(id: selectedTag) {
                filterProblems()
            }
        }
    }


        // MARK: - Detail View Tabs
        struct DescriptionTab: View {
            let problem: Problem
            
            var body: some View {
                WebView(url: URL(string: "https://codeforces.com/contest/\(problem.contestId)/problem/\(problem.index)")!)
            }
        }
        
        struct WebView: UIViewRepresentable {
            let url: URL
            
            func makeUIView(context: Context) -> WKWebView {
                let config = WKWebViewConfiguration()
                let userContentController = WKUserContentController()
                
                let css = """
                    #header, .footer, .menu-box, .sidebar-menu, .roundbox-lt, .roundbox-rt, .roundbox-lb, .roundbox-rb, .second-level-menu, .userbox, .main-menu-list, .invitation-code-form, #topic-1 { display: none !important; }
                    #pageContent { margin: 0 !important; width: 100% !important; padding: 10px !important; }
                    .ttypography { font-size: 110% !important; }
                    body { padding-top: 0 !important; background-color: #ffffff !important; }
                """
                
                let js = """
                    var style = document.createElement('style');
                    style.innerHTML = `\(css)`;
                    document.head.appendChild(style);
                """
                
                let userScript = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
                userContentController.addUserScript(userScript)
                config.userContentController = userContentController
                
                return WKWebView(frame: .zero, configuration: config)
            }
            
            func updateUIView(_ uiView: WKWebView, context: Context) {
                let request = URLRequest(url: url)
                uiView.load(request)
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
                    
                    SubmitLauncherView(problem: problem)
                        .tag(1)
                    
                    ProblemSubmissionsView(problem: problem)
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


// MARK: - Preview
#Preview {
    ProblemListView()
}
