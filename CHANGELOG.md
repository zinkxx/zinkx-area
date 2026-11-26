# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [2.1.0] - 2026-11-26

### Added
- UI localization: English, German, French, Spanish, Japanese, Simplified Chinese and Korean alongside Turkish. The language follows macOS by default and can be changed live in Settings → Appearance → Language.
- Dates, relative times, play time, percentages and file sizes are formatted for the selected language.
- The on-screen keyboard uses a matching layout for German (QWERTZ), French (AZERTY), Spanish and English.
- `scripts/l10n_check.py` checks every translation file for missing, unused or broken entries.

### Changed
- The profile screen's action buttons are stacked in one column so longer translations fit.
- GTA IV: the per-game RPCS3 settings are documented in code, and the audio buffer was raised from 150 ms to 200 ms to reduce stutter.
- Sharper image on Retina displays. RPCS3 output is now upscaled with FidelityFX Super Resolution instead of bilinear stretching, and 16x anisotropic filtering is forced. In testing, Need for Speed Undercover at the 1080p profile ran at 55–60 fps on an M1 MacBook Air.

### Fixed
- The console UI no longer competes with RPCS3 for CPU while a game runs. The hidden home screen used to keep animating at roughly 40% of a core. Its view tree is now dropped during play, and the background wave animation stops.
- ffmpeg disc-media conversions are paused while a game runs and resume afterwards, so they no longer compete for CPU or for the game disk.
- The background wave animation is capped at 30 fps on the home screen.

## [2.0.0] - 2026-11-25

First public release.

### Added
- Fullscreen, controller-first console frontend for RPCS3, written in native SwiftUI + AppKit.
- Library scanning: `~/Games/PS3`, external `/Volumes/*/PS3 Games`, RPCS3 `games.yml` and `dev_hdd0/game`, custom folders.
- Binary `PARAM.SFO`, `TROPHY.TRP` and `TROPUSR.DAT` parsers: trophy room, trophy level and unlock timestamps.
- Per-game performance profiles (resolution scale, FPS limit, shader mode) written to RPCS3 `custom_configs`.
- Multi-display switching for both the UI and RPCS3 fullscreen output (`⌘E`).
- DualShock 4 / DualSense lightbar colors sampled from game cover art.
- Disc media extraction (`SND0.AT3`, `.PAM`, `.BIK`, `PIC1.PNG`).
- Multi-user "Who's playing?" profiles, weekly activity chart, badges and an on-screen keyboard.
- `--demo` mode with procedurally generated, copyright-free showcase games and `--export-screenshots`.
- Universal (Apple Silicon + Intel) release builds via `scripts/package_release.sh` and GitHub Actions.

[Unreleased]: https://github.com/zinkxx/zinkx-arena/compare/v2.1.0...HEAD
[2.1.0]: https://github.com/zinkxx/zinkx-arena/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/zinkxx/zinkx-arena/releases/tag/v2.0.0
