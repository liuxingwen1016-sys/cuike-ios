import SwiftUI

enum Palette {
    static let ink = Color("Ink")
    static let paper = Color("Paper")
    static let card = Color("Card")
    static let accent = Color("AccentColor")
    static let sage = Color(red: 0.39, green: 0.47, blue: 0.42)
    static func bean(_ name: String) -> Color {
        switch name {
        case "sage": return sage
        case "cocoa": return Color(red: 0.45, green: 0.37, blue: 0.33)
        default: return accent
        }
    }
}

struct PrimaryButton: View {
    let title: String
    var symbol: String = "arrow.right"
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title).font(.headline)
                Spacer(minLength: 8)
                Image(systemName: symbol)
            }
            .padding(.horizontal, 22).padding(.vertical, 18)
            .foregroundStyle(Color("ButtonText"))
            .background(Palette.ink, in: RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
    }
}

struct SectionHeading: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.bold())
            Spacer()
            if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
        }
    }
}

struct TagPill: View {
    let title: String
    var selected = false
    var body: some View {
        Text(title).font(.subheadline)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .foregroundStyle(selected ? Color("ButtonText") : Palette.ink)
            .background(selected ? Palette.ink : Palette.ink.opacity(0.06), in: Capsule())
    }
}

struct Metric: View {
    let value: String
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct BeanBag: View {
    var color = "terracotta"
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                BagShape().fill(LinearGradient(colors: [Color(red: 0.78, green: 0.68, blue: 0.53),
                    Color(red: 0.94, green: 0.88, blue: 0.76), Color(red: 0.82, green: 0.72, blue: 0.56)],
                    startPoint: .leading, endPoint: .trailing))
                VStack(spacing: size.height * 0.045) {
                    Rectangle().fill(Palette.bean(color)).frame(height: size.height * 0.045)
                    Text("CUIKE COFFEE").font(.system(size: size.width * 0.052, weight: .medium, design: .serif)).tracking(1)
                    Text(color == "sage" ? "BERRY\nHILLS" : color == "cocoa" ? "FOREST\nCOCOA" : "CITRUS\nMORNING")
                        .font(.system(size: size.width * 0.105, design: .serif)).lineSpacing(3)
                    Image(systemName: "sun.max.fill").font(.system(size: size.width * 0.19)).foregroundStyle(Palette.bean(color))
                    Text("SMALL BATCH · 200G").font(.system(size: size.width * 0.043))
                    Spacer(minLength: 4)
                }
                .foregroundStyle(Color(red: 0.25, green: 0.18, blue: 0.14))
                .frame(width: size.width * 0.61, height: size.height * 0.62)
                .background(Color(red: 0.99, green: 0.97, blue: 0.90))
                .offset(y: size.height * 0.04)
                Capsule().fill(Color.brown.opacity(0.28)).frame(width: size.width * 0.69, height: 4)
                    .offset(y: -size.height * 0.37)
            }
            .rotationEffect(.degrees(-5))
            .shadow(color: .black.opacity(0.10), radius: 16, x: 3, y: 14)
        }
        .accessibilityHidden(true)
    }
}

private struct BagShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let w = rect.width, h = rect.height
            p.move(to: CGPoint(x: 0.16*w, y: 0.04*h))
            p.addLine(to: CGPoint(x: 0.84*w, y: 0.04*h))
            p.addLine(to: CGPoint(x: 0.91*w, y: 0.18*h))
            p.addLine(to: CGPoint(x: 0.87*w, y: 0.94*h))
            p.addQuadCurve(to: CGPoint(x: 0.13*w, y: 0.94*h), control: CGPoint(x: 0.5*w, y: 1.04*h))
            p.addLine(to: CGPoint(x: 0.09*w, y: 0.18*h))
            p.closeSubpath()
        }
    }
}

struct EmptyCard: View {
    let title: String
    let detail: String
    var symbol = "cup.and.saucer"
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol).font(.largeTitle).foregroundStyle(Palette.accent)
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(32).cardSurface()
    }
}

extension View {
    func cardSurface() -> some View {
        background(Palette.card, in: RoundedRectangle(cornerRadius: 24))
    }
    func cuikePage() -> some View {
        background(Palette.paper.ignoresSafeArea()).foregroundStyle(Palette.ink)
    }
}

enum DisplayFormat {
    static func ratio(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...1))) }
    static func time(_ seconds: Int) -> String { String(format: "%02d:%02d", max(0, seconds) / 60, max(0, seconds) % 60) }
}
