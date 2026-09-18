# Network Pulse

Network Pulse is a native SwiftUI macOS app for viewing live upload and download traffic. It includes a full dashboard and a compact menu-bar companion.

It runs `sysctl` with c interface in a repeating timer.

Use at your own risk.

# Features

1. Live upload and download speeds in the Dock app and menu bar.
2. Real-time traffic charts with 5-minute, 15-minute, and 1-hour ranges.
3. Session transfer totals and peak speeds.
4. Automatic or manual network-interface selection.
5. Start at login and configurable 1s, 2s, 5s, 10s, or 30s updates.
6. Pause/resume monitoring, clear session history, and open Activity Monitor.

# Build and run

Open `NetSpeedMonitor.xcodeproj` in Xcode, or run:

```sh
./script/build_and_run.sh
```

# Note

For per-process network traffic monitoring, it usually requires `nettop` which is quite cpu-heavy making it impractical to keep running at the background. Implementing it to run only when the user click the status item to make the menu showing may be a good choice.

From v1.8, the UI is built using SwiftUI, on macOS 15, with minimum system version macOS 14.6. Since I haven't successfully built it with lower version of github action runner images, it is what it is now. Later if I have the chance, I would make it compatible with lower version of macOS.

Any PR for feature enhancement or compatibility improvement is welcomed!

# Screenshot

![](./screenshot.png)
