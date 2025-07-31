import SwiftUI
import CoreData

struct JournalView: View {
    @StateObject private var viewModel: JournalViewModel
    @EnvironmentObject private var supabaseService: SupabaseService
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingNewEntry = false
    @State private var showingFilters = false
    @State private var selectedEntry: JournalEntryData?
    
    // Current user's path for theming
    private var currentPath: UserPath {
        supabaseService.currentUser?.selectedPath ?? .clarity
    }
    
    // Theme colors based on user's path
    private var themeColors: (primary: Color, secondary: Color, accent: Color, background: Color, cardBackground: Color, text: Color, textSecondary: Color) {
        currentPath.colors
    }
    
    // Theme typography based on user's path
    private var themeTypography: (title: Font, headline: Font, body: Font, caption: Font) {
        currentPath.typography
    }
    
    init(context: NSManagedObjectContext, supabaseService: SupabaseService) {
        self._viewModel = StateObject(wrappedValue: JournalViewModel(context: context, supabaseService: supabaseService))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                themeColors.background
                    .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.entries.isEmpty {
                    loadingView
                } else if viewModel.filteredEntries.isEmpty {
                    emptyStateView
                } else {
                    journalContent
                }
            }
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingFilters = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(themeColors.primary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewEntry = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(themeColors.accent)
                    }
                }
            }
            .sheet(isPresented: $showingNewEntry) {
                NewJournalEntryView(viewModel: viewModel)
                    .environmentObject(supabaseService)
            }
            .sheet(isPresented: $showingFilters) {
                JournalFiltersView(viewModel: viewModel)
            }
            .sheet(item: $selectedEntry) { entry in
                JournalEntryDetailView(entry: entry, viewModel: viewModel)
                    .environmentObject(supabaseService)
            }
        }
        .onAppear {
            viewModel.refreshEntries()
        }
        .alert("Error", isPresented: $viewModel.showErrorAlert) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: Themes.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(themeColors.primary)
            
            Text("Loading your journal...")
                .font(themeTypography.body)
                .foregroundColor(themeColors.textSecondary)
        }
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: Themes.Spacing.xl) {
            Image(systemName: currentPath.icon)
                .font(.system(size: 64, weight: .light))
                .foregroundColor(themeColors.primary.opacity(0.6))
            
            VStack(spacing: Themes.Spacing.md) {
                Text("Your Journey Begins Here")
                    .font(themeTypography.headline)
                    .foregroundColor(themeColors.text)
                
                Text("Start documenting your path to \(currentPath.displayName.lowercased()). Every entry is a step toward becoming who you're meant to be.")
                    .font(themeTypography.body)
                    .foregroundColor(themeColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Themes.Spacing.xl)
            }
            
            Button(action: { showingNewEntry = true }) {
                HStack(spacing: Themes.Spacing.sm) {
                    Image(systemName: "plus")
                    Text("Create First Entry")
                }
                .font(themeTypography.body.weight(.semibold))
                .foregroundColor(themeColors.background)
                .padding(.horizontal, Themes.Spacing.xl)
                .padding(.vertical, Themes.Spacing.md)
                .background(themeColors.primary)
                .cornerRadius(Themes.CornerRadius.button)
            }
        }
        .padding(Themes.Spacing.xl)
    }
    
    // MARK: - Journal Content
    private var journalContent: some View {
        ScrollView {
            LazyVStack(spacing: Themes.Spacing.lg) {
                // Stats Header
                journalStatsView
                
                // Search Bar
                searchBar
                
                // Journal Entries
                ForEach(sortedDateSections, id: \.0) { date, entries in
                    journalSection(date: date, entries: entries)
                }
            }
            .padding(.horizontal, Themes.Spacing.md)
            .padding(.vertical, Themes.Spacing.sm)
        }
        .refreshable {
            viewModel.refreshEntries()
        }
    }
    
    // MARK: - Stats View
    private var journalStatsView: some View {
        HStack(spacing: Themes.Spacing.lg) {
            statCard(
                title: "Entries",
                value: "\(viewModel.entries.count)",
                icon: "book.closed"
            )
            
            statCard(
                title: "Streak",
                value: "\(viewModel.currentStreak)",
                icon: "flame"
            )
            
            statCard(
                title: "Words",
                value: formatNumber(viewModel.totalWordCount),
                icon: "text.alignleft"
            )
        }
        .padding(.top, Themes.Spacing.sm)
    }
    
    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: Themes.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(themeColors.primary)
            
            Text(value)
                .font(themeTypography.headline.weight(.bold))
                .foregroundColor(themeColors.text)
            
            Text(title)
                .font(themeTypography.caption)
                .foregroundColor(themeColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Themes.Spacing.md)
        .background(themeColors.cardBackground)
        .cornerRadius(Themes.CornerRadius.card)
        .shadow(
            color: adaptiveShadowColor,
            radius: Themes.Shadow.cardShadow.radius,
            x: Themes.Shadow.cardShadow.x,
            y: Themes.Shadow.cardShadow.y
        )
        .overlay(
            RoundedRectangle(cornerRadius: Themes.CornerRadius.card)
                .stroke(themeColors.secondary.opacity(0.3), lineWidth: 0.5)
        )
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(themeColors.textSecondary)
            
            TextField("Search entries...", text: $viewModel.searchText)
                .font(themeTypography.body)
                .foregroundColor(themeColors.text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !viewModel.searchText.isEmpty {
                Button(action: { 
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.searchText = ""
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(themeColors.textSecondary)
                }
            }
        }
        .padding(Themes.Spacing.md)
        .background(themeColors.cardBackground)
        .cornerRadius(Themes.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Themes.CornerRadius.md)
                .stroke(themeColors.secondary.opacity(0.5), lineWidth: 1)
        )
        .shadow(
            color: adaptiveShadowColor,
            radius: 2,
            x: 0,
            y: 1
        )
    }
    
    // MARK: - Journal Section
    private func journalSection(date: Date, entries: [JournalEntryData]) -> some View {
        VStack(alignment: .leading, spacing: Themes.Spacing.md) {
            // Date Header
            HStack {
                Text(formatSectionDate(date))
                    .font(themeTypography.headline.weight(.semibold))
                    .foregroundColor(themeColors.text)
                
                Spacer()
                
                Text("\(entries.count) \(entries.count == 1 ? "entry" : "entries")")
                    .font(themeTypography.caption)
                    .foregroundColor(themeColors.textSecondary)
            }
            .padding(.horizontal, Themes.Spacing.xs)
            
            // Entries for this date
            ForEach(entries) { entry in
                journalEntryCard(entry)
            }
        }
    }
    
    // MARK: - Journal Entry Card
    private func journalEntryCard(_ entry: JournalEntryData) -> some View {
        Button(action: { 
            withAnimation(.easeInOut(duration: 0.2)) { 
                selectedEntry = entry 
            } 
        }) {
            VStack(alignment: .leading, spacing: Themes.Spacing.sm) {
                // Header with time and path
                HStack {
                    // Path indicator
                    HStack(spacing: Themes.Spacing.xs) {
                        Image(systemName: entry.userPath.icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(entry.userPath.colors.primary)
                        
                        Text(entry.userPath.displayName)
                            .font(themeTypography.caption.weight(.medium))
                            .foregroundColor(entry.userPath.colors.primary)
                    }
                    
                    Spacer()
                    
                    // Time and metadata
                    VStack(alignment: .trailing, spacing: Themes.Spacing.xs) {
                        Text(entry.timeAgo)
                            .font(themeTypography.caption)
                            .foregroundColor(themeColors.textSecondary)
                        
                        if let mood = entry.mood {
                            HStack(spacing: 2) {
                                let starRating = Int(round(Double(mood) / 2.0))
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= starRating ? "star.fill" : "star")
                                        .font(.system(size: 10))
                                        .foregroundColor(themeColors.accent.opacity(0.7))
                                }
                            }
                        }
                    }
                }
                
                // Title (if exists)
                if let title = entry.title, !title.isEmpty {
                    Text(title)
                        .font(themeTypography.body.weight(.semibold))
                        .foregroundColor(themeColors.text)
                        .lineLimit(1)
                }
                
                // Content preview
                Text(entry.content)
                    .font(themeTypography.body)
                    .foregroundColor(themeColors.textSecondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                // AI Summary (if available)
                if let aiSummary = entry.aiSummary, !aiSummary.isEmpty {
                    Text(aiSummary)
                        .font(themeTypography.caption)
                        .foregroundColor(themeColors.textSecondary.opacity(0.8))
                        .italic()
                        .lineLimit(2)
                        .padding(.top, Themes.Spacing.xs)
                        .overlay(
                            // Subtle AI indicator
                            HStack {
                                Spacer()
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 10))
                                    .foregroundColor(themeColors.primary.opacity(0.5))
                            }
                        )
                }
                
                // Footer with tags and reading time
                HStack {
                    // Tags
                    if !entry.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Themes.Spacing.xs) {
                                ForEach(entry.tags.prefix(3), id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(themeTypography.caption)
                                        .foregroundColor(themeColors.primary)
                                        .padding(.horizontal, Themes.Spacing.sm)
                                        .padding(.vertical, 2)
                                        .background(themeColors.primary.opacity(0.1))
                                        .cornerRadius(Themes.CornerRadius.sm)
                                }
                                
                                if entry.tags.count > 3 {
                                    Text("+\(entry.tags.count - 3)")
                                        .font(themeTypography.caption)
                                        .foregroundColor(themeColors.textSecondary)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Reading time and privacy indicator
                    HStack(spacing: Themes.Spacing.sm) {
                        if entry.isPrivate {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12))
                                .foregroundColor(themeColors.textSecondary)
                        }
                        
                        Text(entry.readingTime)
                            .font(themeTypography.caption)
                            .foregroundColor(themeColors.textSecondary)
                    }
                }
            }
            .padding(Themes.Spacing.md)
            .background(themeColors.cardBackground)
            .cornerRadius(Themes.CornerRadius.card)
            .shadow(
                color: adaptiveShadowColor,
                radius: Themes.Shadow.cardShadow.radius,
                x: Themes.Shadow.cardShadow.x,
                y: Themes.Shadow.cardShadow.y
            )
        }
        .buttonStyle(ResponsiveButtonStyle())
    }
    
    // MARK: - Computed Properties
    private var sortedDateSections: [(Date, [JournalEntryData])] {
        viewModel.entriesByDate
            .sorted { $0.key > $1.key }
            .map { ($0.key, $0.value.sorted { $0.createdAt > $1.createdAt }) }
    }
    
    // Dark mode adaptive shadow color
    private var adaptiveShadowColor: Color {
        Color.primary.opacity(0.1)
    }
    
    // MARK: - Helper Methods
    private func formatSectionDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
    
    private func formatNumber(_ number: Int) -> String {
        if number >= 1000 {
            return String(format: "%.1fk", Double(number) / 1000.0)
        }
        return "\(number)"
    }
}

