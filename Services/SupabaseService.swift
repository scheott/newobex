import Foundation
import CoreData
import Combine
import Supabase

// MARK: - Date Formatter Extension
extension ISO8601DateFormatter {
    static let shared = ISO8601DateFormatter()
}

    // MARK: - Journal Entry Data Model
struct JournalEntryData: Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let date: Date
    let userPath: UserPath
    let title: String?
    let content: String
    let mood: Int?
    let aiSummary: String?
    let aiReflection: String?
    let aiInsights: [String]
    let voiceNoteURL: String?
    let voiceTranscript: String?
    let tags: [String]
    let isPrivate: Bool
    let createdAt: Date
    let updatedAt: Date
    
    // Helper computed properties
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    var wordCount: Int {
        content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
    }
    
    var readingTime: String {
        let wordsPerMinute = 200
        let minutes = max(1, wordCount / wordsPerMinute)
        return "\(minutes) min read"
    }
}

// MARK: - Journal View Model
@MainActor
class JournalViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var entries: [JournalEntryData] = []
    @Published var filteredEntries: [JournalEntryData] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedPath: UserPath?
    @Published var searchText = ""
    @Published var isCreatingEntry = false
    @Published var selectedEntry: JournalEntryData?
    @Published var showErrorAlert = false
    
    // MARK: - AI Analysis Properties
    @Published var isAnalyzing = false
    @Published var aiInsights: JournalAIResponse?
    
    // MARK: - Filter Properties
    @Published var showPrivateOnly = false
    @Published var selectedMoodRange: ClosedRange<Int>?
    @Published var selectedTags: Set<String> = []
    
    // MARK: - Dependencies
    private let context: NSManagedObjectContext
    private let aiService = JournalAIService.shared
    private let supabaseService: SupabaseService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var availableTags: [String] {
        Array(Set(entries.flatMap { $0.tags })).sorted()
    }
    
    var entriesByDate: [Date: [JournalEntryData]] {
        Dictionary(grouping: filteredEntries) { entry in
            Calendar.current.startOfDay(for: entry.date)
        }
    }
    
    var totalWordCount: Int {
        entries.reduce(0) { $0 + $1.wordCount }
    }
    
    var currentStreak: Int {
        calculateCurrentStreak()
    }
    
    // MARK: - Initialization
    init(context: NSManagedObjectContext, supabaseService: SupabaseService) {
        self.context = context
        self.supabaseService = supabaseService
        
        setupSubscriptions()
        loadEntries()
    }
    
    // MARK: - Setup
    private func setupSubscriptions() {
        // Filter entries based on search text and filters
        Publishers.CombineLatest4($entries, $searchText, $selectedPath, $showPrivateOnly)
            .map { entries, searchText, selectedPath, showPrivateOnly in
                self.filterEntries(entries, searchText: searchText, path: selectedPath, privateOnly: showPrivateOnly)
            }
            .assign(to: &$filteredEntries)
        
        // Listen for user path changes
        supabaseService.$currentUser
            .compactMap { $0?.selectedPath }
            .sink { [weak self] path in
                self?.selectedPath = path
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Core Data Operations
    func loadEntries() {
        guard let currentUser = supabaseService.currentUser else { return }
        
        isLoading = true
        errorMessage = nil
        
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", currentUser.id as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            let coreDataEntries = try context.fetch(request)
            self.entries = coreDataEntries.map { convertToJournalEntryData($0) }
            isLoading = false
        } catch {
            errorMessage = "Failed to load journal entries: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func createEntry(
        title: String?,
        content: String,
        userPath: UserPath,
        mood: Int? = nil,
        tags: [String] = [],
        isPrivate: Bool = false,
        withAIAnalysis: Bool = true
    ) async -> Bool {
        guard let currentUser = supabaseService.currentUser else { return false }
        
        isCreatingEntry = true
        errorMessage = nil
        
        do {
            // Create Core Data entity
            let newEntry = JournalEntry(context: context)
            newEntry.id = UUID()
            newEntry.userId = currentUser.id
            newEntry.date = Date()
            newEntry.userPath = userPath.rawValue
            newEntry.title = title
            newEntry.content = content
            newEntry.mood = Int16(mood ?? 0)
            newEntry.tags = tags.joined(separator: ",")
            newEntry.isPrivate = isPrivate
            newEntry.createdAt = Date()
            newEntry.updatedAt = Date()
            
            // Generate AI analysis if requested
            if withAIAnalysis {
                isAnalyzing = true
                
                let aiRequest = JournalAIRequest(
                    content: content,
                    userPath: userPath,
                    previousEntries: getRecentEntryContents(limit: 3),
                    mood: mood
                )
                
                do {
                    let aiResponse = try await aiService.analyzeJournalEntry(aiRequest)
                    
                    // Save AI analysis to Core Data
                    newEntry.aiSummary = aiResponse.summary
                    newEntry.aiReflection = aiResponse.reflection
                    newEntry.aiInsights = aiResponse.insights.joined(separator: "|")
                    
                    // Update mood if AI provided a better estimate
                    if mood == nil, let aiMood = aiResponse.mood {
                        newEntry.mood = Int16(aiMood)
                    }
                    
                    // Merge AI suggested tags with user tags
                    let allTags = Set(tags + aiResponse.suggestedTags)
                    newEntry.tags = Array(allTags).joined(separator: ",")
                    
                    self.aiInsights = aiResponse
                } catch {
                    // AI analysis failed, but we'll still save the entry
                    errorMessage = "Entry saved, but AI analysis failed: \(error.localizedDescription)"
                    print("AI analysis failed: \(error)")
                }
                
                isAnalyzing = false
            }
            
            // Save to Core Data
            try context.save()
            
            // Update Supabase (fire and forget)
            Task {
                await syncToSupabase(newEntry)
            }
            
            // Reload entries to update UI
            loadEntries()
            
            // Update user's total journal entries count
            Task {
                let newCount = currentUser.totalJournalEntries + 1
                _ = await supabaseService.updateJournalEntryCount(newCount)
            }
            
            isCreatingEntry = false
            return true
            
        } catch {
            errorMessage = "Failed to create journal entry: \(error.localizedDescription)"
            showErrorAlert = true
            isCreatingEntry = false
            return false
        }
    }
    
    func updateEntry(_ entryData: JournalEntryData, title: String?, content: String, tags: [String], isPrivate: Bool) async -> Bool {
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", entryData.id as CVarArg)
        
        do {
            let results = try context.fetch(request)
            guard let entry = results.first else { return false }
            
            entry.title = title
            entry.content = content
            entry.tags = tags.joined(separator: ",")
            entry.isPrivate = isPrivate
            entry.updatedAt = Date()
            
            try context.save()
            
            // Sync to Supabase
            Task {
                await syncToSupabase(entry)
            }
            
            loadEntries()
            return true
            
        } catch {
            errorMessage = "Failed to update entry: \(error.localizedDescription)"
            showErrorAlert = true
            return false
        }
    }
    
    func deleteEntry(_ entryData: JournalEntryData) async -> Bool {
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", entryData.id as CVarArg)
        
        do {
            let results = try context.fetch(request)
            guard let entry = results.first else { return false }
            
            context.delete(entry)
            try context.save()
            
            // Update user's total journal entries count
            if let currentUser = supabaseService.currentUser {
                Task {
                    let newCount = max(0, currentUser.totalJournalEntries - 1)
                    _ = await supabaseService.updateJournalEntryCount(newCount)
                }
            }
            
            loadEntries()
            return true
            
        } catch {
            errorMessage = "Failed to delete entry: \(error.localizedDescription)"
            showErrorAlert = true
            return false
        }
    }
    
    // MARK: - AI Operations
    func generateReflection(for content: String, userPath: UserPath) async -> String? {
        do {
            return try await aiService.generateQuickReflection(content: content, userPath: userPath)
        } catch {
            errorMessage = "Failed to generate reflection: \(error.localizedDescription)"
            return nil
        }
    }
    
    func analyzeMood(for content: String) async -> Int? {
        do {
            return try await aiService.analyzeMood(content: content)
        } catch {
            return nil
        }
    }
    
    // MARK: - Filtering and Search
    private func filterEntries(
        _ entries: [JournalEntryData],
        searchText: String,
        path: UserPath?,
        privateOnly: Bool
    ) -> [JournalEntryData] {
        var filtered = entries
        
        // Filter by path
        if let path = path {
            filtered = filtered.filter { $0.userPath == path }
        }
        
        // Filter by privacy
        if privateOnly {
            filtered = filtered.filter { $0.isPrivate }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { entry in
                entry.title?.localizedCaseInsensitiveContains(searchText) == true ||
                entry.content.localizedCaseInsensitiveContains(searchText) ||
                entry.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // Filter by selected tags
        if !selectedTags.isEmpty {
            filtered = filtered.filter { entry in
                !Set(entry.tags).isDisjoint(with: selectedTags)
            }
        }
        
        // Filter by mood range
        if let moodRange = selectedMoodRange {
            filtered = filtered.filter { entry in
                guard let mood = entry.mood else { return false }
                return moodRange.contains(mood)
            }
        }
        
        return filtered
    }
    
    // MARK: - Helper Methods
    private func convertToJournalEntryData(_ entry: JournalEntry) -> JournalEntryData {
        JournalEntryData(
            id: entry.id ?? UUID(),
            userId: entry.userId ?? UUID(),
            date: entry.date ?? Date(),
            userPath: UserPath(rawValue: entry.userPath ?? "") ?? .clarity,
            title: entry.title,
            content: entry.content ?? "",
            mood: entry.mood != 0 ? Int(entry.mood) : nil,
            aiSummary: entry.aiSummary,
            aiReflection: entry.aiReflection,
            aiInsights: entry.aiInsights?.components(separatedBy: "|").filter { !$0.isEmpty } ?? [],
            voiceNoteURL: entry.voiceNoteURL,
            voiceTranscript: entry.voiceTranscript,
            tags: entry.tags?.components(separatedBy: ",").filter { !$0.isEmpty } ?? [],
            isPrivate: entry.isPrivate,
            createdAt: entry.createdAt ?? Date(),
            updatedAt: entry.updatedAt ?? Date()
        )
    }
    
    private func getRecentEntryContents(limit: Int) -> [String] {
        entries.prefix(limit).map { $0.content }
    }
    
    private func calculateCurrentStreak() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var currentDate = today
        
        let entriesByDate = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.date)
        }
        
        while entriesByDate[currentDate] != nil {
            streak += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }
        
        return streak
    }
    
    private func syncToSupabase(_ entry: JournalEntry) async {
        guard let currentUser = supabaseService.currentUser else { return }
        
        let entryData: [String: Any] = [
            "id": entry.id?.uuidString ?? UUID().uuidString,
            "user_id": currentUser.id.uuidString,
            "date": ISO8601DateFormatter.shared.string(from: entry.date ?? Date()),
            "user_path": entry.userPath ?? "clarity",
            "title": entry.title,
            "content": entry.content ?? "",
            "mood": entry.mood != 0 ? Int(entry.mood) : nil,
            "ai_summary": entry.aiSummary,
            "ai_reflection": entry.aiReflection,
            "ai_insights": entry.aiInsights,
            "voice_note_url": entry.voiceNoteURL,
            "voice_transcript": entry.voiceTranscript,
            "tags": entry.tags,
            "is_private": entry.isPrivate,
            "created_at": ISO8601DateFormatter.shared.string(from: entry.createdAt ?? Date()),
            "updated_at": ISO8601DateFormatter.shared.string(from: entry.updatedAt ?? Date())
        ]
        
        let success = await supabaseService.syncJournalEntry(entryData)
        
        if success {
            print("Successfully synced entry \(entry.id?.uuidString ?? "unknown") to Supabase")
        } else {
            print("Failed to sync entry to Supabase")
            errorMessage = "Entry saved locally but cloud sync failed"
        }
    }
    
    // MARK: - Voice Note Upload
    func uploadVoiceNote(_ audioData: Data, for entryId: UUID) async -> String? {
        guard let currentUser = supabaseService.currentUser else { return nil }
        
        let fileName = "\(currentUser.id.uuidString)/voice_notes/\(entryId.uuidString).m4a"
        
        return await supabaseService.uploadVoiceNote(audioData, fileName: fileName)
    }
    
    // MARK: - Batch Sync for Offline Entries
    func syncPendingEntries() async {
        let request: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        request.predicate = NSPredicate(format: "syncStatus != %@", "synced")
        
        do {
            let pendingEntries = try context.fetch(request)
            
            for entry in pendingEntries {
                await syncToSupabase(entry)
                // Mark as synced if successful (you might want to check return value)
                entry.syncStatus = "synced"
            }
            
            try context.save()
            
        } catch {
            print("Failed to sync pending entries: \(error)")
        }
    }
    
    // MARK: - Public Interface Methods
    func refreshEntries() {
        loadEntries()
    }
    
    func clearFilters() {
        searchText = ""
        selectedPath = nil
        showPrivateOnly = false
        selectedTags.removeAll()
        selectedMoodRange = nil
    }
    
    func exportEntries() -> String {
        let sortedEntries = entries.sorted { $0.createdAt < $1.createdAt }
        
        var exportString = "Obex Journal Export\n"
        exportString += "Generated: \(Date().formatted())\n"
        exportString += "Total Entries: \(entries.count)\n"
        exportString += "Total Words: \(totalWordCount)\n\n"
        
        for entry in sortedEntries {
            exportString += "---\n"
            exportString += "Date: \(entry.formattedDate)\n"
            exportString += "Path: \(entry.userPath.displayName)\n"
            if let title = entry.title {
                exportString += "Title: \(title)\n"
            }
            if let mood = entry.mood {
                exportString += "Mood: \(mood)/10\n"
            }
            if !entry.tags.isEmpty {
                exportString += "Tags: \(entry.tags.joined(separator: ", "))\n"
            }
            exportString += "\n\(entry.content)\n\n"
            
            if let aiSummary = entry.aiSummary {
                exportString += "AI Summary: \(aiSummary)\n\n"
            }
        }
        
        return exportString
    }
}
