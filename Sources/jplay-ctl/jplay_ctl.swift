import ApplicationServices
import Cocoa

// MARK: - Actions & View Protocol

enum JPlayAction: CaseIterable {
    case play, next, prev, toggleLike, search
}

protocol JPlayView {
    static func matches(window: AXUIElement) -> Bool
    func canPerform(_ action: JPlayAction, window: AXUIElement) -> Bool
    func perform(_ action: JPlayAction, window: AXUIElement) -> Bool
    func escape(window: AXUIElement) -> Bool
}

// MARK: - Views

/// Search view - has text field, NO large transport
struct SearchView: JPlayView {
    static func matches(window: AXUIElement) -> Bool {
        // Must have text field
        guard JPlayCtl.findTextField(in: window) != nil else { return false }
        // Must NOT have large transport (that's NowPlaying/Sofa)
        guard !JPlayCtl.hasLargeTransport(in: window) else { return false }
        return true
    }

    func canPerform(_ action: JPlayAction, window: AXUIElement) -> Bool {
        true  // Has mini transport + search field
    }

    func perform(_ action: JPlayAction, window: AXUIElement) -> Bool {
        switch action {
        case .play:
            return JPlayCtl.clickTransportInWindow(window, matching: ["Play", "Pause"])
        case .next:
            return JPlayCtl.clickTransportInWindow(window, matching: ["Next"])
        case .prev:
            return JPlayCtl.clickTransportInWindow(window, matching: ["Previous"])
        case .toggleLike:
            return JPlayCtl.clickFavoriteInWindow(window)
        case .search:
            // Focus the search text field by clicking it
            if let textField = JPlayCtl.findTextField(in: window) {
                if AXUIElementPerformAction(textField, kAXPressAction as CFString) == .success {
                    JPlayCtl.debug("clicked text field")
                } else {
                    AXUIElementSetAttributeValue(textField, kAXFocusedAttribute as CFString, true as CFTypeRef)
                    JPlayCtl.debug("set focus attribute")
                }
                if let pid = JPlayCtl.findUPnPPlayerPID() {
                    let app = NSRunningApplication(processIdentifier: pid)
                    app?.activate(options: .activateIgnoringOtherApps)
                }
                return true
            }
            return false
        }
    }

    func escape(window: AXUIElement) -> Bool {
        false  // No escape needed
    }
}

/// Library view - has Search button + small transport
struct LibraryView: JPlayView {
    static func matches(window: AXUIElement) -> Bool {
        // Must have Search button (to navigate to search)
        guard JPlayCtl.findButtonByDesc(in: window, matching: ["Search"]) != nil else {
            return false
        }
        // And small transport (<=50px)
        if let playBtn = JPlayCtl.findTransportButton(in: window, matching: ["Play", "Pause"]) {
            var sizeRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(playBtn, kAXSizeAttribute as CFString, &sizeRef) == .success,
               let sizeValue = sizeRef {
                var size = CGSize.zero
                if AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) {
                    return size.width <= 50
                }
            }
        }
        return false
    }

    func canPerform(_ action: JPlayAction, window: AXUIElement) -> Bool {
        switch action {
        case .play, .next, .prev, .toggleLike:
            return true
        case .search:
            return false  // Need to escape to SearchView first
        }
    }

    func perform(_ action: JPlayAction, window: AXUIElement) -> Bool {
        switch action {
        case .play:
            return JPlayCtl.clickTransportInWindow(window, matching: ["Play", "Pause"])
        case .next:
            return JPlayCtl.clickTransportInWindow(window, matching: ["Next"])
        case .prev:
            return JPlayCtl.clickTransportInWindow(window, matching: ["Previous"])
        case .toggleLike:
            return JPlayCtl.clickFavoriteInWindow(window)
        case .search:
            return false  // Handled by escape
        }
    }

    func escape(window: AXUIElement) -> Bool {
        // Click Search button to navigate to SearchView
        if let btn = JPlayCtl.findButtonByDesc(in: window, matching: ["Search"]) {
            return AXUIElementPerformAction(btn, kAXPressAction as CFString) == .success
        }
        return false
    }
}

