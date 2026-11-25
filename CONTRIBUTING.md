# Contributing / Katkıda Bulunma

Thanks for your interest in Zinkx Arena! / Zinkx Arena'ya ilgin için teşekkürler!

## Ground rules / Temel kurallar
- **No copyrighted material.** Never add or link ROMs, ISOs, PKGs, BIOS/firmware, keys or commercial artwork. See [LEGAL_DISCLAIMER.md](LEGAL_DISCLAIMER.md).
  **Telifli içerik yok.** ROM, ISO, PKG, BIOS/firmware, anahtar veya ticari görsel eklemeyin ve bunlara link vermeyin.
- Screenshots and videos must use the built-in `--demo` mode. / Ekran görüntüleri ve videolar `--demo` moduyla alınmalıdır.

## Development / Geliştirme
```bash
./build.sh                                  # native build → build/Zinkx Arena.app
open "build/Zinkx Arena.app" --args --demo  # try it with demo data
UNIVERSAL=1 ./build.sh                      # Apple Silicon + Intel
```
Requirements: macOS 15+, Xcode Command Line Tools (Swift 6 toolchain, Swift 5 language mode). No external dependencies.

## Pull requests
1. Fork the repo and create a branch from `main`.
2. Keep changes focused; describe what changed and how you tested it (ideally with a `--demo` screenshot for UI changes).
3. Make sure `./build.sh` succeeds; the GitHub Actions build must be green.

## Reporting bugs / Hata bildirimi
Use the issue templates. Include your macOS version, Mac model (Apple Silicon/Intel), RPCS3 version and controller model.
