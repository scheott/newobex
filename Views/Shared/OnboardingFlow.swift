import SwiftUI

struct OnboardingFlow: View {
    @EnvironmentObject private var supabaseService: SupabaseService
    @State private var currentStep: OnboardingStep = .intro
    @State private var selectedPath: UserPath?
    @State private var displayName: String = ""
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            // Content
            VStack {
                switch currentStep {
                case .intro:
                    IntroView(onContinue: {
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                            currentStep = .pathSelection
                        }
                    })
                    
                case .pathSelection:
                    PathSelectionView(
                        selectedPath: $selectedPath,
                        onContinue: {
                            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                                currentStep = .nameInput
                            }
                        }
                    )
                    
                case .nameInput:
                    if let path = selectedPath {
                        NameInputView(
                            displayName: $displayName,
                            selectedPath: path,
                            isLoading: $isLoading,
                            onComplete: completeOnboarding
                        )
                    } else {
                        VStack {
                            Text("Error: Path not selected.")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }

            }
        }
        .animation(.spring(response: 0.8, dampingFraction: 0.8), value: currentStep)
    }
    
    private func completeOnboarding() async {
        guard let selectedPath = selectedPath else { return }
        
        isLoading = true
        
        // Update user path
        let pathSuccess = await supabaseService.updateUserPath(selectedPath)
        guard pathSuccess else {
            isLoading = false
            return
        }
        
        // Update display name if provided
        if !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let nameSuccess = await supabaseService.updateDisplayName(displayName)
            guard nameSuccess else {
                isLoading = false
                return
            }
        }
        
        // Complete onboarding
        let onboardingSuccess = await supabaseService.completeOnboarding()
        guard onboardingSuccess else {
            isLoading = false
            print("Failed to complete onboarding")
            return
        }
        
        // Reload user profile to ensure navigation triggers
        await supabaseService.loadUserProfile()
        
        isLoading = false
    }
}

// MARK: - Onboarding Steps
enum OnboardingStep {
    case intro
    case pathSelection
    case nameInput
}

// MARK: - Intro View
struct IntroView: View {
    let onContinue: () -> Void
    @State private var textOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    
    var body: some View {
        VStack(spacing: Themes.Spacing.xxl) {
            Spacer()
            
            // Logo
            VStack(spacing: Themes.Spacing.sm) {
                Text("OBEX")
                    .font(Themes.Typography.launchTitle)
                    .foregroundColor(.white)
                
                Text("Elite Self-Discipline")
                    .font(Themes.Typography.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .opacity(textOpacity)
            
            Spacer()
            
            // Description
            VStack(spacing: Themes.Spacing.lg) {
                Text("Obex is not a productivity app.")
                    .font(Themes.Typography.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("It's a companion for those becoming someone rare.")
                    .font(Themes.Typography.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Themes.Spacing.xl)
            .opacity(textOpacity)
            
            Spacer()
            
            // Continue Button
            Button(action: onContinue) {
                Text("Begin Your Path")
                    .font(Themes.Typography.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: Themes.CornerRadius.button))
            }
            .padding(.horizontal, Themes.Spacing.xl)
            .opacity(buttonOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.5)) {
                textOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(1.2)) {
                buttonOpacity = 1.0
            }
        }
    }
}

// MARK: - Path Selection View
struct PathSelectionView: View {
    @Binding var selectedPath: UserPath?
    let onContinue: () -> Void
    @State private var cardsOpacity: Double = 0
    
    var body: some View {
        VStack(spacing: Themes.Spacing.xl) {
            // Header
            VStack(spacing: Themes.Spacing.md) {
                Text("Choose Your Path")
                    .font(Themes.Typography.largeTitle)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Who are you becoming?")
                    .font(Themes.Typography.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Themes.Spacing.xl)
            .opacity(cardsOpacity)
            
            // Path Cards
            VStack(spacing: Themes.Spacing.lg) {
                ForEach(UserPath.allCases, id: \.self) { path in
                    PathCard(
                        path: path,
                        isSelected: selectedPath == path,
                        onTap: {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                selectedPath = path
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, Themes.Spacing.xl)
            .opacity(cardsOpacity)
            
            Spacer()
            
            // Continue Button
            if selectedPath != nil {
                Button(action: onContinue) {
                    Text("Continue")
                        .font(Themes.Typography.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: Themes.CornerRadius.button))
                }
                .padding(.horizontal, Themes.Spacing.xl)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                cardsOpacity = 1.0
            }
        }
    }
}

// MARK: - Path Card
struct PathCard: View {
    let path: UserPath
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Themes.Spacing.lg) {
                // Icon
                Image(systemName: path.icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(isSelected ? path.colors.primary : .white.opacity(0.6))
                    .frame(width: 50)
                
                // Content
                VStack(alignment: .leading, spacing: Themes.Spacing.xs) {
                    Text(path.displayName)
                        .font(Themes.Typography.headline)
                        .foregroundColor(isSelected ? .white : .white.opacity(0.9))
                    
                    Text(path.description)
                        .font(Themes.Typography.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .white.opacity(0.6))
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding(Themes.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Themes.CornerRadius.card)
                    .fill(isSelected ? path.colors.primary.opacity(0.2) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: Themes.CornerRadius.card)
                            .stroke(
                                isSelected ? path.colors.primary : Color.white.opacity(0.1),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .shadow(color: isSelected ? path.colors.primary.opacity(0.4) : .clear, radius: 6)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
    }
}

// MARK: - Name Input View
struct NameInputView: View {
    @Binding var displayName: String
    let selectedPath: UserPath
    @Binding var isLoading: Bool
    let onComplete: () async -> Void
    
    @State private var contentOpacity: Double = 0
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: Themes.Spacing.xl) {
            Spacer()
            
            // Header
            VStack(spacing: Themes.Spacing.md) {
                // Path confirmation with icon
                HStack(spacing: Themes.Spacing.sm) {
                    Image(systemName: selectedPath.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(selectedPath.colors.primary)
                    
                    Text("Path: \(selectedPath.displayName)")
                        .font(Themes.Typography.headline)
                        .foregroundColor(.white)
                }
                
                Text("How would you like to be addressed?")
                    .font(Themes.Typography.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                Text("(Optional)")
                    .font(Themes.Typography.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            .opacity(contentOpacity)
            
            // Name Input
            VStack(spacing: Themes.Spacing.md) {
                TextField("Enter your name", text: $displayName)
                    .font(Themes.Typography.body)
                    .foregroundColor(.white)
                    .padding(Themes.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: Themes.CornerRadius.button)
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: Themes.CornerRadius.button)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .focused($isTextFieldFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        Task {
                            await onComplete()
                        }
                    }
            }
            .padding(.horizontal, Themes.Spacing.xl)
            .opacity(contentOpacity)
            
            Spacer()
            
            // Complete Button
            Button(action: {
                Task {
                    await onComplete()
                }
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .scaleEffect(0.8)
                    }
                    
                    Text(isLoading ? "Setting up your path..." : "Complete Setup")
                        .font(Themes.Typography.headline)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: Themes.CornerRadius.button))
            }
            .disabled(isLoading)
            .padding(.horizontal, Themes.Spacing.xl)
            .opacity(contentOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                contentOpacity = 1.0
            }
            
            // Auto-focus the text field after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                isTextFieldFocused = true
            }
        }
    }
}

// MARK: - Preview
struct OnboardingFlow_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingFlow()
            .environmentObject(SupabaseService())
    }
}