/// Now Playing view - has 27x33 chevron, large transport, no "Upcoming" label
struct NowPlayingView: JPlayView {
    static func matches(window: AXUIElement) -> Bool {
        // Must have large transport (>50px) but NOT "Upcoming" label (that's Sofa)
        guard !SofaView.hasUpcomingLabel(window: window) else { return false }
        return JPlayCtl.hasLargeTransport(in: window)
    }

    func canPerform(_ action: JPlayAction, window: AXUIElement) -> Bool {
        switch action {
        case .play, .next, .prev, .toggleLike:
            return true
        case .search:
            return false  // Need to escape first
        }
    }

    func perform(_ action: JPlayAction, window: AXUIElement) -> Bool {
        switch action {
        case .play:
            return JPlayCtl.clickTransportInWindow(window, matching: ["Play", "Pause"])
        case .next:
            return JPlayCtl.clickTransportInWindow(window, matching: ["Next"])
        case .prev:
            return JPlayCtl.clickTransportInWindow(window, matching: ["Previous"])
        case .toggleLike:
            return JPlayCtl.clickFavoriteInWindow(window)
        case .search:
            return false
        }
    }

    func escape(window: AXUIElement) -> Bool {
        // Click the chevron (27x33 no-desc button)
        if let chevron = JPlayCtl.findFirstButtonNoDesc(in: window, width: 27, height: 33) {
            return AXUIElementPerformAction(chevron, kAXPressAction as CFString) == .success
        }
        return false
    }
}

/// Sofa view - has "Upcoming" queue panel + large transport
struct SofaView: JPlayView {
    static func matches(window: AXUIElement) -> Bool {
        hasUpcomingLabel(window: window) && JPlayCtl.hasLargeTransport(in: window)
    }

    static func hasUpcomingLabel(window: AXUIElement) -> Bool {
        JPlayCtl.hasTextElement(in: window, matching: "Upcoming")
    }

    func canPerform(_ action: JPlayAction, window: AXUIElement) -> Bool {
        switch action {
        case .play, .next, .prev, .toggleLike:
            return true
        case .search:
            return false  // Need to escape first
        }
    }

    func perform(_ action: JPlayAction, window: AXUIElement) -> Bool {
        switch action {
        case .play:
            return JPlayCtl.clickTransportInWindow(window, matching: ["Play", "Pause"])
        case .next:
            return JPlayCtl.clickTransportInWindow(window, matching: ["Next"])
        case .prev:
            return JPlayCtl.clickTransportInWindow(window, matching: ["Previous"])
        case .toggleLike:
            return JPlayCtl.clickFavoriteInWindow(window)
        case .search:
            return false
        }
    }

    func escape(window: AXUIElement) -> Bool {
        // Click the X button (56x53 no-desc, 2nd after Renderer Selection)
        var noDescButtons: [AXUIElement] = []
        JPlayCtl.collectNoDescButtons(in: window, width: 56, height: 53, into: &noDescButtons)
        if noDescButtons.count >= 2 {
            return AXUIElementPerformAction(noDescButtons[1], kAXPressAction as CFString) == .success
        }
        return false
    }
}

// MARK: - Main

@main
struct JPlayCtl {
    static var verbose = false

    static func debug(_ message: String) {
        if verbose {
            fputs("debug: \(message)\n", stderr)
        }
    }

    // MARK: - View Registry & Execute Loop

    // Order matters: more specific views first
    static let views: [JPlayView.Type] = [
        SearchView.self,     // Has Cancel button + no large transport
        SofaView.self,       // Has 646x646 element + large transport
        NowPlayingView.self, // Has large transport (no 646x646)
        LibraryView.self,    // Small transport (fallback)
    ]

