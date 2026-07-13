import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panelView: MenuBarPanelView!
    private let playbackController = PlaybackController()
    private var cancellables = Set<AnyCancellable>()

    private let githubURL = URL(string: "https://github.com/bilal-psd/Marquee")!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        observePlaybackChanges()
        observeDisplaySleep()
    }

    private func setupStatusItem() {
        panelView = MenuBarPanelView(controller: playbackController)
        panelView.onWidthChange = { [weak self] in
            self?.updateStatusItemWidth()
        }
        panelView.contextMenu = buildContextMenu()
        panelView.translatesAutoresizingMaskIntoConstraints = false

        statusItem = NSStatusBar.system.statusItem(withLength: panelView.intrinsicContentSize.width)
        guard let button = statusItem.button else { return }

        button.subviews.forEach { $0.removeFromSuperview() }
        button.addSubview(panelView)

        button.action = nil
        button.target = nil
        button.image = nil
        button.title = ""
        button.sendAction(on: [])

        NSLayoutConstraint.activate([
            panelView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            panelView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            panelView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            panelView.heightAnchor.constraint(equalToConstant: NSStatusBar.system.thickness),
        ])

        updateStatusItemWidth()
    }

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()

        let aboutItem = NSMenuItem(title: "About Marquee", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let githubItem = NSMenuItem(title: "View on GitHub", action: #selector(openGitHub), keyEquivalent: "")
        githubItem.target = self
        menu.addItem(githubItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Marquee", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func observePlaybackChanges() {
        playbackController.$nowPlaying
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusItemWidth()
            }
            .store(in: &cancellables)
    }

    private func observeDisplaySleep() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            self,
            selector: #selector(displaysDidSleep),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(displaysDidWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
    }

    @objc private func displaysDidSleep() {
        playbackController.suspend()
        panelView.setDisplayAwake(false)
    }

    @objc private func displaysDidWake() {
        playbackController.resume()
        panelView.setDisplayAwake(true)
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func openGitHub() {
        NSWorkspace.shared.open(githubURL)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func updateStatusItemWidth() {
        let width = panelView.intrinsicContentSize.width
        guard abs(statusItem.length - width) > 0.5 else { return }
        statusItem.length = width
        panelView.layoutSubtreeIfNeeded()
    }
}
