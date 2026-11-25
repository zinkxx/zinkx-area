# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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

[2.0.0]: https://github.com/zinkxx/zinkx-arena/releases/tag/v2.0.0
