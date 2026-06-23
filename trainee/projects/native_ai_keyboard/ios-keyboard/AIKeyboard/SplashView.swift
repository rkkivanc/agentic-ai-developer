import SwiftUI

/// Branded launch screen — content mounts only after splash so modals cannot cover it.
struct SplashGate<Content: View>: View {
    @ViewBuilder var content: () -> Content

    @State private var showSplash = true

    var body: some View {
        Group {
            if showSplash {
                SplashScreen()
            } else {
                content()
            }
        }
        .animation(.easeOut(duration: 0.28), value: showSplash)
        .task {
            guard showSplash else { return }
            try? await Task.sleep(for: .seconds(1.35))
            showSplash = false
        }
    }
}

struct SplashScreen: View {
    @State private var logoScale: CGFloat = 0.55
    @State private var logoOpacity: Double = 0
    @State private var versionOpacity: Double = 0

    var body: some View {
        Color("SplashBackground")
            .ignoresSafeArea()
            .overlay {
                BrandMarkImage(height: 120, onLightBackground: true)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Text(AppVersionLabel.text)
                    .font(.caption)
                    .foregroundStyle(Color.black.opacity(0.45))
                    .opacity(versionOpacity)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 4)
            }
            .onAppear {
                withAnimation(.spring(response: 0.62, dampingFraction: 0.72)) {
                    logoScale = 1
                    logoOpacity = 1
                }
                withAnimation(.easeOut(duration: 0.4).delay(0.25)) {
                    versionOpacity = 1
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("MF AI Keyboard")
    }
}

/// Flat black brand mark — template rendering, no background chip.
struct BrandMarkImage: View {
    @Environment(\.colorScheme) private var colorScheme

    var height: CGFloat = 26
    var onLightBackground: Bool = false

    private var tint: Color {
        if onLightBackground { return .black }
        return colorScheme == .dark ? .white : .black
    }

    var body: some View {
        Image("masterfabric-logo")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .foregroundStyle(tint)
            .background(Color.clear)
            .accessibilityLabel(Text("app.title", bundle: .main))
    }
}

enum AppVersionLabel {
    static var text: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        if build.isEmpty { return "v\(version)" }
        return "v\(version) (\(build))"
    }
}
