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

    // ---- NEW ----
    @State private var showChat = false               // toggles the overlay
    @State private var chatMessages: [ChatMessage] = [] // conversation history
    @State private var pendingPrompt = ""             // text field binding
    // ---- END NEW ----

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
                reloadAction: { webView.reload() },
                chatToggle: { showChat.toggle() }   // NEW
            )
        }
        .animation(.easeInOut(duration: 0.2), value: showChat)   // NEW

        // ----- CHAT OVERLAY -----
        if showChat {
            ChatOverlay(isPresented: $showChat,
                        messages: $chatMessages,
                        prompt: $pendingPrompt)
                .transition(.opacity.combined(with: .scale))
                .zIndex(100)   // ensure it sits above everything
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

// MARK: - Simple chat model
struct ChatMessage: Identifiable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    let content: String
}

// MARK: - Transparent chat overlay
struct ChatOverlay: View {
    @Binding var isPresented: Bool
    @Binding var messages: [ChatMessage]
    @Binding var prompt: String

    var body: some View {
        ZStack {
            // Dimmed background – tap to dismiss
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            // Glass‑like chat window
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(messages) { msg in
                            HStack {
                                if msg.role == .assistant {
                                    Image(systemName: "cpu")
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "person")
                                        .foregroundColor(.blue)
                                }
                                Text(msg.content)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.2))
                            )
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 300)

                Divider()

                HStack {
                    TextField("Ask the LLM…", text: $prompt, onCommit: send)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button(action: send) {
                        Image(systemName: "paperplane.fill")
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .frame(width: 500, maxHeight: .infinity, alignment: .top)
            .background(
                VisualEffectBlur(material: .ultraThin, blendingMode: .behindWindow)
                    .cornerRadius(12)
            )
            .padding(.top, 80) // leave room for the glass bar
        }
    }

    // -----------------------------------------------------------------
    // Send the current prompt to the LLM (Ollama on 127.0.0.1:11434)
    // -----------------------------------------------------------------
    private func send() {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Append user message locally
        messages.append(ChatMessage(role: .user, content: trimmed))
        prompt = ""

        // Build request payload – you can change the model name if you wish
        let payload: [String: Any] = [
            "model": "llama3.2",                     // <-- pick a model that supports tool calls
            "messages": messages.map { ["role": $0.role == .user ? "user" : "assistant",
                                        "content": $0.content] },
            // OPTIONAL: expose a tool that can manipulate JSX/DOM
            "tools": [
                [
                    "type": "function",
                    "function": [
                        "name": "jsx_dom",
                        "description": "Interact with a JSX DOM (create, update, query).",
                        "parameters": [
                            "type": "object",
                            "properties": [
                                "action": ["type": "string", "enum": ["create","update","query"]],
                                "selector": ["type": "string"],
                                "jsx": ["type": "string"]
                            ],
                            "required": ["action"]
                        ]
                    ]
                ]
            ]
        ]

        guard let url = URL(string: "http://127.0.0.1:11434/api/chat"),
              let body = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        // Fire‑and‑forget async request
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                // Ollama returns a stream of JSON objects; we just decode the last one
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    await MainActor.run {
                        messages.append(ChatMessage(role: .assistant, content: content))
                    }
                }
            } catch {
                await MainActor.run {
                    messages.append(ChatMessage(role: .assistant,
                                                content: "❗️ Error: \(error.localizedDescription)"))
                }
            }
        }
    }
}

// MARK: - Glass navigation bar (liquid UI)
struct GlassBar: View {
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    var backAction: () -> Void
    var forwardAction: () -> Void
    var reloadAction: () -> Void
    var chatToggle: () -> Void          // NEW

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

            // ----- NEW CHAT BUTTON -----
            Button(action: chatToggle) {
                Image(systemName: "bubble.left.and.bubble.right")
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