// MARK: - Supporting Views

// Custom Button Style for Entry Cards
struct ResponsiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct JournalFiltersView: View {
    @ObservedObject var viewModel: JournalViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Path") {
                    Picker("Filter by Path", selection: $viewModel.selectedPath) {
                        Text("All Paths").tag(UserPath?.none)
                        ForEach(UserPath.allCases, id: \.self) { path in
                            Text(path.displayName).tag(path as UserPath?)
                        }
                    }
                }
                
                Section("Privacy") {
                    Toggle("Private entries only", isOn: $viewModel.showPrivateOnly)
                }
                
                Section("Tags") {
                    if viewModel.availableTags.isEmpty {
                        Text("No tags available")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.availableTags, id: \.self) { tag in
                            HStack {
                                Text("#\(tag)")
                                Spacer()
                                if viewModel.selectedTags.contains(tag) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if viewModel.selectedTags.contains(tag) {
                                    viewModel.selectedTags.remove(tag)
                                } else {
                                    viewModel.selectedTags.insert(tag)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        viewModel.clearFilters()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
struct JournalView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.shared.container.viewContext
        let supabaseService = SupabaseService()
        
        JournalView(context: context, supabaseService: supabaseService)
            .environmentObject(supabaseService)
            .environment(\.managedObjectContext, context)
    }
}