import Foundation
import ScriptingBridge

enum PlayerStateCode {
    static let playing: UInt32 = 0x6b505350 // 'kPSP'
    static let paused: UInt32 = 0x6b505370  // 'kPSp'
    static let stopped: UInt32 = 0x6b505353  // 'kPSS'
}

enum SBHelpers {
    static func runningApp(bundleIdentifier: String) -> SBApplication? {
        guard let app = SBApplication(bundleIdentifier: bundleIdentifier), app.isRunning else {
            return nil
        }
        return app
    }

    static func isPlaying(_ app: SBApplication) -> Bool {
        guard let state = app.value(forKey: "playerState") as? NSNumber else { return false }
        return state.uint32Value == PlayerStateCode.playing
    }

    static func perform(_ app: SBApplication, _ command: String) {
        let selector = NSSelectorFromString(command)
        guard app.responds(to: selector) else { return }
        _ = app.perform(selector)
    }

    static func string(from object: Any?, key: String) -> String? {
        guard let object else { return nil }
        if let sbObject = object as? SBObject {
            return sbObject.value(forKey: key) as? String
        }
        return (object as AnyObject).value(forKey: key) as? String
    }

    static func double(from object: Any?, key: String) -> Double? {
        guard let object else { return nil }
        let value: Any?
        if let sbObject = object as? SBObject {
            value = sbObject.value(forKey: key)
        } else {
            value = (object as AnyObject).value(forKey: key)
        }
        return (value as? NSNumber)?.doubleValue
    }

    static func int(from object: Any?, key: String) -> Int? {
        guard let object else { return nil }
        let value: Any?
        if let sbObject = object as? SBObject {
            value = sbObject.value(forKey: key)
        } else {
            value = (object as AnyObject).value(forKey: key)
        }
        return (value as? NSNumber)?.intValue
    }
}
