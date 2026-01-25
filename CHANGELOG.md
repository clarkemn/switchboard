# Changelog

All notable changes to Switchboard will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-12

### Added

- Initial release of Switchboard
- AWS config and credentials file parsing
- Support for multiple AWS profile types:
  - Static credentials
  - AWS SSO
  - Assume Role profiles
- Menu bar interface with:
  - Profile search and filtering
  - Quick actions context menu
  - Profile type indicators
- Terminal launcher support for:
  - Terminal.app
  - iTerm2
  - Warp
- Profile validation using AWS CLI
- Real-time file watching for config changes
- Preferences window with customization options:
  - Terminal application selection
  - Display preferences
  - File watching toggle
- AWS Console launcher (basic implementation)
- Copy to clipboard actions:
  - Copy profile name
  - Copy account ID
  - Copy export command
- Unit tests for INI parser

[1.0.0]: https://github.com/clarkemn/switchboard/releases/tag/v1.0.0
