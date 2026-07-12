# Marquee

A native macOS menu bar app that shows the currently playing track and provides playback controls for **Apple Music** and **Spotify**.

## Features

- Lives in the menu bar with inline playback controls and a scrolling track marquee — no click required
- Shows track title, artist, and playback state
- Play/pause, next, and previous controls inline in the menu bar
- Seamless scrolling marquee for long track titles
- Live updates via system distributed notifications
- Energy-conscious: scrolling and polling pause while the track is paused or the display is asleep

## Requirements

- macOS 13 or later
- Swift toolchain that can compile against the macOS SDK
- Apple Music and/or Spotify installed

### Toolchain note

If the system Swift compiler fails with an SDK version mismatch, install Homebrew Swift and rebuild:

```bash
brew install swift
./scripts/build_app.sh
```

The build script automatically uses `/opt/homebrew/opt/swift/bin/swiftc` when available.

## Build

```bash
chmod +x scripts/build_app.sh
./scripts/build_app.sh
```

This produces `Marquee.app` in the project root.

## Run

```bash
open Marquee.app
```

Controls and the scrolling now-playing text are always visible directly in the menu bar.

## First-run permissions

On first use, macOS will prompt you to allow Marquee to control **Music** and/or **Spotify**. Approve these in **System Settings → Privacy & Security → Automation** for playback controls to work.

## Development

Run directly without bundling:

```bash
swift run
```

Note: running via `swift run` may not show the Automation permission prompt correctly. Use the bundled `Marquee.app` for full behavior.

## Supported sources

| App | Bundle ID | Status |
|-----|-----------|--------|
| Apple Music | `com.apple.Music` | Supported |
| Spotify | `com.spotify.client` | Supported |

Other apps (browsers, podcasts, etc.) are not supported in this MVP.

## Architecture

- **ScriptingBridge** (via KVC) for reading metadata and sending playback commands, run on a background serial queue so the UI never stalls on Apple Event IPC
- **Distributed Notifications** for real-time track/state change updates, with low-frequency polling as a safety net
- **AppKit** inline menu bar view (`MenuBarPanelView`) hosted directly in the `NSStatusItem` button, with a `MarqueeLabel` that scrolls long titles as a seamless two-copy ticker. The scroll timer only runs while a track is playing, on-screen, and the display is awake — it is fully stopped when paused, hidden, or asleep

## License

MIT
