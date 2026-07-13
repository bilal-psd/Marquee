# Developing Marquee

Technical notes for building, running, and releasing Marquee from source.

## Requirements

- macOS 13 or later
- Swift toolchain that can compile against the macOS SDK
- Apple Music and/or Spotify (for testing playback integration)

### Toolchain note

If the system Swift compiler fails with an SDK version mismatch, install Homebrew Swift and rebuild:

```bash
brew install swift
./scripts/build_app.sh
```

The build script automatically uses `/opt/homebrew/opt/swift/bin/swiftc` when available.

## Build from source

```bash
chmod +x scripts/build_app.sh
./scripts/build_app.sh
```

This produces `Marquee.app` in the project root.

```bash
open Marquee.app
```

## Run without bundling

```bash
swift run
```

Note: `swift run` may not show the Automation permission prompt correctly. Use the bundled `Marquee.app` for full behavior.

## Supported sources

| App | Bundle ID | Status |
|-----|-----------|--------|
| Apple Music | `com.apple.Music` | Supported |
| Spotify | `com.spotify.client` | Supported |

## Architecture

- **ScriptingBridge** (via KVC) for reading metadata and sending playback commands, run on a background serial queue so the UI never stalls on Apple Event IPC
- **Distributed Notifications** for real-time track/state change updates, with low-frequency polling as a safety net
- **AppKit** inline menu bar view (`MenuBarPanelView`) hosted directly in the `NSStatusItem` button, with a `MarqueeLabel` that scrolls long titles as a seamless two-copy ticker. The scroll timer only runs while a track is playing, on-screen, and the display is awake — it is fully stopped when paused, hidden, or asleep

## Releasing via Homebrew

Marquee is distributed through a personal tap: [bilal-psd/homebrew-tap](https://github.com/bilal-psd/homebrew-tap).

To publish a new version:

1. Build and zip the app:

   ```bash
   ./scripts/build_app.sh
   ditto -c -k --sequesterRsrc --keepParent Marquee.app "Marquee-X.Y.Z.zip"
   shasum -a 256 "Marquee-X.Y.Z.zip"
   ```

2. Tag and create a GitHub release with the zip asset:

   ```bash
   git tag vX.Y.Z
   git push origin vX.Y.Z
   gh release create vX.Y.Z Marquee-X.Y.Z.zip
   ```

3. Update `Casks/marquee.rb` in the tap with the new `version` and `sha256`, then push.

The release asset must be publicly downloadable (the Marquee repo is public for this reason).

### Code signing

Current builds are ad-hoc signed (`codesign --sign -`). Users must clear Gatekeeper quarantine on first install. For a warning-free install experience, sign with a Developer ID certificate and notarize via `notarytool`.
