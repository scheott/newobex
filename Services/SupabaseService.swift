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
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case createdAt = "created_at"
        case selectedPath = "selected_path"
        case displayName = "display_name"
        case onboardingCompleted = "onboarding_completed"
        case streak
        case totalJournalEntries = "total_journal_entries"
        case updatedAt = "updated_at"
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
    private var supabase: SupabaseClient
    private var authStateTask: Task<Void, Never>?
    
    // MARK: - Configuration
    private let supabaseURL = "https://your-project.supabase.co" // Replace with your URL
    private let supabaseKey = "your-anon-key" // Replace with your anon key
    
    // MARK: - Initialization
    init() {
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: supabaseURL)!,
            supabaseKey: supabaseKey
        )
        
        startAuthStateListener()
    }
    
    deinit {
        authStateTask?.cancel()
    }
    
    // MARK: - Auth State Listener
    private func startAuthStateListener() {
        authStateTask = Task {
            for await state in supabase.auth.authStateChanges {
                await handleAuthStateChange(state)
            }
        }
    }
    
    private func handleAuthStateChange(_ state: AuthState) async {
        switch state.event {
        case .signedIn:
            if let user = state.session?.user {
                isAuthenticated = true
                await loadUserProfile(userId: user.id)
            }
        case .signedOut:
            isAuthenticated = false
            currentUser = nil
        case .tokenRefreshed:
            if let user = state.session?.user {
                await loadUserProfile(userId: user.id)
            }
        default:
            break
        }
    }
    
    // MARK: - Sign Up
    func signUp(email: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password
            )
            
            if let user = response.user {
                // User profile will be created automatically via database trigger
                isLoading = false
                return true
            } else {
                errorMessage = "Sign up failed - please check your email for confirmation"
                isLoading = false
                return false
            }
            
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
            try await supabase.auth.signIn(
                email: email,
                password: password
            )
            
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
            
            // State will be updated via auth state listener
            isLoading = false
            
        } catch {
            errorMessage = "Sign out failed"
            isLoading = false
        }
    }
    
    // MARK: - Update User Path
    func updateUserPath(_ path: UserPath) async -> Bool {
        guard let currentUser = currentUser else { return false }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let updatedProfile: UserProfile = try await supabase.database
                .from("user_profiles")
                .update([
                    "selected_path": path.rawValue,
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: currentUser.id)
                .select()
                .single()
                .execute()
                .value
            
            self.currentUser = updatedProfile
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
            let updatedProfile: UserProfile = try await supabase.database
                .from("user_profiles")
                .update([
                    "onboarding_completed": true,
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: currentUser.id)
                .select()
                .single()
                .execute()
                .value
            
            self.currentUser = updatedProfile
            isLoading = false
            return true
            
        } catch {
            errorMessage = mapSupabaseError(error)
            isLoading = false
            return false
        }
    }
    
    // MARK: - Update Display Name
    func updateDisplayName(_ name: String) async -> Bool {
        guard let currentUser = currentUser else { return false }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let updatedProfile: UserProfile = try await supabase.database
                .from("user_profiles")
                .update([
                    "display_name": name,
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: currentUser.id)
                .select()
                .single()
                .execute()
                .value
            
            self.currentUser = updatedProfile
            isLoading = false
            return true
            
        } catch {
            errorMessage = mapSupabaseError(error)
            isLoading = false
            return false
        }
    }
    
    // MARK: - Load User Profile
    private func loadUserProfile(userId: UUID) async {
        do {
            let profile: UserProfile = try await supabase.database
                .from("user_profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            self.currentUser = profile
            
        } catch {
            errorMessage = mapSupabaseError(error)
            // If profile load fails, sign out
            await signOut()
        }
    }
    
    // MARK: - Password Reset
    func resetPassword(email: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabase.auth.resetPasswordForEmail(email)
            isLoading = false
            return true
            
        } catch {
            errorMessage = mapSupabaseError(error)
            isLoading = false
            return false
        }
    }
    
    // MARK: - Error Mapping
    private func mapSupabaseError(_ error: Error) -> String {
        if let authError = error as? AuthError {
            switch authError {
            case .invalidCredentials:
                return "Invalid email or password"
            case .signUpDisabled:
                return "Sign up is currently disabled"
            case .emailNotConfirmed:
                return "Please check your email and confirm your account"
            case .tooManyRequests:
                return "Too many attempts. Please try again later"
            case .weakPassword:
                return "Password must be at least 6 characters"
            default:
                return authError.localizedDescription
            }
        }
        
        // Handle network and other errors
        if error.localizedDescription.contains("network") {
            return "Network connection error. Please check your internet connection"
        }
        
        if error.localizedDescription.contains("email") && error.localizedDescription.contains("already") {
            return "This email is already registered"
        }
        
        return error.localizedDescription
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
    case signUpDisabled
    case emailNotConfirmed
    case tooManyRequests
    
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
        case .signUpDisabled:
            return "Sign up is currently disabled"
        case .emailNotConfirmed:
            return "Please confirm your email address"
        case .tooManyRequests:
            return "Too many requests. Please try again later"
        }
    }
}
