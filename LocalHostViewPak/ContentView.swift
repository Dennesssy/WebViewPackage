import SwiftUI
import WebKit
import AppKit

// MARK: - SwiftUI App Entry Point
@main
struct LocalHostViewPakApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Main Content View (URL bar + WebView)
struct ContentView: View {
    @State private var urlString: String = "https://www.apple.com"
    @State private var webView = WKWebView()          // persistent instance
    @State private var canGoBack = false              // navigation flags
    @State private var canGoForward = false

    var body: some View {
        ZStack(alignment: .top) {
            // Background to keep window opaque when glass is transparent
            Color.clear
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // ---- URL Bar -------------------------------------------------
                HStack {
                    TextField("Enter URL", text: $urlString, onCommit: loadCurrentURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Button(action: loadCurrentURL) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Load URL")
                }
                .padding(.top, 44)   // push content below the glass bar
                .padding()

                // ---- WebView -------------------------------------------------
                WebView(
                    webView: webView,
                    urlString: $urlString,
                    updateNavigationState: { updateNavigationState() }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Glass navigation bar (always on top)
            GlassBar(
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                backAction: goBack,
                forwardAction: goForward,
                reloadAction: { webView.reload() }   // new reload closure
            )
        }
    }

    // MARK: - URL handling
    private func loadCurrentURL() {
        // Normalise the string – add scheme if missing
        var formatted = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !formatted.lowercased().hasPrefix("http://") &&
            !formatted.lowercased().hasPrefix("https://") {
            formatted = "https://\(formatted)"
        }
        urlString = formatted   // update the bound text field (shows scheme)

        if let url = URL(string: formatted) {
            webView.load(URLRequest(url: url))
        }
    }

    // MARK: - Navigation state helpers
    private func updateNavigationState() {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
    }

    private func goBack() {
        if webView.canGoBack { webView.goBack() }
        updateNavigationState()
    }

    private func goForward() {
        if webView.canGoForward { webView.goForward() }
        updateNavigationState()
    }
}

// MARK: - Glass navigation bar (liquid UI)
struct GlassBar: View {
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    var backAction: () -> Void
    var forwardAction: () -> Void
    var reloadAction: () -> Void   // new closure

    var body: some View {
        HStack(spacing: 12) {
            Button(action: backAction) {
                Image(systemName: "chevron.left")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .disabled(!canGoBack)

            Button(action: forwardAction) {
                Image(systemName: "chevron.right")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .disabled(!canGoForward)

            Button(action: reloadAction) {
                Image(systemName: "arrow.clockwise")
                    .font(.title2)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(
            // macOS 12+ visual‑effect material (glass / liquid)
            VisualEffectBlur(material: .ultraThin, blendingMode: .behindWindow)
        )
    }
}

// Helper for macOS visual‑effect blur (SwiftUI wrapper)
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - NSViewRepresentable wrapper for WKWebView
struct WebView: NSViewRepresentable {
    let webView: WKWebView
    @Binding var urlString: String   // kept only for possible future sync (e.g., title)
    var updateNavigationState: (() -> Void)? = nil   // optional callback

    func makeNSView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        // Pinch‑zoom, scrolling, etc. are enabled by default.
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // No‑op – we drive navigation from ContentView.loadCurrentURL()
    }

    // MARK: Coordinator – optional but useful for future extensions
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        // Example: keep the URL bar in sync when the user follows a link
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let url = webView.url?.absoluteString {
                DispatchQueue.main.async {
                    self.parent.urlString = url
                    self.parent.updateNavigationState?()   // keep navigation flags in sync
                }
            }
        }
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
