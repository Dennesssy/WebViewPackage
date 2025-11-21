//
//  LocalHostViewPakTests.swift
//  LocalHostViewPakTests
//
//  Created by Dennis Stewart Jr. on 11/13/25.
//

import SwiftUI
import WebKit

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
    
    @State private var canGoBack = false
    @State private var canGoForward = false

    var body: some View {
        VStack(spacing: 0) {
            // ---- URL Bar -------------------------------------------------
            HStack {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!canGoBack)
                .help("Back")

                Button(action: goForward) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!canGoForward)
                .help("Forward")

                Button(action: reloadPage) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(PlainButtonStyle())
                .help("Reload")

                TextField("Enter URL", text: $urlString, onCommit: loadCurrentURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button(action: loadCurrentURL) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("Load URL")

                // Simple Chat Button
                Button(action: {
                    // Load chat interface via data URL
                    let chatHTML = """
                    <!DOCTYPE html>
                    <html>
                    <head>
                        <title>LocalHostViewPak Chat Interface</title>
                        <style>
                            body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 20px; background: #f5f5f7; }
                            .chat-container { max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; padding: 20px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
                            h2 { color: #333; margin-bottom: 20px; }
                            .api-section { background: #f8f9fa; padding: 15px; border-radius: 8px; margin: 15px 0; }
                            .command { background: #e3f2fd; padding: 10px; border-radius: 6px; margin: 5px 0; font-family: monospace; }
                            button { background: #007aff; color: white; border: none; padding: 10px 20px; border-radius: 6px; cursor: pointer; margin: 5px; }
                            button:hover { background: #0056b3; }
                        </style>
                    </head>
                    <body>
                        <div class="chat-container">
                            <h2>🤖 LocalHostViewPak Chat Interface</h2>
                            <p>Welcome! I can help you interact with webpages using JavaScript commands.</p>

                            <div class="api-section">
                                <h3>📡 API Server is running on: <a href="http://localhost:8080" target="_blank">http://localhost:8080</a></h3>
                                <p>Use these API endpoints to control the WebView:</p>
                                <div class="command">GET /current - Get current URL</div>
                                <div class="command">GET /title - Get page title</div>
                                <div class="command">GET /source - Get page HTML</div>
                                <div class="command">GET /navigate?url=URL - Navigate to URL</div>
                                <div class="command">GET /make_editable - Make page editable</div>
                                <div class="command">GET /make_readonly - Make page read-only</div>
                            </div>

                            <h3>💡 Try These Examples:</h3>
                            <button onclick="testAPI()">Test API Health</button>
                            <button onclick="getCurrentURL()">Get Current URL</button>
                            <button onclick="getPageTitle()">Get Page Title</button>
                            <button onclick="goBack()">← Back to Previous Page</button>

                            <script>
                                function testAPI() {
                                    fetch('http://localhost:8080/health')
                                        .then(r => r.text())
                                        .then(data => alert('✅ API Health: ' + data))
                                        .catch(e => alert('❌ Error: ' + e));
                                }

                                function getCurrentURL() {
                                    fetch('http://localhost:8080/current')
                                        .then(r => r.text())
                                        .then(url => alert('📍 Current URL: ' + url))
                                        .catch(e => alert('❌ Error: ' + e));
                                }

                                function getPageTitle() {
                                    fetch('http://localhost:8080/title')
                                        .then(r => r.text())
                                        .then(title => alert('📄 Page Title: ' + title))
                                        .catch(e => alert('❌ Error: ' + e));
                                }

                                function goBack() {
                                    history.back();
                                }
                            </script>
                        </div>
                    </body>
                    </html>
                    """
                    if let data = chatHTML.data(using: .utf8) {
                        let base64 = data.base64EncodedString()
                        if let url = URL(string: "data:text/html;base64,\(base64)") {
                            webView.load(URLRequest(url: url))
                        }
                    }
                }) {
                    Image(systemName: "message.badge")
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Open Chat Interface")
            }
            .padding()

            // ---- WebView -------------------------------------------------
            WebView(webView: webView, urlString: $urlString, canGoBack: $canGoBack, canGoForward: $canGoForward)
                .frame(maxWidth: .infinity, maxHeight: .infinity)   // fill remaining space
        }
    }

    private func loadCurrentURL() {
        // Normalise the string – add scheme if missing, but preserve file:// URLs
        var formatted = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Don't modify URLs that already have a scheme (including file://)
        if !formatted.lowercased().hasPrefix("http://") &&
            !formatted.lowercased().hasPrefix("https://") &&
            !formatted.lowercased().hasPrefix("file://") {
            formatted = "https://\(formatted)"
        }
        urlString = formatted   // update the bound text field (shows scheme)

        if let url = URL(string: formatted) {
            webView.load(URLRequest(url: url))
        }
    }

    private func goBack() {
        webView.goBack()
    }
    private func goForward() {
        webView.goForward()
    }
    private func reloadPage() {
        webView.reload()
    }
}

// MARK: - NSViewRepresentable wrapper for WKWebView
struct WebView: NSViewRepresentable {
    let webView: WKWebView
    @Binding var urlString: String   // kept only for possible future sync (e.g., title)
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool

    func makeNSView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        // Pinch‑zoom, scrolling, etc. are enabled by default.

        // Update initial navigation state
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward

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
                    self.parent.canGoBack = webView.canGoBack
                    self.parent.canGoForward = webView.canGoForward
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

