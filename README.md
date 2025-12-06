# jplay-ctl

Native macOS CLI to control JPlay (UPnP Player) via accessibility APIs.

## Features

- Control playback: play/pause, next, previous
- Works across all JPlay views (Default, Now Playing, Lounge)
- Fast native Swift implementation (~50-270ms vs 27s for AppleScript)
- Direct path access with recursive fallback

## Installation

### From releases

```bash
curl -L https://github.com/jkp/jplay-ctl/releases/latest/download/jplay-ctl-darwin-arm64 -o ~/.local/bin/jplay-ctl
chmod +x ~/.local/bin/jplay-ctl
```

### From source

```bash
git clone https://github.com/jkp/jplay-ctl.git
cd jplay-ctl
swift build -c release
cp .build/release/jplay-ctl ~/.local/bin/
```

## Usage

```bash
jplay-ctl play      # Toggle play/pause
jplay-ctl next      # Next track
jplay-ctl prev      # Previous track
jplay-ctl status    # Show current state
```

## Requirements

- macOS 12+
- JPlay (UPnP Player) running
- Accessibility permissions granted to the calling app (Terminal, Hammerspoon, etc.)

## Integration

### Hammerspoon

```lua
hs.hotkey.bind({"cmd"}, "f8", function()
    hs.execute("/Users/you/.local/bin/jplay-ctl play", true)
end)
```

## License

MIT
