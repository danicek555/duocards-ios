import SwiftUI

enum DuoColors {
    static let gray50 = Color(hex: 0xF7F9FC)
    static let gray100 = Color(hex: 0xEEF2F8)
    static let gray200 = Color(hex: 0xDFE6F0)
    static let gray400 = Color(hex: 0x94A5C0)
    static let gray500 = Color(hex: 0x64748F)
    static let gray700 = Color(hex: 0x334059)
    static let gray800 = Color(hex: 0x1D2739)
    static let gray900 = Color(hex: 0x12192B)
    static let gray950 = Color(hex: 0x0A0F1E)

    static let indigo50 = Color(hex: 0xEEF2FF)
    static let indigo200 = Color(hex: 0xC7D2FE)
    static let indigo400 = Color(hex: 0x818CF8)
    static let indigo500 = Color(hex: 0x6366F1)
    static let indigo600 = Color(hex: 0x4F46E5)
    static let indigo700 = Color(hex: 0x4338CA)

    static let violet100 = Color(hex: 0xEDE9FE)
    static let violet400 = Color(hex: 0xA78BFA)
    static let violet600 = Color(hex: 0x7C3AED)
    static let emerald500 = Color(hex: 0x10B981)
    static let emerald600 = Color(hex: 0x059669)
    static let amber500 = Color(hex: 0xF59E0B)
    static let red500 = Color(hex: 0xEF4444)

    static let brandGradient = LinearGradient(
        colors: [violet600, indigo600],
        startPoint: .leading,
        endPoint: .trailing
    )

    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark ? gray950 : gray50
    }

    static func surface(for scheme: ColorScheme) -> Color {
        scheme == .dark ? gray800 : .white
    }

    static func primaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? gray100 : gray900
    }

    static func secondaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? gray400 : gray500
    }

    static func border(for scheme: ColorScheme) -> Color {
        scheme == .dark ? gray700 : gray200
    }
}

enum DuoSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum DuoRadius {
    static let small: CGFloat = 10
    static let medium: CGFloat = 14
    static let large: CGFloat = 20
    static let hero: CGFloat = 28
}

private struct DuoCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(DuoColors.surface(for: colorScheme).opacity(0.94))
            .clipShape(RoundedRectangle(cornerRadius: DuoRadius.large))
            .overlay {
                RoundedRectangle(cornerRadius: DuoRadius.large)
                    .stroke(DuoColors.border(for: colorScheme), lineWidth: 1)
            }
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.08),
                radius: 16,
                y: 8
            )
    }
}

extension View {
    func duoCard(padding: CGFloat = DuoSpacing.lg) -> some View {
        modifier(DuoCardModifier(padding: padding))
    }
}

struct DuoBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            DuoColors.background(for: colorScheme)
            LinearGradient(
                colors: colorScheme == .dark
                    ? [DuoColors.gray950, DuoColors.gray900]
                    : [DuoColors.indigo50, DuoColors.indigo200.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [
                    DuoColors.violet400.opacity(colorScheme == .dark ? 0.08 : 0.14),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 440
            )
        }
        .ignoresSafeArea()
    }
}

struct DuoBrandMark: View {
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24)
                .fill(DuoColors.indigo400.opacity(0.5))
                .frame(width: size * 0.84, height: size * 0.9)
                .rotationEffect(.degrees(7))
                .offset(x: size * 0.15, y: size * 0.08)
            RoundedRectangle(cornerRadius: size * 0.24)
                .fill(DuoColors.indigo600)
            Text("D")
                .font(.system(size: size * 0.58, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