    static func execute(_ action: JPlayAction, maxDepth: Int = 5, timeout: Double = 2.0) -> Bool {
        for attempt in 0..<maxDepth {
            guard let window = findJPlayWindow() else { return false }

            // Find matching view
            guard let viewType = views.first(where: { $0.matches(window: window) }) else {
                debug("no view matched for attempt \(attempt)")
                return false
            }

            let viewName = String(describing: viewType).replacingOccurrences(of: ".Type", with: "")
            debug("matched \(viewName)")

            let view = createView(viewType)

            // Can perform action here?
            if view.canPerform(action, window: window) {
                debug("performing \(action) in \(viewName)")
                return view.perform(action, window: window)
            }

            // Escape and wait for view change, then loop to re-evaluate
            debug("escaping from \(viewName)")
            guard view.escape(window: window) else {
                debug("escape failed")
                return false
            }

            guard waitForViewChange(from: viewType, timeout: timeout) else {
                debug("timeout waiting for view change")
                return false
            }
        }
        debug("max depth reached")
        return false
    }

    static func createView(_ type: JPlayView.Type) -> JPlayView {
        switch type {
        case is SearchView.Type: return SearchView()
        case is LibraryView.Type: return LibraryView()
        case is NowPlayingView.Type: return NowPlayingView()
        case is SofaView.Type: return SofaView()
        default: fatalError("Unknown view type")
        }
    }

    static func waitForViewChange(from originalView: JPlayView.Type, timeout: Double) -> Bool {
        let start = Date()
        var pollCount = 0
        while Date().timeIntervalSince(start) < timeout {
            guard let window = findJPlayWindow() else { return false }
            pollCount += 1
            for viewType in views {
                if viewType.matches(window: window) {
                    // View changed or stabilized - let main loop decide what to do
                    if viewType != originalView {
                        let viewName = String(describing: viewType).replacingOccurrences(of: ".Type", with: "")
                        debug("poll \(pollCount): changed to \(viewName)")
                    }
                    return true
                }
            }
            usleep(50000)  // 50ms poll
        }
        return false
    }

    // MARK: - View Helpers

    static func clickTransportInWindow(_ window: AXUIElement, matching descriptions: [String]) -> Bool {
        if let button = findTransportButton(in: window, matching: descriptions) {
            return AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
        }
        return false
    }

    static func clickFavoriteInWindow(_ window: AXUIElement) -> Bool {
        let descriptions = [
            "Not Favorite, tap to mark as favorite.",
            "Is Favorite, tap to unfavorite."
        ]
        if let button = findFavoriteButton(in: window, matching: descriptions) {
            return AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
        }
        return false
    }

    static func hasLargeTransport(in window: AXUIElement) -> Bool {
        var found = false
        findButtonBySize(in: window, minWidth: 50, minHeight: 50, maxWidth: 70, maxHeight: 70) { _ in
            found = true
        }
        return found
    }

