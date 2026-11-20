import SwiftUI
import ForgeCore
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum ForgeStyle {
    private static func adaptive(light: (Double,Double,Double), dark: (Double,Double,Double)) -> Color {
        #if os(macOS)
        Color(NSColor(name: nil) { appearance in
            let rgb = appearance.bestMatch(from: [.darkAqua,.aqua]) == .darkAqua ? dark : light
            return NSColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
        #else
        Color(UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
        #endif
    }
    static let accent = adaptive(light: (0.72,0.23,0.07), dark: (0.98,0.42,0.21))
    static let primaryButtonText = adaptive(light: (1,1,1), dark: (0,0,0))
    static let green = adaptive(light: (0.15,0.45,0.26), dark: (0.40,0.72,0.54))
    static func color(_ domain: Domain) -> Color {
        switch domain { case .business: accent; case .builder: adaptive(light: (0.29,0.35,0.73), dark: (0.52,0.58,0.93)); case .health: green; case .network: adaptive(light: (0.50,0.37,0.13), dark: (0.80,0.64,0.39)) }
    }
    static func money(_ amount: Double) -> String { amount.formatted(.number.precision(.fractionLength(0))) }
}
struct Card<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.primary.opacity(0.07), lineWidth: 1))
    }
}
struct Eyebrow: View {
    var title: String
    var body: some View { Text(title.uppercased()).font(.caption2.weight(.semibold)).tracking(2).foregroundStyle(.secondary) }
}
struct PageHeader: View {
    var eyebrow: String; var title: String; var subtitle: String
    var body: some View { VStack(alignment: .leading, spacing: 9) { Eyebrow(title: eyebrow); Text(title).font(.system(.largeTitle, design: .default, weight: .bold)); Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 8) }
}
struct DomainPill: View {
    var domain: Domain
    var body: some View { Label(domain.title, systemImage: domain.symbol).font(.caption.weight(.medium)).foregroundStyle(ForgeStyle.color(domain)).padding(.horizontal, 9).padding(.vertical, 5).background(ForgeStyle.color(domain).opacity(0.10), in: Capsule()) }
}
struct Metric: View {
    var label: String; var value: String; var footnote: String; var symbol: String
    var body: some View { Card { VStack(alignment: .leading, spacing: 12) { HStack { Eyebrow(title: label); Spacer(); Image(systemName: symbol).foregroundStyle(ForgeStyle.accent) }; Text(value).font(.system(size: 29, weight: .semibold, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6); Text(footnote).font(.caption).foregroundStyle(.secondary) } } }
}
struct ScreenContent<Content: View>: View {
    var content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View { ScrollView { VStack(alignment: .leading, spacing: 22) { content }.padding(26).frame(maxWidth: 1240).frame(maxWidth: .infinity) }.scrollIndicators(.hidden) }
}
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.weight(.semibold)).padding(.horizontal, 18).padding(.vertical, 12).background(ForgeStyle.accent.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 10)).foregroundStyle(ForgeStyle.primaryButtonText)
    }
}
extension View {
    func forgePrimary() -> some View { buttonStyle(PrimaryButtonStyle()) }
    func sheetSizing() -> some View {
        #if os(macOS)
        self.frame(minWidth: 520, idealWidth: 620, maxWidth: 760, minHeight: 480, idealHeight: 700, maxHeight: 900)
        #else
        self
        #endif
    }
}
