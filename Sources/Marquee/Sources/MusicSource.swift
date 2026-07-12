import Foundation

protocol MusicSource: AnyObject {
    var id: String { get }
    var displayName: String { get }
    var notificationName: Notification.Name { get }

    var isRunning: Bool { get }
    func snapshot() -> NowPlaying?
    func playPause()
    func nextTrack()
    func previousTrack()
    func seek(to position: TimeInterval)
    func isPlaying() -> Bool
}
