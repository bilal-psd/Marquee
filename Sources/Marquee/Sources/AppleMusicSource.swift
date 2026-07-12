import Foundation
import ScriptingBridge

final class AppleMusicSource: MusicSource {
    let id = "com.apple.Music"
    let displayName = "Apple Music"
    let notificationName = Notification.Name("com.apple.Music.playerInfo")

    private let bundleIdentifier = "com.apple.Music"

    // Cached SBApplication. Only accessed from PlaybackController's serial poll
    // queue, so no locking is required.
    private var cachedApp: SBApplication?

    private func app() -> SBApplication? {
        if let cachedApp, cachedApp.isRunning { return cachedApp }
        cachedApp = nil
        guard let app = SBApplication(bundleIdentifier: bundleIdentifier), app.isRunning else {
            return nil
        }
        cachedApp = app
        return app
    }

    var isRunning: Bool { app() != nil }

    func isPlaying() -> Bool {
        guard let app = app() else { return false }
        return SBHelpers.isPlaying(app)
    }

    func snapshot() -> NowPlaying? {
        guard let app = app(), let track = app.value(forKey: "currentTrack") else {
            return nil
        }

        let title = SBHelpers.string(from: track, key: "name") ?? "Unknown Track"
        let artist = SBHelpers.string(from: track, key: "artist") ?? "Unknown Artist"
        let album = SBHelpers.string(from: track, key: "album") ?? ""
        let duration = SBHelpers.double(from: track, key: "duration") ?? 0
        let elapsed = SBHelpers.double(from: app, key: "playerPosition") ?? 0

        return NowPlaying(
            title: title,
            artist: artist,
            album: album,
            isPlaying: SBHelpers.isPlaying(app),
            duration: duration,
            elapsed: elapsed,
            sourceName: displayName,
            sourceID: id
        )
    }

    func playPause() {
        guard let app = app() else { return }
        SBHelpers.perform(app, "playpause")
    }

    func nextTrack() {
        guard let app = app() else { return }
        SBHelpers.perform(app, "nextTrack")
    }

    func previousTrack() {
        guard let app = app() else { return }
        SBHelpers.perform(app, "previousTrack")
    }

    func seek(to position: TimeInterval) {
        app()?.setValue(position, forKey: "playerPosition")
    }
}
