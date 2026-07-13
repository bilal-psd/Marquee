import AppKit

enum StatusItemContextMenu {
    static func menu(for view: NSView) -> NSMenu? {
        var current: NSView? = view
        while let ancestor = current {
            if let panel = ancestor as? MenuBarPanelView {
                return panel.contextMenu
            }
            current = ancestor.superview
        }
        return nil
    }
}

/// Playback control button that forwards right-click context menus to the
/// parent `MenuBarPanelView` so the status-item menu works on controls too.
final class MenuBarButton: NSButton {
    override func menu(for event: NSEvent) -> NSMenu? {
        StatusItemContextMenu.menu(for: self)
    }
}

/// Idle-state label that forwards right-click context menus to the panel.
final class MenuBarIdleLabel: NSTextField {
    override func menu(for event: NSEvent) -> NSMenu? {
        StatusItemContextMenu.menu(for: self)
    }
}
