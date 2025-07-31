import Foundation
import Combine

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
    private let baseURL = "YOUR_SUPABASE_URL" // Replace with actual URL
    private let apiKey = "YOUR_SUPABASE_ANON_KEY" // Replace with actual key
    
    // MARK: - Initialization
    init() {
        checkAuthenticationState()
    }
    
    // MARK: - Authentication State Check
    private func checkAuthenticationState() {
        // Check for stored session in UserDefaults or Keychain
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
            let result = try await performSignUp(email: email, password: password)
            
            // Store session
            storeAuthSession(result.session)
            
            // Update state
            self.authSession = result.session
            self.currentUser = result.user
            self.isAuthenticated = true
            
            isLoading = false
            return true
            
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    // MARK: - Sign In
    func signIn(email: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await performSignIn(email: email, password: password)
            
            // Store session
            storeAuthSession(result.session)
            
            // Update state
            self.authSession = result.session
            self.currentUser = result.user
            self.isAuthenticated = true
            
            isLoading = false
            return true
            
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    // MARK: - Sign Out
    func signOut() async {
        isLoading = true
        
        // Clear stored session
        UserDefaults.standard.removeObject(forKey: "obex_auth_session")
        
        // Clear state
        self.authSession = nil
        self.currentUser = nil
        self.isAuthenticated = false
        self.errorMessage = nil
        
        isLoading = false
    }
    
    // MARK: - Update User Path
    func updateUserPath(_ path: UserPath) async -> Bool {
        guard let currentUser = currentUser else { return false }
        
        isLoading = true
        
        do {
            let updatedUser = try await performUpdateUserPath(userId: currentUser.id, path: path)
            self.currentUser = updatedUser
            isLoading = false
            return true
            
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    // MARK: - Complete Onboarding
    func completeOnboarding() async -> Bool {
        guard let currentUser = currentUser else { return false }
        
        isLoading = true
        
        do {
            let updatedUser = try await performCompleteOnboarding(userId: currentUser.id)
            self.currentUser = updatedUser
            isLoading = false
            return true
            
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    // MARK: - Load User Profile
    private func loadUserProfile() async {
        guard let session = authSession else { return }
        
        do {
            let user = try await performLoadUserProfile(session: session)
            self.currentUser = user
            
        } catch {
            errorMessage = error.localizedDescription
            // If profile load fails, sign out
            await signOut()
        }
    }
    
    // MARK: - Private API Methods
    private func performSignUp(email: String, password: String) async throws -> AuthResult {
        // Simulate API call - replace with actual Supabase implementation
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        // Mock successful response - replace with actual Supabase auth
        let user = UserProfile(
            id: UUID(),
            email: email,
            createdAt: Date(),
            selectedPath: nil,
            displayName: nil,
            onboardingCompleted: false,
            streak: 0,
            totalJournalEntries: 0
        )
        
        let session = AuthSession(
            accessToken: "mock_access_token",
            refreshToken: "mock_refresh_token",
            expiresAt: Date().addingTimeInterval(3600) // 1 hour
        )
        
        return AuthResult(user: user, session: session)
    }
    
    private func performSignIn(email: String, password: String) async throws -> AuthResult {
        // Simulate API call - replace with actual Supabase implementation
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        // Mock returning user - replace with actual Supabase auth
        let user = UserProfile(
            id: UUID(),
            email: email,
            createdAt: Date().addingTimeInterval(-86400), // Created yesterday
            selectedPath: .confidence,
            displayName: "Elite User",
            onboardingCompleted: true,
            streak: 5,
            totalJournalEntries: 12
        )
        
        let session = AuthSession(
            accessToken: "mock_access_token",
            refreshToken: "mock_refresh_token",
            expiresAt: Date().addingTimeInterval(3600) // 1 hour
        )
        
        return AuthResult(user: user, session: session)
    }
    
    private func performLoadUserProfile(session: AuthSession) async throws -> UserProfile {
        // Simulate API call - replace with actual Supabase implementation
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        return UserProfile(
            id: UUID(),
            email: "user@example.com",
            createdAt: Date().addingTimeInterval(-86400),
            selectedPath: .confidence,
            displayName: "Elite User",
            onboardingCompleted: true,
            streak: 5,
            totalJournalEntries: 12
        )
    }
    
    private func performUpdateUserPath(userId: UUID, path: UserPath) async throws -> UserProfile {
        // Simulate API call - replace with actual Supabase implementation
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        var updatedUser = currentUser!
        updatedUser.selectedPath = path
        
        return updatedUser
    }
    
    private func performCompleteOnboarding(userId: UUID) async throws -> UserProfile {
        // Simulate API call - replace with actual Supabase implementation
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        var updatedUser = currentUser!
        updatedUser.onboardingCompleted = true
        
        return updatedUser
    }
    
    // MARK: - Session Storage
    private func storeAuthSession(_ session: AuthSession) {
        do {
            let data = try JSONEncoder().encode(session)
            UserDefaults.standard.set(data, forKey: "obex_auth_session")
        } catch {
            print("Failed to store auth session: \(error)")
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
    case sessionExpired
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError:
            return "Network connection error"
        case .userNotFound:
            return "User not found"
        case .weakPassword:
            return "Password must be at least 8 characters"
        case .emailAlreadyExists:
            return "Email already registered"
        case .sessionExpired:
            return "Session expired. Please sign in again"
        }
    }
}