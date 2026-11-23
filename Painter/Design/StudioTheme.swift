import SwiftUI

enum StudioTheme {
    static let paper = Color(hex: 0xFBF8F2)
    static let ink = Color(hex: 0x262925)
    static let muted = Color(hex: 0x72756D)
    static let coral = Color(hex: 0xC44F38)
    static let peach = Color(hex: 0xF7DDD0)
    static let sage = Color(hex: 0xDCE8DA)
    static let green = Color(hex: 0x345A45)
    static let lavender = Color(hex: 0xE6E0F4)
    static let line = Color(hex: 0xE6E4DC)
    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let name = weight == .bold ? "Bold" : weight == .semibold ? "SemiBold" : weight == .medium ? "Medium" : "Regular"
        return .custom("DMSans-\(name)", size: size, relativeTo: size >= 28 ? .title : size <= 12 ? .caption : .body)
    }
}

extension Color {
    init(hex: UInt32) { self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1) }
}

struct StudioButton: View {
    let title: String
    var color: Color = StudioTheme.coral
    var isBusy = false
    var action: () -> Void
    init(_ title: String, color: Color = StudioTheme.coral, isBusy: Bool = false, action: @escaping () -> Void) {
        self.title = title; self.color = color; self.isBusy = isBusy; self.action = action
    }
    var body: some View {
        Button(action: action) {
            HStack { if isBusy { ProgressView().tint(.white) }; Text(title).multilineTextAlignment(.center) }
                .font(StudioTheme.font(16, .bold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 17).padding(.horizontal, 12)
                .background(color, in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain).disabled(isBusy)
    }
}

struct StudioIcon: View {
    let name: String
    var size: CGFloat = 24
    var body: some View { Image("icon-" + name).resizable().renderingMode(.template).scaledToFit().frame(width: size, height: size).accessibilityHidden(true) }
}

struct Badge: View {
    let text: String
    var color: Color = StudioTheme.green
    var background: Color = StudioTheme.sage
    var body: some View { Text(text).font(StudioTheme.font(11, .bold)).foregroundStyle(color).padding(.horizontal, 11).padding(.vertical, 6).background(background, in: Capsule()) }
}

struct SectionHeading: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(StudioTheme.font(21, .bold))
            Spacer(minLength: 8)
            if let actionTitle, let action {
                Button(actionTitle, action: action).font(StudioTheme.font(12, .semibold)).foregroundStyle(StudioTheme.coral).frame(minHeight: 44)
            }
        }
    }
}

struct Artwork: View {
    let drawing: Drawing
    var body: some View {
        Group {
            if let path = drawing.localImage, let image = ImageFiles.load(path) { Image(uiImage: image).resizable().scaledToFit() }
            else { Image(drawing.asset).resizable().scaledToFill() }
        }.accessibilityLabel(drawing.title)
    }
}

struct DifficultyFilter: View {
    @Binding var selection: Difficulty?
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", value: nil)
                ForEach(Difficulty.allCases) { chip($0.rawValue, value: $0) }
            }
        }
    }
    private func chip(_ label: String, value: Difficulty?) -> some View {
        Button { selection = value } label: {
            Text(label).font(StudioTheme.font(12, .bold)).padding(.horizontal, 13).padding(.vertical, 9)
                .foregroundStyle(selection == value ? .white : StudioTheme.ink)
                .background(selection == value ? StudioTheme.ink : .white, in: Capsule())
                .frame(minHeight: 44)
        }.buttonStyle(.plain).accessibilityAddTraits(selection == value ? .isSelected : [])
    }
}

struct StudioPage<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) { content }
                .frame(maxWidth: 560).padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 28)
                .frame(maxWidth: .infinity)
        }.background(StudioTheme.paper).foregroundStyle(StudioTheme.ink)
    }
}

extension View {
    func studioCard(_ color: Color = .white, padding: CGFloat = 16) -> some View {
        self.padding(padding).background(color, in: RoundedRectangle(cornerRadius: 22))
    }
    func studioTitle() -> some View { self.font(StudioTheme.font(30, .bold)).fixedSize(horizontal: false, vertical: true) }
    func studioCaption() -> some View { self.font(StudioTheme.font(14)).foregroundStyle(StudioTheme.muted).fixedSize(horizontal: false, vertical: true) }
}
