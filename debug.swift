import SwiftUI

// MARK: - Step 1: Add this to find the source
extension View {
    func debugNaN(_ label: String) -> some View {
        self.onAppear {
            print("🔍 \(label) appeared - checking for NaN issues")
        }
    }
}

// MARK: - Step 2: Fix your LaunchView (most likely culprit)
struct FixedLaunchView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.0
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 8) {
                Text("OBEX")
                    .font(Themes.Typography.launchTitle)
                    .foregroundColor(.white)
                    .scaleEffect(validateScale(logoScale))
                    .opacity(validateOpacity(logoOpacity))
                    .debugNaN("OBEX Title")
                
                Text("Elite Self-Discipline")
                    .font(Themes.Typography.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .opacity(validateOpacity(logoOpacity))
                    .debugNaN("OBEX Subtitle")
            }
        }
        .onAppear {
            // Add validation before animation
            print("🎬 Starting launch animation")
            
            withAnimation(.spring(response: 1.0, dampingFraction: 0.6).delay(0.2)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
        }
    }
    
    // Validation functions
    private func validateScale(_ value: CGFloat) -> CGFloat {
        if value.isNaN || value.isInfinite || value <= 0 {
            print("❌ Invalid scale: \(value), using 1.0")
            return 1.0
        }
        return value
    }
    
    private func validateOpacity(_ value: Double) -> Double {
        if value.isNaN || value.isInfinite || value < 0 {
            print("❌ Invalid opacity: \(value), using 1.0")
            return 1.0
        }
        return min(1.0, max(0.0, value))
    }
}

// MARK: - Step 3: Check your Themes for invalid values
extension Themes.Typography {
    static func validateFont(_ font: Font) -> Font {
        // If custom fonts fail to load, they can cause NaN issues
        // Fall back to system fonts
        return font // or return Font.system(.title) as fallback
    }
}

// MARK: - Step 4: Fix common animation issues
struct SafeAnimationWrapper<Content: View>: View {
    let content: Content
    @State private var isVisible = false
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.95)
            .onAppear {
                // Delay prevents NaN on immediate animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isVisible = true
                    }
                }
            }
    }
}

// MARK: - Step 5: Quick replacement for your EntryPoint
@main
struct FixedObexApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var supabaseService = SupabaseService()
    @State private var isLaunching = true
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isLaunching {
                    FixedLaunchView()
                        .debugNaN("LaunchView")
                        .onAppear {
                            print("🚀 App launched")
                            
                            // Simple delay without complex animations
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                print("🎯 Transitioning from launch")
                                isLaunching = false
                            }
                        }
                } else if supabaseService.isAuthenticated {
                    Text("Main App")
                        .debugNaN("MainApp")
                        .environmentObject(supabaseService)
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                } else {
                    Text("Onboarding")
                        .debugNaN("Onboarding")
                        .environmentObject(supabaseService)
                }
            }
            // Simplified animations
            .animation(.easeInOut(duration: 0.4), value: isLaunching)
            .animation(.easeInOut(duration: 0.4), value: supabaseService.isAuthenticated)
        }
    }
}
