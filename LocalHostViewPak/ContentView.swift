import SwiftUI
import WebKit
import AppKit

// MARK: - SwiftUI App Entry Point
@main
struct LocalHostViewPakApp: App {
    init() {
        // Prompt user for Accessibility permission if not already granted
        AccessibilityHelper.ensurePermission()
    }
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
                    TextField("Go to a site…", text: $urlString, onCommit: loadCurrentURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Button(action: loadCurrentURL) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Load URL")

                    // NEW – open current URL in Safari
                    Button(action: openInSafari) {
                        Image(systemName: "safari")
                            .font(.title2)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Open in Safari")
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
                chatToggle: { showChat.toggle() },   // NEW
                // EXTERNAL‑BROWSER ACTIONS
                externalBack: {
                    Task {
                        do { try SafariAutomation.goBack() }
                        catch { print("❗️ Safari back error:", $0) }
                    }
                },
                externalForward: {
                    Task {
                        do { try SafariAutomation.goForward() }
                        catch { print("❗️ Safari forward error:", $0) }
                    }
                },
                externalReload: {
                    Task {
                        do { try SafariAutomation.reload() }
                        catch { print("❗️ Safari reload error:", $0) }
                    }
                }
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

    // MARK: - External browser helpers
    private func openInSafari() {
        Task {
            do {
                try SafariAutomation.open(url: urlString)
            } catch {
                print("❗️ Safari open error:", error)
            }
        }
    }
}

// MARK: - Simple chat model
struct ChatMessage: Identifiable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    let content: String
}

// MARK: - Ollama chat response model
private struct OllamaChatResponse: Decodable {
    struct Message: Decodable {
        let role: String
        let content: String
    }
    let message: Message
    let tool_calls: [ToolCall]?

    struct ToolCall: Decodable {
        let id: String
        let type: String
        let function: FunctionCall

        struct FunctionCall: Decodable {
            let name: String
            let arguments: String
        }
    }
}

private struct JSXDomArgs: Decodable {
    let action: String
    let selector: String?
    let jsx: String?
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
                    TextField("Ask me something…", text: $prompt, onCommit: send)
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
            "model": "llama3.2",
            "stream": false,                     // ← NEW
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
                // Decode the *single* JSON object returned by Ollama
                let response = try JSONDecoder().decode(OllamaChatResponse.self, from: data)

                // Normal assistant reply
                await MainActor.run {
                    messages.append(ChatMessage(role: .assistant,
                                                content: response.message.content))
                }

                // OPTIONAL: handle a tool call (e.g., jsx_dom)
                if let tool = response.tool_calls?.first,
                   tool.type == "function",
                   tool.function.name == "jsx_dom" {
                    // `tool.function.arguments` is a JSON string – decode it if you need it
                    // Example:
                    // let args = try JSONDecoder().decode(JSXDomArgs.self,
                    //                                      from: Data(tool.function.arguments.utf8))
                    // …perform the requested DOM manipulation…
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
    var chatToggle: () -> Void

    // NEW – external‑browser actions (optional)
    var externalBack: (() -> Void)? = nil
    var externalForward: (() -> Void)? = nil
    var externalReload: (() -> Void)? = nil

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

            // ----- NEW EXTERNAL BROWSER BUTTONS (optional) -----
            if let extBack = externalBack {
                Button(action: extBack) {
                    Image(systemName: "arrow.left.square")
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            if let extFwd = externalForward {
                Button(action: extFwd) {
                    Image(systemName: "arrow.right.square")
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            if let extReload = externalReload {
                Button(action: extReload) {
                    Image(systemName: "arrow.clockwise.square")
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }

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
