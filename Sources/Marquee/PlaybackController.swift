import Combine
import Foundation

/// Owns music-source selection and publishes the current now-playing state.
///
/// Threading model: all `@Published` state and `activeSource` are only mutated
/// on the main thread. The synchronous ScriptingBridge / Apple Event work is
/// performed on `pollQueue` (a serial queue), and the resulting snapshot is
/// published back on main. `MusicSource` instances are therefore only ever
/// touched from `pollQueue`.
final class PlaybackController: ObservableObject {
    @Published private(set) var nowPlaying: NowPlaying?

    private let sources: [MusicSource]
    private var activeSource: MusicSource?
    private var pollTimer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var refreshWorkItem: DispatchWorkItem?
    private var suspended = false

    private let pollQueue = DispatchQueue(label: "com.marquee.poll", qos: .utility)

    // Notifications drive most updates; polling is only a low-frequency safety
    // net to catch app launches / state changes that don't emit a notification.
    private let pollInterval: TimeInterval = 10
    private let refreshDebounce: TimeInterval = 0.2

    init(sources: [MusicSource] = [AppleMusicSource(), SpotifySource()]) {
        self.sources = sources
        subscribeToNotifications()
        refresh()
        startPollTimer()
    }

    deinit {
        pollTimer?.invalidate()
        observers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
    }

    // MARK: - Controls

    func playPause() {
        let source = activeSource
        pollQueue.async { source?.playPause() }
        requestRefresh()
    }

    func nextTrack() {
        let source = activeSource
        pollQueue.async { source?.nextTrack() }
        requestRefresh()
    }

    func previousTrack() {
        let source = activeSource
        pollQueue.async { source?.previousTrack() }
        requestRefresh()
    }

    // MARK: - Lifecycle gating (e.g. display sleep)

    func suspend() {
        guard !suspended else { return }
        suspended = true
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func resume() {
        guard suspended else { return }
        suspended = false
        startPollTimer()
        requestRefresh()
    }

    // MARK: - Refresh

    private func subscribeToNotifications() {
        for source in sources {
            let observer = DistributedNotificationCenter.default().addObserver(
                forName: source.notificationName,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.requestRefresh(preferredSourceID: source.id)
            }
            observers.append(observer)
        }
    }

    /// Coalesces bursts of refresh requests (e.g. notification floods, rapid
    /// track skips) into a single refresh.
    private func requestRefresh(preferredSourceID: String? = nil) {
        refreshWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.refresh(preferredSourceID: preferredSourceID)
        }
        refreshWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + refreshDebounce, execute: item)
    }

    private func refresh(preferredSourceID: String? = nil) {
        let currentActiveID = activeSource?.id

        pollQueue.async { [weak self] in
            guard let self else { return }

            let playingSource = self.sources.first { $0.isRunning && $0.isPlaying() }
            let preferredSource = preferredSourceID.flatMap { id in
                self.sources.first { $0.id == id && $0.isRunning }
            }
            let lastActiveSource = currentActiveID.flatMap { id in
                self.sources.first { $0.id == id && $0.isRunning }
            }

            let selected = playingSource ?? preferredSource ?? lastActiveSource
                ?? self.sources.first { $0.isRunning }
            let snapshot = selected?.snapshot()

            DispatchQueue.main.async {
                self.activeSource = selected
                self.nowPlaying = snapshot
            }
        }
    }

    private func startPollTimer() {
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.requestRefresh()
        }
        timer.tolerance = pollInterval * 0.25
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }
}
