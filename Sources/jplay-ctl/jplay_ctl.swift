import ApplicationServices
import Cocoa

@main
struct JPlayCtl {
    static func main() {
        let args = CommandLine.arguments
        guard args.count >= 2 else {
            printUsage()
            exit(1)
        }

        let command = args[1]

        switch command {
        case "play":
            exit(clickTransportButton(matching: ["Play", "Pause"]) ? 0 : 1)
        case "next":
            exit(clickTransportButton(matching: ["Next"]) ? 0 : 1)
        case "prev":
            exit(clickTransportButton(matching: ["Previous"]) ? 0 : 1)
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
        case "inspect":
            inspectGroup()
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
          jplay-ctl play      Toggle play/pause
          jplay-ctl next      Next track
          jplay-ctl prev      Previous track
          jplay-ctl status    Show current state
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

    static func clickTransportButton(matching descriptions: [String]) -> Bool {
        guard let window = findJPlayWindow() else {
            return false
        }

        // Determine button offset: Prev=0, Play=1, Next=2 relative to Play position
        let buttonOffset: Int
        if descriptions.contains("Previous") {
            buttonOffset = -1
        } else if descriptions.contains("Next") {
            buttonOffset = 1
        } else {
            buttonOffset = 0  // Play/Pause
        }

        // Try direct paths in order (fastest first)
        if let (button, _) = tryDirectPath(window: window, buttonOffset: buttonOffset) {
            let result = AXUIElementPerformAction(button, kAXPressAction as CFString)
            if result == .success {
                return true
            }
        }

        // Fallback to recursive search
        if let button = findTransportButton(in: window, matching: descriptions) {
            let result = AXUIElementPerformAction(button, kAXPressAction as CFString)
            if result == .success {
                return true
            } else {
                fputs("error: Failed to press button (code: \(result.rawValue))\n", stderr)
                return false
            }
        }

        fputs("error: Button not found\n", stderr)
        return false
    }

    static func getChild(_ element: AXUIElement, at index: Int) -> AXUIElement? {
        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement],
              index >= 0 && index < children.count else {
            return nil
        }
        return children[index]
    }

    static func followPath(_ element: AXUIElement, path: [Int]) -> AXUIElement? {
        var current = element
        for index in path {
            guard let next = getChild(current, at: index) else {
                return nil
            }
            current = next
        }
        return current
    }

    static func isButtonWithDesc(_ element: AXUIElement, matching descriptions: [String]) -> Bool {
        var roleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
              let role = roleRef as? String,
              role == kAXButtonRole as String else {
            return false
        }

        var descRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &descRef) == .success,
              let desc = descRef as? String,
              descriptions.contains(desc) else {
            return false
        }

        return true
    }

    static func tryDirectPath(window: AXUIElement, buttonOffset: Int) -> (AXUIElement, String)? {
        let targetDesc = buttonOffset == -1 ? ["Previous"] : buttonOffset == 1 ? ["Next"] : ["Play", "Pause"]

        // Path 1: Lounge - Group[0] > Group[0] > Button[9/10/11]
        if let group = followPath(window, path: [0, 0]) {
            let buttonIndex = 10 + buttonOffset
            if let button = getChild(group, at: buttonIndex),
               isButtonWithDesc(button, matching: targetDesc) {
                return (button, "lounge")
            }
        }

        // Path 2: Now Playing - Group[0] > Group[0] > Group[1] > Group[0] > Group[6] > Button[0/1/2]
        if let group = followPath(window, path: [0, 0, 1, 0, 6]) {
            let buttonIndex = 1 + buttonOffset
            if let button = getChild(group, at: buttonIndex),
               isButtonWithDesc(button, matching: targetDesc) {
                return (button, "nowplaying")
            }
        }

        // Path 3: Default mini bar - two possible structures
        // Try: Group[0] > Group[0] > Group[1] > Group[0] > Group[0] > Group[0] > Group[1]
        // Trace showed Play at Button[0], so scan siblings for matching button
        if let group = followPath(window, path: [0, 0, 1, 0, 0, 0, 1]) {
            if let button = findButtonInGroup(group, matching: targetDesc) {
                return (button, "default")
            }
        }

        return nil
    }

    static func findButtonInGroup(_ group: AXUIElement, matching descriptions: [String]) -> AXUIElement? {
        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(group, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else {
            return nil
        }
        // Only check first 10 children max
        for i in 0..<min(10, children.count) {
            if isButtonWithDesc(children[i], matching: descriptions) {
                return children[i]
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

    static func inspectGroup() {
        guard let window = findJPlayWindow() else { return }

        // Inspect the default path group
        print("Default path [0,0,1,0,0,0,1]:")
        if let group = followPath(window, path: [0, 0, 1, 0, 0, 0, 1]) {
            printChildren(of: group)
        } else {
            print("  (path not found)")
        }

        print("\nLounge path [0,0]:")
        if let group = followPath(window, path: [0, 0]) {
            printChildren(of: group, startIndex: 8, count: 6)
        } else {
            print("  (path not found)")
        }

        print("\nNow Playing path [0,0,1,0,6]:")
        if let group = followPath(window, path: [0, 0, 1, 0, 6]) {
            printChildren(of: group)
        } else {
            print("  (path not found)")
        }
    }

    static func printChildren(of element: AXUIElement, startIndex: Int = 0, count: Int = 10) {
        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else {
            print("  (no children)")
            return
        }

        let endIndex = min(startIndex + count, children.count)
        for i in startIndex..<endIndex {
            let child = children[i]
            var roleRef: CFTypeRef?
            var descRef: CFTypeRef?
            var role = "?"
            var desc = ""

            if AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef) == .success,
               let r = roleRef as? String {
                role = r.replacingOccurrences(of: "AX", with: "")
            }
            if AXUIElementCopyAttributeValue(child, kAXDescriptionAttribute as CFString, &descRef) == .success,
               let d = descRef as? String {
                desc = d
            }

            print("  [\(i)] \(role): \(desc)")
        }
        print("  (total: \(children.count) children)")
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

                // Verify it's a reasonable button size (not tiny icons)
                var sizeRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
                   let sizeValue = sizeRef {
                    var size = CGSize.zero
                    if AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) {
                        // Accept buttons >= 25px (filters out tiny 12x14 icons)
                        if size.width >= 25 && size.height >= 20 {
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
