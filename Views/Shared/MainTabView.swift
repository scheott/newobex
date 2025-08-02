import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var supabaseService: SupabaseService
    @State private var selectedTab: Tab = .journal
    // TODO: Consider dynamic launch tab based on deep links or user preferences
    
    // Get user's selected path for theming
    private var userPath: UserPath {
        supabaseService.currentUser?.selectedPath ?? .confidence
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Journal Tab
            JournalView()
                .tabItem {
                    Image(systemName: selectedTab == .journal ? "book.fill" : "book")
                    Text("Journal")
                }
                .tag(Tab.journal)
            
            // Path-Specific Tab (dynamic based on user's path)
            PathSpecificView(path: userPath)
                .tabItem {
                    Image(systemName: selectedTab == .path ? userPath.icon : userPath.icon.replacingOccurrences(of: ".fill", with: ""))
                    Text(userPath.displayName)
                }
                .tag(Tab.path)
            
            // Progress Tab
            ProgressView()
                .tabItem {
                    Image(systemName: selectedTab == .progress ? "chart.line.uptrend.xyaxis.circle.fill" : "chart.line.uptrend.xyaxis.circle")
                    Text("Progress")
                }
                .tag(Tab.progress)
            
            // Profile Tab
            ProfileView()
                .tabItem {
                    Image(systemName: selectedTab == .profile ? "person.fill" : "person")
                    Text("Profile")
                }
                .tag(Tab.profile)
        }
        .tint(userPath.colors.primary)
        .background(userPath.colors.background)
        .preferredColorScheme(userPath == .discipline ? .dark : .light)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: selectedTab)
    }
}

// MARK: - Tab Enum
private enum Tab {
    case journal
    case path
    case progress
    case profile
}

// MARK: - Journal View
struct JournalView: View {
    @EnvironmentObject private var supabaseService: SupabaseService
    
    private var userPath: UserPath {
        supabaseService.currentUser?.selectedPath ?? .confidence
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                userPath.colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: Themes.Spacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: Themes.Spacing.sm) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Your Journey")
                                    .font(userPath.typography.title)
                                    .foregroundColor(userPath.colors.text)
                                
                                if let user = supabaseService.currentUser {
                                    Text("Day \(user.streak + 1) • \(user.totalJournalEntries) entries")
                                        .font(userPath.typography.caption)
                                        .foregroundColor(userPath.colors.textSecondary)
                                }
                            }
                            
                            Spacer()
                            
                            // New Entry Button
                            NavigationLink(destination: NewJournalEntryView()) {
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(userPath.colors.background)
                                    .frame(width: 44, height: 44)
                                    .background(userPath.colors.primary)
                                    .clipShape(Circle())
                                    .shadow(color: userPath.colors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                            }
                            // TODO: Use NewJournalEntryView(viewModel:) when available
                        }
                    }
                    .padding(.horizontal, Themes.Spacing.lg)
                    
                    // Recent Entries
                    ScrollView {
                        LazyVStack(spacing: Themes.Spacing.md) {
                            // TODO: Replace with JournalView(context: viewContext, supabaseService: supabaseService)
                            // Use @StateObject initialization when JournalViewModel is ready
                            ForEach(0..<3) { index in
                                JournalEntryCard(
                                    title: "Entry \(index + 1)",
                                    preview: "This is a preview of your journal entry...",
                                    date: Date(),
                                    path: userPath
                                )
                            }
                        }
                        .padding(.horizontal, Themes.Spacing.lg)
                    }
                }
            }
            .navigationBarHidden(true)
            .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
    }
}

// MARK: - Journal Entry Card
struct JournalEntryCard: View {
    let title: String
    let preview: String
    let date: Date
    let path: UserPath
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Themes.Spacing.sm) {
            HStack {
                Text(title)
                    .font(path.typography.headline)
                    .foregroundColor(path.colors.text)
                
                Spacer()
                
                Text(dateFormatter.string(from: date))
                    .font(path.typography.caption)
                    .foregroundColor(path.colors.textSecondary)
            }
            
            Text(preview)
                .font(path.typography.body)
                .foregroundColor(path.colors.textSecondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .padding(Themes.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Themes.CornerRadius.card)
                .fill(path.colors.cardBackground)
                .shadow(
                    color: Themes.Shadow.cardShadow.color,
                    radius: Themes.Shadow.cardShadow.radius,
                    x: Themes.Shadow.cardShadow.x,
                    y: Themes.Shadow.cardShadow.y
                )
        )
    }
}

