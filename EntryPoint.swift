import SwiftUI
import CoreData

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
                        .onAppear {
                            // Simulate launch delay for premium feel
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation(.easeInOut(duration: 0.6)) {
                                    isLaunching = false
                                }
                            }
                        }
                } else if supabaseService.isAuthenticated {
                    MainTabView()
                        .environmentObject(supabaseService)
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else {
                    OnboardingFlow()
                        .environmentObject(supabaseService)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .animation(.spring(response: 0.8, dampingFraction: 0.8), value: isLaunching)
            .animation(.spring(response: 0.8, dampingFraction: 0.8), value: supabaseService.isAuthenticated)
        }
    }
}

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
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                
                Text("Elite Self-Discipline")
                    .font(Themes.Typography.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .opacity(logoOpacity)
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

struct MainTabView: View {
    var body: some View {
        Text("Testingggg")
        
    }
}

struct OnboardingFlow: View {
    var body: some View {
        Text("Testingggg again typ shi")
        
    }
}
