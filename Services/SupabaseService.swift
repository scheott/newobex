import Foundation
import Combine
import Supabase

// MARK: - User Profile Model
struct UserProfile: Codable, Identifiable {
    let id: UUID
    let email: String
    let createdAt: Date
    var selectedPath: UserPath?
    var displayName: String?
    var onboardingCompleted: Bool
    var streak: Int
    var totalJournalEntries: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case createdAt = "created_at"
        case selectedPath = "selected_path"
        case displayName = "display_name"
        case onboardingCompleted = "onboarding_completed"
        case streak
        case totalJournalEntries = "total_journal_entries"
    }
    
    init(from supabaseUser: User, profile: UserProfileDB? = nil) {
        self.id = UUID(uuidString: supabaseUser.id.uuidString) ?? UUID()
        self.email = supabaseUser.email ?? ""
        self.createdAt = supabaseUser.createdAt
        
        // Use profile data if available, otherwise defaults
        self.selectedPath = profile?.selectedPath
        self.displayName = profile?.displayName
        self.onboardingCompleted = profile?.onboardingCompleted ?? false
        self.streak = profile?.streak ?? 0
        self.totalJournalEntries = profile?.totalJournalEntries ?? 0
    }
}

// MARK: - Database Profile Model (for Supabase table)
private struct UserProfileDB: Codable {
    let id: UUID
    let email: String
    let selectedPath: UserPath?
    let displayName: String?
    let onboardingCompleted: Bool
    let streak: Int
    let totalJournalEntries: Int
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case selectedPath = "selected_path"
        case displayName = "display_name"
        case onboardingCompleted = "onboarding_completed"
        case streak
        case totalJournalEntries = "total_journal_entries"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Authentication Result
struct AuthResult {
    let user: UserProfile
    let session: AuthSession
}

struct AuthSession: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
    }
    
    init(from supabaseSession: Session) {
        self.accessToken = supabaseSession.accessToken
        self.refreshToken = supabaseSession.refreshToken
        self.expiresAt = supabaseSession.expiresAt
    }
}

