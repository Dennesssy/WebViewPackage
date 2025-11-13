//
//  ContentView.swift
//  LocalHostViewPak
//
//  Created by Dennis Stewart Jr. on 11/13/25.
//

import SwiftUI
import WebKit

// MARK: - SwiftUI App Entry Point
@main
struct HybridWebViewApp: App {
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

    var body: some View {
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
            .padding()

            // ---- WebView -------------------------------------------------
            WebView(webView: webView, urlString: $urlString)
                .frame(maxWidth: .infinity, maxHeight: .infinity)   // fill remaining space
        }
    }

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
}

// MARK: - NSViewRepresentable wrapper for WKWebView
struct WebView: NSViewRepresentable {
    let webView: WKWebView
    @Binding var urlString: String   // kept only for possible future sync (e.g., title)

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
