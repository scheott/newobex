import SwiftUI

struct Themes {
    
    // MARK: - Colors
    struct Colors {
        
        // MARK: Confidence Path - Warm, Open, Social
        struct Confidence {
            static let primary = Color(hex: "C19A6B")      // Warm bronze
            static let secondary = Color(hex: "E5D3C5")    // Soft ivory
            static let accent = Color(hex: "D4AF37")       // Subtle gold
            static let background = Color(hex: "FEFCF8")   // Warm white
            static let cardBackground = Color(hex: "F7F3ED") // Warm card
            static let text = Color(hex: "4A3B2E")         // Dark brown
            static let textSecondary = Color(hex: "8B7355") // Medium brown
        }
        
        // MARK: Clarity Path - Clean, Intellectual, Focused
        struct Clarity {
            static let primary = Color(hex: "6B7280")      // Cool gray
            static let secondary = Color(hex: "F3F4F6")    // Light gray
            static let accent = Color(hex: "3B82F6")       // Subtle blue
            static let background = Color(hex: "FFFFFF")   // Pure white
            static let cardBackground = Color(hex: "F9FAFB") // Glass-like
            static let text = Color(hex: "111827")         // Near black
            static let textSecondary = Color(hex: "6B7280") // Medium gray
        }
        
        // MARK: Discipline Path - Dark, Intense, Powerful
        struct Discipline {
            static let primary = Color(hex: "B00020")      // Blood red
            static let secondary = Color(hex: "2D2D2D")    // Dark slate
            static let accent = Color(hex: "FF1744")       // Bright red
            static let background = Color(hex: "0A0A0A")   // Deep black
            static let cardBackground = Color(hex: "1A1A1A") // Card black
            static let text = Color(hex: "FFFFFF")         // Pure white
            static let textSecondary = Color(hex: "CCCCCC") // Light gray
        }
        
        // MARK: Shared/Universal Colors
        static let black = Color(hex: "000000")
        static let white = Color(hex: "FFFFFF")
        static let error = Color(hex: "DC2626")
        static let success = Color(hex: "16A34A")
        static let warning = Color(hex: "F59E0B")
    }
    
    // MARK: - Typography
    struct Typography {
        
        // MARK: Launch & Branding
        static let launchTitle = Font.custom("SF Pro Display", size: 48)
            .weight(.black)
        
        // MARK: Confidence Path Typography
        struct Confidence {
            static let title = Font.custom("SF Pro Rounded", size: 32)
                .weight(.bold)
            static let headline = Font.custom("SF Pro Rounded", size: 24)
                .weight(.semibold)
            static let body = Font.custom("SF Pro Rounded", size: 16)
                .weight(.medium)
            static let caption = Font.custom("SF Pro Rounded", size: 14)
                .weight(.regular)
        }
        
        // MARK: Clarity Path Typography
        struct Clarity {
            static let title = Font.custom("New York", size: 32)
                .weight(.bold)
            static let headline = Font.custom("New York", size: 24)
                .weight(.semibold)
            static let body = Font.custom("Georgia", size: 16)
                .weight(.regular)
            static let caption = Font.custom("Georgia", size: 14)
                .weight(.regular)
        }
        
        // MARK: Discipline Path Typography
        struct Discipline {
            static let title = Font.custom("SF Pro Display", size: 32)
                .weight(.black)
            static let headline = Font.custom("SF Compact", size: 24)
                .weight(.bold)
            static let body = Font.custom("SF Compact", size: 16)
                .weight(.semibold)
            static let caption = Font.custom("SF Compact", size: 14)
                .weight(.medium)
        }
        
        // MARK: Universal Typography
        static let largeTitle = Font.system(size: 36, weight: .bold, design: .default)
        static let title = Font.system(size: 28, weight: .semibold, design: .default)
        static let headline = Font.system(size: 20, weight: .medium, design: .default)
        static let body = Font.system(size: 16, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
        static let card: CGFloat = 20
        static let button: CGFloat = 16
    }
    
    // MARK: - Shadows
    struct Shadow {
        static let light = Color.black.opacity(0.1)
        static let medium = Color.black.opacity(0.2)
        static let heavy = Color.black.opacity(0.3)
        
        static let cardShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = 
            (light, 8, 0, 4)
        static let buttonShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = 
            (medium, 4, 0, 2)
    }
    
    // MARK: - Animations
    struct Animation {
        static let spring = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.8)
        static let easeIn = SwiftUI.Animation.easeIn(duration: 0.3)
        static let easeOut = SwiftUI.Animation.easeOut(duration: 0.3)
        static let easeInOut = SwiftUI.Animation.easeInOut(duration: 0.4)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.8)
    }
}

// MARK: - Path-Based Theme Provider
enum UserPath: String, CaseIterable {
    case confidence = "confidence"
    case clarity = "clarity"
    case discipline = "discipline"
    
    var colors: (primary: Color, secondary: Color, accent: Color, background: Color, cardBackground: Color, text: Color, textSecondary: Color) {
        switch self {
        case .confidence:
            return (
                Themes.Colors.Confidence.primary,
                Themes.Colors.Confidence.secondary,
                Themes.Colors.Confidence.accent,
                Themes.Colors.Confidence.background,
                Themes.Colors.Confidence.cardBackground,
                Themes.Colors.Confidence.text,
                Themes.Colors.Confidence.textSecondary
            )
        case .clarity:
            return (
                Themes.Colors.Clarity.primary,
                Themes.Colors.Clarity.secondary,
                Themes.Colors.Clarity.accent,
                Themes.Colors.Clarity.background,
                Themes.Colors.Clarity.cardBackground,
                Themes.Colors.Clarity.text,
                Themes.Colors.Clarity.textSecondary
            )
        case .discipline:
            return (
                Themes.Colors.Discipline.primary,
                Themes.Colors.Discipline.secondary,
                Themes.Colors.Discipline.accent,
                Themes.Colors.Discipline.background,
                Themes.Colors.Discipline.cardBackground,
                Themes.Colors.Discipline.text,
                Themes.Colors.Discipline.textSecondary
            )
        }
    }
    
    var typography: (title: Font, headline: Font, body: Font, caption: Font) {
        switch self {
        case .confidence:
            return (
                Themes.Typography.Confidence.title,
                Themes.Typography.Confidence.headline,
                Themes.Typography.Confidence.body,
                Themes.Typography.Confidence.caption
            )
        case .clarity:
            return (
                Themes.Typography.Clarity.title,
                Themes.Typography.Clarity.headline,
                Themes.Typography.Clarity.body,
                Themes.Typography.Clarity.caption
            )
        case .discipline:
            return (
                Themes.Typography.Discipline.title,
                Themes.Typography.Discipline.headline,
                Themes.Typography.Discipline.body,
                Themes.Typography.Discipline.caption
            )
        }
    }
    
    var displayName: String {
        switch self {
        case .confidence: return "Confidence"
        case .clarity: return "Clarity"
        case .discipline: return "Discipline"
        }
    }
    
    var description: String {
        switch self {
        case .confidence: return "Self-expression, presence, charisma, social fluidity"
        case .clarity: return "Stillness, logic, journaling, intentional thought"
        case .discipline: return "Willpower, endurance, challenge, grit"
        }
    }
    
    var icon: String {
        switch self {
        case .confidence: return "person.crop.circle.fill"
        case .clarity: return "book.closed.fill"
        case .discipline: return "flame.fill"
        }
    }
}

// MARK: - Color Extension for Hex Support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}