// MARK: - Supabase Service
@MainActor
class SupabaseService: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var currentUser: UserProfile?
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private var authSession: AuthSession?
    private let supabase: SupabaseClient
    
    // MARK: - Configuration
    private let baseURL = "https://your-project.supabase.co" // Replace with your Supabase URL
    private let apiKey = "your-anon-key" // Replace with your anon key
    
    // MARK: - Initialization
    init() {
        // Initialize Supabase client
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: baseURL)!,
            supabaseKey: apiKey
        )
        
        // Set up auth state listener
        setupAuthStateListener()
        
        // Check initial auth state
        checkAuthenticationState()
    }
    
    // MARK: - Auth State Management
    private func setupAuthStateListener() {
        Task {
            for await authState in supabase.auth.authStateChanges {
                await handleAuthStateChange(authState)
            }
        }
    }
    
    private func handleAuthStateChange(_ authState: AuthState) async {
        switch authState.event {
        case .signedIn:
            if let session = authState.session {
                await handleSuccessfulAuth(session)
            }
        case .signedOut:
            await handleSignOut()
        case .tokenRefreshed:
            if let session = authState.session {
                await updateSession(session)
            }
        default:
            break
        }
    }
    
    private func checkAuthenticationState() {
        // Check for stored session
        if let sessionData = UserDefaults.standard.data(forKey: "obex_auth_session"),
           let session = try? JSONDecoder().decode(AuthSession.self, from: sessionData),
           session.expiresAt > Date() {
            
            self.authSession = session
            self.isAuthenticated = true
            
            // Load user profile
            Task {
                await loadUserProfile()
            }
        }
    }
    
    // MARK: - Sign Up
    func signUp(email: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            // Create auth user
            let authResponse = try await supabase.auth.signUp(
                email: email,
                password: password
            )
            
            guard let session = authResponse.session else {
                throw AuthError.registrationFailed
            }
            
            // Create user profile in database
            let profileData = UserProfileDB(
                id: UUID(uuidString: authResponse.user.id.uuidString) ?? UUID(),
                email: email,
                selectedPath: nil,
                displayName: nil,
                onboardingCompleted: false,
                streak: 0,
                totalJournalEntries: 0,
                createdAt: Date(),
                updatedAt: Date()
            )
            
            try await supabase
                .from("profiles")
                .insert(profileData)
                .execute()
            
            // Handle successful auth
            await handleSuccessfulAuth(session)
            
            isLoading = false
            return true
            
        } catch {
            errorMessage = mapSupabaseError(error)
            isLoading = false
            return false
        }
    }
    
    // MARK: - Sign In
    func signIn(email: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            
            await handleSuccessfulAuth(session)
            
            isLoading = false
            return true
            
        } catch {
            errorMessage = mapSupabaseError(error)
            isLoading = false
            return false
        }
    }
    
    // MARK: - Sign Out
    func signOut() async {
        isLoading = true
        
        do {
            try await supabase.auth.signOut()
            await handleSignOut()
        } catch {
            // Even if remote signout fails, clear local state
            await handleSignOut()
        }
        
        isLoading = false
    }
    
    // MARK: - Update User Path
    func updateUserPath(_ path: UserPath) async -> Bool {
        guard let currentUser = currentUser else { return false }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabase
                .from("profiles")
                .update([
                    "selected_path": path.rawValue,
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: currentUser.id.uuidString)
                .execute()
            
            // Update local user
            var updatedUser = currentUser
            updatedUser.selectedPath = path
            self.currentUser = updatedUser
            
            isLoading = false
            return true
            
        } catch {
            errorMessage = mapSupabaseError(error)
            isLoading = false
            return false
        }
    }
    
    // MARK: - Complete Onboarding
    func completeOnboarding() async -> Bool {
        guard let currentUser = currentUser else { return false }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabase
                .from("profiles")
                .update([
                    "onboarding_completed": true,
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: currentUser.id.uuidString)
                .execute()
            
            // Update local user
            var updatedUser = currentUser
            updatedUser.onboardingCompleted = true
            self.currentUser = updatedUser
            
            isLoading = false
            return true
            
        } catch {
            errorMessage = mapSupabaseError(error)
            isLoading = false
            return false
        }
    }
    
    // MARK: - Update Display Name
    func updateDisplayName(_ displayName: String) async -> Bool {
        guard let currentUser = currentUser else { return false }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabase
                .from("profiles")
                .update([
                    "display_name": displayName,
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: currentUser.id.uuidString)
                .execute()
            
            // Update local user
            var updatedUser = currentUser
            updatedUser.displayName = displayName
            self.currentUser = updatedUser
            
            isLoading = false
            return true
            
        } catch {
            errorMessage = mapSupabaseError(error)
            isLoading = false
            return false
        }
    }
    
    // MARK: - Update Streak
    func updateStreak(_ newStreak: Int) async -> Bool {
        guard let currentUser = currentUser else { return false }
        
        do {
            try await supabase
                .from("profiles")
                .update([
                    "streak": newStreak,
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: currentUser.id.uuidString)
                .execute()
            
            // Update local user
            var updatedUser = currentUser
            updatedUser.streak = newStreak
            self.currentUser = updatedUser
            
            return true
            
        } catch {
            errorMessage = mapSupabaseError(error)
            return false
        }
    }
    
    // MARK: - Private Helper Methods
    private func handleSuccessfulAuth(_ session: Session) async {
        let authSession = AuthSession(from: session)
        
        // Store session
        storeAuthSession(authSession)
        
        // Update state
        self.authSession = authSession
        self.isAuthenticated = true
        
        // Load user profile
        await loadUserProfile()
    }
    
    private func handleSignOut() async {
        // Clear stored session
        UserDefaults.standard.removeObject(forKey: "obex_auth_session")
        
        // Clear state
        self.authSession = nil
        self.currentUser = nil
        self.isAuthenticated = false
        self.errorMessage = nil
    }
    
    private func updateSession(_ session: Session) async {
        let authSession = AuthSession(from: session)
        storeAuthSession(authSession)
        self.authSession = authSession
    }
    
    private func loadUserProfile() async {
        guard let session = authSession else { return }
        
        do {
            // Get current user from auth
            let user = try await supabase.auth.user()
            
            // Get user profile from database
            let profileResponse: [UserProfileDB] = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: user.id.uuidString)
                .execute()
                .value
            
            let profile = profileResponse.first
            let userProfile = UserProfile(from: user, profile: profile)
            
            self.currentUser = userProfile
            
        } catch {
            errorMessage = mapSupabaseError(error)
            // If profile load fails, sign out
            await signOut()
        }
    }
    
    private func storeAuthSession(_ session: AuthSession) {
        do {
            let data = try JSONEncoder().encode(session)
            UserDefaults.standard.set(data, forKey: "obex_auth_session")
        } catch {
            print("Failed to store auth session: \(error)")
        }
    }
    
    private func mapSupabaseError(_ error: Error) -> String {
        // Map Supabase-specific errors to user-friendly messages
        if let authError = error as? AuthError {
            return authError.localizedDescription
        }
        
        let errorString = error.localizedDescription.lowercased()
        
        if errorString.contains("invalid login credentials") {
            return "Invalid email or password"
        } else if errorString.contains("email not confirmed") {
            return "Please check your email and confirm your account"
        } else if errorString.contains("user already registered") {
            return "An account with this email already exists"
        } else if errorString.contains("weak password") {
            return "Password must be at least 6 characters"
        } else if errorString.contains("network") || errorString.contains("connection") {
            return "Network connection error. Please try again."
        } else {
            return "Something went wrong. Please try again."
        }
    }
}

// MARK: - Authentication Errors
enum AuthError: LocalizedError {
    case invalidCredentials
    case networkError
    case userNotFound
    case weakPassword
    case emailAlreadyExists
    case emailNotConfirmed
    case sessionExpired
    case registrationFailed
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError:
            return "Network connection error"
        case .userNotFound:
            return "User not found"
        case .weakPassword:
            return "Password must be at least 6 characters"
        case .emailAlreadyExists:
            return "Email already registered"
        case .emailNotConfirmed:
            return "Please check your email and confirm your account"
        case .sessionExpired:
            return "Session expired. Please sign in again"
        case .registrationFailed:
            return "Registration failed. Please try again."
        case .unknown(let message):
            return message
        }
    }
}