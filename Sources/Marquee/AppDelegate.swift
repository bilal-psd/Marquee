import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panelView: MenuBarPanelView!
    private let playbackController = PlaybackController()
    private var cancellables = Set<AnyCancellable>()

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

    private func updateStatusItemWidth() {
        let width = panelView.intrinsicContentSize.width
        guard abs(statusItem.length - width) > 0.5 else { return }
        statusItem.length = width
        panelView.layoutSubtreeIfNeeded()
    }
}