// MARK: - Path-Specific View
struct PathSpecificView: View {
    let path: UserPath
    
    var body: some View {
        NavigationView {
            ZStack {
                path.colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: Themes.Spacing.xl) {
                    // Path Header
                    VStack(spacing: Themes.Spacing.md) {
                        Image(systemName: path.icon)
                            .font(.system(size: 48, weight: .medium))
                            .foregroundColor(path.colors.primary)
                        
                        Text(path.displayName)
                            .font(path.typography.title)
                            .foregroundColor(path.colors.text)
                        
                        Text(path.description)
                            .font(path.typography.body)
                            .foregroundColor(path.colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Themes.Spacing.xl)
                    }
                    
                    // Path-Specific Content
                    ScrollView {
                        LazyVStack(spacing: Themes.Spacing.lg) {
                            Group {
                                switch path {
                                case .confidence:
                                    ConfidenceFeatures(path: path)
                                case .clarity:
                                    ClarityFeatures(path: path)
                                case .discipline:
                                    DisciplineFeatures(path: path)
                                }
                            }
                        }
                        .padding(.horizontal, Themes.Spacing.lg)
                    }
                    
                    Spacer()
                }
                .padding(.top, Themes.Spacing.xl)
            }
            .navigationBarHidden(true)
            .transition(.opacity.combined(with: .move(edge: .leading)))
        }
    }
}

// MARK: - Path-Specific Feature Views
struct ConfidenceFeatures: View {
    let path: UserPath
    
    var body: some View {
        VStack(spacing: Themes.Spacing.lg) {
            FeatureCard(
                icon: "mic.fill",
                title: "Voice Training",
                description: "AI feedback on speaking, expression, and presence",
                path: path,
                action: { /* Navigate to voice training */ }
            )
            
            FeatureCard(
                icon: "eye.fill",
                title: "Mirror Work",
                description: "Posture and eye contact drills for commanding presence",
                path: path,
                action: { /* Navigate to mirror work */ }
            )
            
            FeatureCard(
                icon: "person.2.fill",
                title: "Social Challenges",
                description: "Simulated interviews, dates, and negotiations",
                path: path,
                action: { /* Navigate to social challenges */ }
            )
        }
    }
}

struct ClarityFeatures: View {
    let path: UserPath
    
    var body: some View {
        VStack(spacing: Themes.Spacing.lg) {
            FeatureCard(
                icon: "brain.head.profile",
                title: "Thought Organization",
                description: "AI-guided journaling and thought structuring",
                path: path,
                action: { /* Navigate to thought organization */ }
            )
            
            FeatureCard(
                icon: "target",
                title: "Pattern Recognition",
                description: "Identify blind spots and core values",
                path: path,
                action: { /* Navigate to pattern recognition */ }
            )
            
            FeatureCard(
                icon: "minus.circle.fill",
                title: "Minimalism Practice",
                description: "Simplify thoughts and decision-making",
                path: path,
                action: { /* Navigate to minimalism */ }
            )
        }
    }
}

struct DisciplineFeatures: View {
    let path: UserPath
    
    var body: some View {
        VStack(spacing: Themes.Spacing.lg) {
            FeatureCard(
                icon: "figure.strengthtraining.traditional",
                title: "Daily Challenges",
                description: "Physical and mental challenges to forge will",
                path: path,
                action: { /* Navigate to challenges */ }
            )
            
            FeatureCard(
                icon: "chart.line.uptrend.xyaxis",
                title: "Habit Coaching",
                description: "AI-powered strategies and friction reduction",
                path: path,
                action: { /* Navigate to habit coaching */ }
            )
            
            FeatureCard(
                icon: "heart.fill",
                title: "Health Integration",
                description: "HealthKit data for streaks, sleep, and movement",
                path: path,
                action: { /* Navigate to health integration */ }
            )
        }
    }
}

