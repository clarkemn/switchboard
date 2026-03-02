# Switchboard

A native macOS application for [Granted](https://granted.dev).

## Features

- **Profile Management** - Parse and display profiles from `~/.aws/config` and `~/.aws/credentials`
- **Terminal Integration** - Launch Terminal, iTerm2, or Warp with profile set
- **AWS Console** - Open AWS Console directly with your chosen profile
- **Search & Filter** - Find profiles by name, account ID, or region

## Requirements

- macOS 14.0 (Sonoma) or later
- Swift 5.9+ (for building from source)
- AWS CLI
- [Granted](https://granted.dev)

## Installation

### Via Homebrew

```bash
brew install --cask clarkemn/tap/switchboard
```

### From Source

```bash
# Clone and build
git clone https://github.com/clarkemn/switchboard.git
cd switchboard
./build.sh release

# Install
cp -r .build/Switchboard.app /Applications/

# Launch
open /Applications/Switchboard.app
```

## License

MIT License - see [LICENSE](LICENSE)
