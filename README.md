# Marquee

A small macOS menu bar app that shows what you're listening to and lets you control playback — without opening Apple Music or Spotify.

Controls and a scrolling track title sit right in the menu bar. No popover, no extra click.

## Install

```bash
brew install --cask bilal-psd/tap/marquee
```

**Requirements:** macOS 13 (Ventura) or later, and Apple Music and/or Spotify installed.

## First launch

macOS may block the app the first time because it is not notarized. If that happens, run:

```bash
xattr -dr com.apple.quarantine "/Applications/Marquee.app"
```

Then open Marquee from Applications.

## Permissions

The first time you use the controls, macOS will ask to let Marquee control **Music** and/or **Spotify**. Allow it under:

**System Settings → Privacy & Security → Automation**

## Supported apps

- Apple Music
- Spotify

Other music apps (browsers, podcast players, etc.) are not supported yet.

## License

MIT
