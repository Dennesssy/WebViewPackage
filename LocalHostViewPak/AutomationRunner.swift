import Foundation

enum AutomationError: Error {
    case scriptFailed(String)
    case noResult
}

/// Executes a plain AppleScript string and returns the script’s standard output.
func runAppleScript(_ source: String) throws -> String {
    var error: NSDictionary?
    if let script = NSAppleScript(source: source) {
        let output = script.executeAndReturnError(&error)
        if let err = error {
            throw AutomationError.scriptFailed(err.description)
        }
        // `output` may be a string, number, etc.  Convert to Swift String.
        if output.descriptorType == typeUnicodeText {
            return output.stringValue ?? ""
        } else {
            // Fallback – try to coerce to string
            return output.coerce(toDescriptorType: typeUnicodeText)?.stringValue ?? ""
        }
    } else {
        throw AutomationError.scriptFailed("Could not compile script")
    }
}

/// Executes a JXA (JavaScript for Automation) script.
func runJXA(_ source: String) throws -> String {
    // JXA runs via the `osascript -l JavaScript` command‑line tool.
    let task = Process()
    task.launchPath = "/usr/bin/osascript"
    task.arguments = ["-l", "JavaScript", "-e", source]

    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe

    try task.run()
    task.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let output = String(data: data, encoding: .utf8) else {
        throw AutomationError.noResult
    }

    if task.terminationStatus != 0 {
        throw AutomationError.scriptFailed(output)
    }
    return output.trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - Safari Automation (AppleScript)

enum SafariAutomation {
    /// Opens a new tab with the given URL (or focuses an existing tab if it already exists).
    static func open(url: String) throws {
        let script = """
        tell application "Safari"
            if (count of windows) = 0 then make new document
            set newTab to make new tab at end of tabs of front window
            set URL of newTab to "\(url)"
            set current tab of front window to newTab
            activate
        end tell
        """
        try runAppleScript(script)
    }

    /// Returns the URL of the frontmost Safari tab.
    static func currentURL() throws -> String {
        let script = """
        tell application "Safari"
            if (count of windows) = 0 then error "no windows"
            set theURL to URL of current tab of front window
        end tell
        theURL
        """
        return try runAppleScript(script)
    }

    static func goBack() throws {
        let script = """
        tell application "Safari"
            if can go back of current tab of front window then
                go back of current tab of front window
            end if
        end tell
        """
        try runAppleScript(script)
    }

    static func goForward() throws {
        let script = """
        tell application "Safari"
            if can go forward of current tab of front window then
                go forward of current tab of front window
            end if
        end tell
        """
        try runAppleScript(script)
    }

    static func reload() throws {
        let script = """
        tell application "Safari"
            reload current tab of front window
        end tell
        """
        try runAppleScript(script)
    }
}

// MARK: - Chrome Automation (JXA)

enum ChromeAutomation {
    /// Opens a new tab (or focuses an existing one) in Google Chrome.
    static func open(url: String) throws {
        let script = """
        var chrome = Application('Google Chrome');
        chrome.activate();
        var win = chrome.windows[0] || chrome.Window().make();
        var tab = chrome.Tab({url: "\(url)"});
        win.tabs.push(tab);
        win.activeTabIndex = win.tabs.length;
        """
        try runJXA(script)
    }

    /// Returns the URL of the active Chrome tab.
    static func currentURL() throws -> String {
        let script = """
        var chrome = Application('Google Chrome');
        var url = chrome.windows[0].activeTab.url();
        url;
        """
        return try runJXA(script)
    }

    static func goBack() throws {
        let script = """
        var chrome = Application('Google Chrome');
        var tab = chrome.windows[0].activeTab;
        if (tab.canGoBack()) { tab.goBack(); }
        """
        try runJXA(script)
    }

    static func goForward() throws {
        let script = """
        var chrome = Application('Google Chrome');
        var tab = chrome.windows[0].activeTab;
        if (tab.canGoForward()) { tab.goForward(); }
        """
        try runJXA(script)
    }

    static func reload() throws {
        let script = """
        var chrome = Application('Google Chrome');
        chrome.windows[0].activeTab.reload();
        """
        try runJXA(script)
    }
}