    static func findElementBySize(in element: AXUIElement, width: Int, height: Int, tolerance: Int, callback: (AXUIElement) -> Void) {
        var sizeRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
           let sizeValue = sizeRef {
            var size = CGSize.zero
            if AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) {
                if abs(Int(size.width) - width) <= tolerance && abs(Int(size.height) - height) <= tolerance {
                    callback(element)
                    return
                }
            }
        }

        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                findElementBySize(in: child, width: width, height: height, tolerance: tolerance, callback: callback)
            }
        }
    }

    static func hasTextElement(in window: AXUIElement, matching text: String) -> Bool {
        var found = false
        findTextElement(in: window, matching: text) { _ in found = true }
        return found
    }

    static func findTextElement(in element: AXUIElement, matching text: String, callback: (AXUIElement) -> Void) {
        // Check description attribute for matching text
        var descRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef) == .success,
           let desc = descRef as? String,
           desc == text {
            callback(element)
            return
        }

        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                findTextElement(in: child, matching: text, callback: callback)
            }
        }
    }

    static func main() {
        var args = Array(CommandLine.arguments.dropFirst())

        // Check for -v/--verbose flag
        if let idx = args.firstIndex(where: { $0 == "-v" || $0 == "--verbose" }) {
            verbose = true
            args.remove(at: idx)
        }

        guard let command = args.first else {
            printUsage()
            exit(1)
        }

        switch command {
        case "play":
            exit(execute(.play) ? 0 : 1)
        case "next":
            exit(execute(.next) ? 0 : 1)
        case "prev":
            exit(execute(.prev) ? 0 : 1)
        case "toggle-like":
            exit(execute(.toggleLike) ? 0 : 1)
        case "search":
            exit(execute(.search) ? 0 : 1)
        case "status":
            printStatus()
            exit(0)
        case "explore":
            exploreButtons()
            exit(0)
        case "detect":
            detectView()
            exit(0)
        case "trace":
            traceButtonPath()
            exit(0)
        case "find-text":
            let pattern = args.count > 1 ? args[1] : ""
            findTextElements(pattern: pattern)
            exit(0)
        default:
            fputs("Unknown command: \(command)\n", stderr)
            printUsage()
            exit(1)
        }
    }

    static func printUsage() {
        print("""
        JPlay CLI - Control JPlay (UPnP Player) via macOS accessibility APIs.

        Usage:
          jplay-ctl [-v] play         Toggle play/pause
          jplay-ctl [-v] next         Next track
          jplay-ctl [-v] prev         Previous track
          jplay-ctl [-v] toggle-like  Toggle favorite
          jplay-ctl [-v] search       Focus search bar
          jplay-ctl status            Show current state

        Options:
          -v, --verbose  Show debug output
        """)
    }

    static func printStatus() {
        if findJPlayWindow() != nil {
            print("running")
        } else if findUPnPPlayerPID() != nil {
            print("no_window")
        } else {
            print("not_running")
        }
    }

    static func findUPnPPlayerPID() -> pid_t? {
        let workspace = NSWorkspace.shared
        for app in workspace.runningApplications {
            if app.localizedName == "UPnP Player" ||
               app.bundleIdentifier == "com.jplay.jplay" {
                return app.processIdentifier
            }
        }
        return nil
    }

    static func findJPlayWindow() -> AXUIElement? {
        guard let pid = findUPnPPlayerPID() else {
            fputs("error: UPnP Player not running\n", stderr)
            return nil
        }

        let app = AXUIElementCreateApplication(pid)

        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else {
            fputs("error: Could not get windows\n", stderr)
            return nil
        }

        for window in windows {
            var titleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
               let title = titleRef as? String,
               title == "JPLAY" {
                return window
            }
        }

        fputs("error: JPLAY window not found\n", stderr)
        return nil
    }

    static func collectNoDescButtons(in element: AXUIElement, width: Int, height: Int, into buttons: inout [AXUIElement]) {
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
           let role = roleRef as? String,
           role == kAXButtonRole as String {

            // Check if no description
            var descRef: CFTypeRef?
            var hasDesc = false
            if AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef) == .success,
               let desc = descRef as? String,
               !desc.isEmpty {
                hasDesc = true
            }

            if !hasDesc {
                var sizeRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
                   let sizeValue = sizeRef {
                    var size = CGSize.zero
                    if AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) {
                        if abs(Int(size.width) - width) <= 3 && abs(Int(size.height) - height) <= 3 {
                            buttons.append(element)
                        }
                    }
                }
            }
        }

        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                collectNoDescButtons(in: child, width: width, height: height, into: &buttons)
            }
        }
    }

    static func findButtonBySize(in element: AXUIElement, minWidth: Int, minHeight: Int, maxWidth: Int, maxHeight: Int, callback: (AXUIElement) -> Void) {
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
           let role = roleRef as? String,
           role == kAXButtonRole as String {

            var sizeRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
               let sizeValue = sizeRef {
                var size = CGSize.zero
                if AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) {
                    let w = Int(size.width)
                    let h = Int(size.height)
                    if w >= minWidth && w <= maxWidth && h >= minHeight && h <= maxHeight {
                        callback(element)
                        return
                    }
                }
            }
        }

        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                findButtonBySize(in: child, minWidth: minWidth, minHeight: minHeight, maxWidth: maxWidth, maxHeight: maxHeight, callback: callback)
            }
        }
    }

    static func findFirstButtonNoDesc(in element: AXUIElement, width: Int, height: Int) -> AXUIElement? {
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
           let role = roleRef as? String,
           role == kAXButtonRole as String {

            // Check if no description or empty description
            var descRef: CFTypeRef?
            var hasDesc = false
            if AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef) == .success,
               let desc = descRef as? String,
               !desc.isEmpty {
                hasDesc = true
            }

            if !hasDesc {
                var sizeRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
                   let sizeValue = sizeRef {
                    var size = CGSize.zero
                    if AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) {
                        // Allow some tolerance
                        if abs(Int(size.width) - width) <= 2 && abs(Int(size.height) - height) <= 2 {
                            return element
                        }
                    }
                }
            }
        }

        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                if let found = findFirstButtonNoDesc(in: child, width: width, height: height) {
                    return found
                }
            }
        }

        return nil
    }

    static func findTextField(in element: AXUIElement) -> AXUIElement? {
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
           let role = roleRef as? String,
           role == kAXTextFieldRole as String {
            return element
        }

        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                if let found = findTextField(in: child) {
                    return found
                }
            }
        }

        return nil
    }

    static func findButtonByDesc(in element: AXUIElement, matching descriptions: [String]) -> AXUIElement? {
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
           let role = roleRef as? String,
           role == kAXButtonRole as String {

            var descRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef) == .success,
               let desc = descRef as? String,
               descriptions.contains(desc) {
                return element
            }
        }

        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                if let found = findButtonByDesc(in: child, matching: descriptions) {
                    return found
                }
            }
        }

        return nil
    }

    static func findFavoriteButton(in element: AXUIElement, matching descriptions: [String]) -> AXUIElement? {
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
           let role = roleRef as? String,
           role == kAXButtonRole as String {

            var descRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef) == .success,
               let desc = descRef as? String,
               descriptions.contains(desc) {

                // Filter by size: transport bar favorite is ~27x20
                // Track list favorites are 18x45/59 (taller than wide)
                var sizeRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
                   let sizeValue = sizeRef {
                    var size = CGSize.zero
                    if AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) {
                        // Accept buttons that are wider than tall (transport bar style)
                        // or small square-ish buttons (22x22)
                        if size.width >= size.height || (size.width >= 20 && size.width <= 30 && size.height <= 30) {
                            return element
                        }
                    }
                }
            }
        }

        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                if let found = findFavoriteButton(in: child, matching: descriptions) {
                    return found
                }
            }
        }

        return nil
    }

    static func exploreButtons() {
        guard let window = findJPlayWindow() else { return }
        var buttons: [(desc: String, width: Int, height: Int)] = []
        collectButtons(in: window, into: &buttons)

        for btn in buttons {
            print("\(btn.desc) (\(btn.width)x\(btn.height))")
        }
    }

    static func collectButtons(in element: AXUIElement, into buttons: inout [(desc: String, width: Int, height: Int)]) {
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
           let role = roleRef as? String,
           role == kAXButtonRole as String {

            var desc = "(no description)"
            var descRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef) == .success,
               let d = descRef as? String, !d.isEmpty {
                desc = d
            }

            var width = 0, height = 0
            var sizeRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
               let sizeValue = sizeRef {
                var size = CGSize.zero
                if AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) {
                    width = Int(size.width)
                    height = Int(size.height)
                }
            }

            buttons.append((desc: desc, width: width, height: height))
        }

        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                collectButtons(in: child, into: &buttons)
            }
        }
    }

    static func findTextElements(pattern: String) {
        guard let window = findJPlayWindow() else { return }
        collectTextElements(in: window, pattern: pattern.lowercased())
    }

    static func collectTextElements(in element: AXUIElement, pattern: String) {
        // Check value, title, description attributes
        for attr in [kAXValueAttribute, kAXTitleAttribute, kAXDescriptionAttribute] as [CFString] {
            var ref: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, attr, &ref) == .success,
               let str = ref as? String,
               !str.isEmpty,
               (pattern.isEmpty || str.lowercased().contains(pattern)) {
                var roleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
                let role = roleRef as? String ?? "?"
                print("[\(role)] \(attr): \(str)")
            }
        }

        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                collectTextElements(in: child, pattern: pattern)
            }
        }
    }

    static func traceButtonPath() {
        guard let window = findJPlayWindow() else { return }
        if let button = findTransportButton(in: window, matching: ["Play", "Pause"]) {
            // Trace path from button back to window
            var path: [String] = []
            var current: AXUIElement? = button

            while let el = current {
                var parentRef: CFTypeRef?
                guard AXUIElementCopyAttributeValue(el, kAXParentAttribute as CFString, &parentRef) == .success,
                      let parent = parentRef else { break }

                let parentElement = parent as! AXUIElement

                // Find index of current element in parent's children
                var childrenRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(parentElement, kAXChildrenAttribute as CFString, &childrenRef) == .success,
                   let children = childrenRef as? [AXUIElement] {
                    for (idx, child) in children.enumerated() {
                        if CFEqual(child, el) {
                            var roleRef: CFTypeRef?
                            var role = "?"
                            if AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &roleRef) == .success,
                               let r = roleRef as? String {
                                role = r.replacingOccurrences(of: "AX", with: "")
                            }
                            path.insert("\(role)[\(idx)]", at: 0)
                            break
                        }
                    }
                }

                // Check if parent is window
                var roleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(parentElement, kAXRoleAttribute as CFString, &roleRef) == .success,
                   let role = roleRef as? String,
                   role == kAXWindowRole as String {
                    break
                }

                current = parentElement
            }

            print(path.joined(separator: " > "))
        } else {
            print("Play button not found")
        }
    }

    static func detectView() {
        guard let window = findJPlayWindow() else { return }
        var buttons: [(desc: String, width: Int, height: Int)] = []
        collectButtons(in: window, into: &buttons)

        let descriptions = Set(buttons.map { $0.desc })

        if descriptions.contains("Search") || descriptions.contains("Reload") {
            print("nowplaying")
        } else if descriptions.contains("CLEAR") {
            // Album and Sofa both have CLEAR, appear similar to accessibility
            print("album")
        } else {
            print("unknown")
        }
    }

    static func findTransportButton(in element: AXUIElement, matching descriptions: [String]) -> AXUIElement? {
        // Check if this element is a matching button
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
           let role = roleRef as? String,
           role == kAXButtonRole as String {

            // Check description
            var descRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef) == .success,
               let desc = descRef as? String,
               descriptions.contains(desc) {

                // Verify it's a transport button by size:
                // - Min 25px (filters out tiny 12x14 icons)
                // - Max 70px width (includes large 60px buttons, filters out 85px album Play)
                var sizeRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
                   let sizeValue = sizeRef {
                    var size = CGSize.zero
                    if AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) {
                        if size.width >= 25 && size.width <= 70 && size.height >= 20 {
                            return element
                        }
                    }
                }
            }
        }

        // Recursively search children
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
           let children = childrenRef as? [AXUIElement] {
            for child in children {
                if let found = findTransportButton(in: child, matching: descriptions) {
                    return found
                }
            }
        }

        return nil
    }
}
