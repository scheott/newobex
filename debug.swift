import SwiftUI
import CoreData

// MARK: - Entry Point
@main
struct ObexApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var supabaseService = SupabaseService()
    @State private var isLaunching = true
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isLaunching {
                    LaunchView()
                        .debugNaN("LaunchView")
                        .onAppear {
                            print("🚀 Launching Obex...")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation(.easeInOut(duration: 0.6)) {
                                    isLaunching = false
                                }
                            }
                        }
                } else if supabaseService.isAuthenticated,
                          supabaseService.currentUser?.onboardingCompleted == true {
                    MainTabView()
                        .environmentObject(supabaseService)
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .debugNaN("MainTabView")
                } else if supabaseService.isAuthenticated {
                    OnboardingFlow()
                        .environmentObject(supabaseService)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .debugNaN("OnboardingFlow (Post-Auth)")
                } else {
                    OnboardingFlow()
                        .environmentObject(supabaseService)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .debugNaN("OnboardingFlow (Pre-Auth)")
                }
            }
            .animation(.spring(response: 0.8, dampingFraction: 0.8), value: isLaunching)
            .animation(.spring(response: 0.8, dampingFraction: 0.8), value: supabaseService.isAuthenticated)
        }
    }
}

// MARK: - Launch View
// EntryPoint.swift

import SwiftUI

// MARK: - Launch View
struct LaunchView: View {
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
                    .safeScale(logoScale)
                    .safeOpacity(logoOpacity)

                Text("Elite Self-Discipline")
                    .font(Themes.Typography.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .safeOpacity(logoOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.6).delay(0.2)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
        }
    }
}


    // MARK: - Validation Helpers
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

// MARK: - Debug NaN View Modifier
extension View {
    func debugNaN(_ label: String) -> some View {
        self.onAppear {
            print("🔍 \(label) appeared")
        }
    }
}

// MARK: - Core Data Persistence Controller
class PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "ObexModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Core Data error: \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Save error: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

import SwiftUI

extension View {
    func safeScale(_ scale: CGFloat) -> some View {
        self.scaleEffect(scale.isFinite ? scale : 1.0)
    }

    func safeOpacity(_ opacity: Double) -> some View {
        self.opacity(opacity.isFinite ? opacity : 1.0)
    }
}