// MARK: - Feature Card
struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let path: UserPath
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Themes.Spacing.lg) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(path.colors.primary)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: Themes.Spacing.xs) {
                    Text(title)
                        .font(path.typography.headline)
                        .foregroundColor(path.colors.text)
                    
                    Text(description)
                        .font(path.typography.caption)
                        .foregroundColor(path.colors.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(path.colors.textSecondary)
            }
            .padding(Themes.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Themes.CornerRadius.card)
                    .fill(path.colors.cardBackground)
                    .shadow(
                        color: Themes.Shadow.cardShadow.color,
                        radius: Themes.Shadow.cardShadow.radius,
                        x: Themes.Shadow.cardShadow.x,
                        y: Themes.Shadow.cardShadow.y
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(title): \(description)")
    }
}

// MARK: - Progress View
struct ProgressView: View {
    @EnvironmentObject private var supabaseService: SupabaseService
    
    private var userPath: UserPath {
        supabaseService.currentUser?.selectedPath ?? .confidence
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                userPath.colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: Themes.Spacing.lg) {
                    Text("Progress")
                        .font(userPath.typography.title)
                        .foregroundColor(userPath.colors.text)
                    
                    // Stats Cards
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: Themes.Spacing.md) {
                        if let user = supabaseService.currentUser {
                            StatCard(
                                title: "Current Streak",
                                value: "\(user.streak)",
                                subtitle: "days",
                                path: userPath
                            )
                            
                            StatCard(
                                title: "Total Entries",
                                value: "\(user.totalJournalEntries)",
                                subtitle: "entries",
                                path: userPath
                            )
                        }
                    }
                    .padding(.horizontal, Themes.Spacing.lg)
                    
                }
                .padding(.top, Themes.Spacing.xl)
            }
            .navigationBarHidden(true)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let path: UserPath
    
    var body: some View {
        VStack(spacing: Themes.Spacing.sm) {
            Text(title)
                .font(path.typography.caption)
                .foregroundColor(path.colors.textSecondary)
            
            Text(value)
                .font(path.typography.title)
                .foregroundColor(path.colors.primary)
            
            Text(subtitle)
                .font(path.typography.caption)
                .foregroundColor(path.colors.textSecondary)
        }
        .padding(Themes.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Themes.CornerRadius.card)
                .fill(path.colors.cardBackground)
                .shadow(
                    color: Themes.Shadow.cardShadow.color,
                    radius: Themes.Shadow.cardShadow.radius,
                    x: Themes.Shadow.cardShadow.x,
                    y: Themes.Shadow.cardShadow.y
                )
        )
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject private var supabaseService: SupabaseService
    
    private var userPath: UserPath {
        supabaseService.currentUser?.selectedPath ?? .confidence
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                userPath.colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: Themes.Spacing.xl) {
                    // Profile Header
                    VStack(spacing: Themes.Spacing.md) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80, weight: .light))
                            .foregroundColor(userPath.colors.primary)
                        
                        if let user = supabaseService.currentUser {
                            Text(user.displayName ?? "Elite User")
                                .font(userPath.typography.title)
                                .foregroundColor(userPath.colors.text)
                            
                            HStack(spacing: Themes.Spacing.sm) {
                                Image(systemName: userPath.icon)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(userPath.colors.primary)
                                
                                Text("\(userPath.displayName) Path")
                                    .font(userPath.typography.body)
                                    .foregroundColor(userPath.colors.textSecondary)
                            }
                        }
                    }
                    
                    // Sign Out Button
                    Button(action: {
                        Task {
                            await supabaseService.signOut()
                        }
                    }) {
                        Text("Sign Out")
                            .font(userPath.typography.headline)
                            .foregroundColor(userPath.colors.text)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: Themes.CornerRadius.button)
                                    .stroke(userPath.colors.primary, lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, Themes.Spacing.xl)
                    
                }
                .padding(.top, Themes.Spacing.xl)
            }
            .navigationBarHidden(true)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

// MARK: - Placeholder Views (to be implemented)
struct NewJournalEntryView: View {
    var body: some View {
        Text("New Journal Entry")
            .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(SupabaseService())
    }
}
