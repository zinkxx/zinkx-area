# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Bu proje nedir

Zinkx Arena: macOS 15+ üzerinde RPCS3 emülatörü için tam ekran, kontrolcüyle yönetilen, PS5 tarzı bir konsol başlatıcısı. Tamamen SwiftUI + AppKit ile yazılmıştır ve harici Swift paketi kullanmaz. Swift modülü, çalıştırılabilir dosya ve kaynak klasörü hâlâ eski adı olan `PlayHub` ile anılır; uygulama paketi ise `Zinkx Arena.app`'tir (bundle id `com.zinkx.playhub`).

## Derleme ve çalıştırma

```bash
./build.sh                                   # yerel derleme → build/Zinkx Arena.app (ad-hoc imzalı)
UNIVERSAL=1 ./build.sh                       # lipo ile arm64 + x86_64
./scripts/package_release.sh                 # universal derleme + dist/ZinkxArena-<sürüm>-macOS-universal.zip (+ .sha256)
open "build/Zinkx Arena.app" --args --demo   # prosedürel üretilmiş kurgusal oyunlarla çalıştır
"build/Zinkx Arena.app/Contents/MacOS/PlayHub" --export-screenshots <klasör>   # doküman ekran görüntülerini üret ve kapan
python3 scripts/l10n_check.py                # çeviri dosyalarında eksik/fazla/bozuk anahtar kontrolü
```

- `build.sh`, `Sources/PlayHub/*.swift` dosyalarını doğrudan `swiftc` ile derler (`-parse-as-library -swift-version 5`); `swift build` kullanmaz. `Package.swift` esas olarak editör/SourceKit desteği içindir. Yeni kaynak dosyaları derlenmesi için `Sources/PlayHub/` içine konmalıdır.
- Uygulama ikonu kodla üretilir: `scripts/make_icon/main.swift` + `Sources/PlayHub/Logo.swift` → `build/AppIcon.icns`. Yalnızca bu iki dosyadan biri değiştiğinde yeniden üretilir. Bu yüzden `Logo.swift`, diğer uygulama dosyalarına bağımlı olmadan `make_icon` ile tek başına derlenebilmelidir.
- Sürüm numarası `Resources/Info.plist` içindeki `CFBundleShortVersionString` değerinden gelir. Üç parçalı yazılır (ör. `2.1.0`) ve git etiketiyle (`v2.1.0`) birebir aynı olmalıdır; sürüm artırılırken `CFBundleVersion` da bir artırılır ve `CHANGELOG.md` güncellenir. CI (`.github/workflows/build.yml`, macos-15) her push ve PR'da `package_release.sh` çalıştırır. `v*` etiketi push edildiğinde zip bir GitHub release'ine eklenir.
- `build.sh`, `Resources/*.lproj` klasörlerini paketin `Contents/Resources` dizinine kopyalar.
- Test ve linter yoktur. Kabul ölçütü, "`./build.sh` başarılı" olması ve `--demo` modunda elle kontrol edilmesidir (PR şablonuna bakın).

## Mimari

**Pencere/uygulama yaşam döngüsü (`PlayHubApp.swift`).** SwiftUI `App` yalnızca boş bir `Settings` sahnesi tanımlar. Asıl arayüz, `AppDelegate`'in oluşturduğu ve `HomeView`'ı bir `NSHostingView` içinde barındıran özel, kenarlıksız `ConsoleWindow: NSWindow` penceresidir. `sizingOptions = []` ve `constrainFrameRect` override'ı SwiftUI/AppKit kısıt döngülerini önlemek için bilinçli olarak vardır; bunu SwiftUI `WindowGroup` ile değiştirmeyin. `AppDelegate.ensureFullScreen()` pencereyi `AppSettings.shared.targetScreen` ekranına yeniden sabitler (çoklu monitör, `⌘E`). Statik `AppDelegate.isGameActive` bayrağı, RPCS3 öndeyken arayüz ve kontrolcü işlerini durdurmak için kod tabanının her yerinde kontrol edilir.

**Durum nesneleri.** `AppDelegate`; `GameLibrary`, `DetailsStore`, `InputManager` ve `GameLauncher` nesnelerinin sahibidir ve bunları `AppSettings.shared` ile birlikte `environmentObject` olarak enjekte eder. Geri kalan her şey `static let shared` singleton'dır (`AudioManager`, `ToastCenter`, `GameMediaStore`, `PerfProfileStore`, `SmartDS4Manager`, `InGameOverlayManager`, `WrapUpStore`, `UserAccountStore`, `ImageCache`). Tüm kalıcı veriler `UserDefaults.standard` içinde tutulur (istatistikler, profiller, performans profilleri ve hesaplar için JSON kodlanmış `Codable` veriler).

**Girdi yönlendirme.** `InputManager`, `GCController` olaylarını ve klavye tuş kodlarını (`NSEvent` yerel monitörü ile) `NavAction` enum'una çevirir ve `HomeView.wire()`'ın kurduğu closure'ları çağırır:
- `onActivity` önce çalışır ve girdiyi yutabilir (açılış animasyonu, ekran koruyucu).
- `onAction`, `HomeView.handle(_:)`'a gider. Bu tek fonksiyon, katman durumları üzerinde bir öncelik zinciridir (hata bildirimi → seçenekler menüsü → profil düzenleyici → kullanıcı seçimi → detay ekranı → …) ve ardından `Tab`'a göre dağıtır (`handleGames`, `handleTrophies`, `handleProfile`, `handleSettings`).
- `onCloseCombo` (Share+Options 1,5 sn basılı) oyun içi menüyü açıp kapatır.

Yeni ekranlar veya katmanlar bu zincire bir dal eklemeyi gerektirir. Gezinme odak indeksine dayalıdır (SwiftUI focus sistemi kullanılmaz). Yerel bir metin alanı etkinken `InputManager.suspended = true` yapın.

**Oyun başlatma döngüsü (`GameLauncher.swift`).**
1. `/Applications/RPCS3.app`, `--no-gui [--fullscreen] [--config <PerfProfileStore'dan oyuna özel yml>] <EBOOT>` argümanlarıyla başlatılır.
2. RPCS3'ün aynı Space üzerinde tam ekrana geçebilmesi için önce `AppDelegate.prepareForGameLaunch()` konsol penceresini gizler.
3. Oyun açıkken bir tam ekran watchdog çalışır.
4. RPCS3 kapandığında `onFinished`, oynama süresini `GameLibrary`'ye kaydeder ve `AppDelegate.restoreFromGame()` kontrolcüleri zorla yeniden bağlar.

Oyuna özel RPCS3 ayarları (`custom_configs/config_<TITLEID>.yml`) her başlatmada `PerfProfileStore.writeRPCS3Config` tarafından `config.yml` + sabit değerlerden yeniden yazılır; dosyayı elle düzenlemek kalıcı olmaz, değişiklik bu fonksiyonda yapılmalıdır (GTA IV ailesi için özel değerler orada).

Oyun çalışırken `GameActivity.shared.isActive` true olur: `HomeView` içeriği kaldırılır, `WavesView` durur ve ffmpeg medya dönüştürmeleri duraklatılır (`GameMediaStore.setPaused`), böylece emülatörle CPU/disk için yarışılmaz.

Oyun çalışırken RPCS3'ün USB HID erişimi tek başına kendisinde olsun diye kontrolcü yoklaması ve lightbar yazımları askıya alınır.

**Kütüphane ve ikili dosya ayrıştırma.**
- `GameLibrary`; `~/Games/PS3`, `/Volumes/*/PS3 Games`, RPCS3'ün `games.yml` / `dev_hdd0/game` dizinleri ve kullanıcının eklediği klasörleri tarar. Diskler takılıp çıkarıldığında yeniden tarar.
- `PARAM.SFO` ayrıştırıcısı `Models.swift` içindedir.
- `GameDetails.swift` (`DetailsStore`), `TROPHY.TRP`, `TROPUSR.DAT` ve savedata dosyalarını ayrıştırır ve RPCS3 uyumluluk bilgisini çeker.
- `GameMedia.swift`, `SND0.AT3` sesini ve `.PAM`/`.BIK` videolarını önbelleğe alır; kuruluysa harici `ffmpeg` ile dönüştürür.

**Ayarlar arayüzü.** Ayar enum'ları `SettingOption` protokolüne uyar (`Settings.swift`) ve `AppSettings` üzerinde `@Published` olarak tutulur. Her ayar, ayarlar ekranına `SettingsBuilder.rows` (`SettingsView.swift`) içinde bir `SettingRow` olarak eklenir; bunlar `AppSettings` içine `KeyPath` alan `toggle`/`choice`/`slider` yardımcılarıyla oluşturulur.

**Yerelleştirme (`L10n.swift`).** Arayüz metinleri `L("Türkçe metin")` ile yazılır; Türkçe metin aynı zamanda çeviri anahtarıdır. Çeviriler `Resources/<dil>.lproj/Localizable.strings` dosyalarındadır (en, de, fr, es, ja, zh-Hans, ko).
- `\(değer)` interpolasyonları anahtarda `%@` olur; çeviriler `%1$@`, `%2$@` ile sırayı değiştirebilir. İlk tam sayı 1 ise varsa `"<anahtar>##one"` tekil biçimi kullanılır.
- Çalışma anında belli olan anahtarlar (ör. kayıtlı tür adı) `L(key:)` ile çevrilir. Saklanan değerler Türkçe anahtar olarak kalır ve `LKey("...")` ile işaretlenir (bkz. `AppSettings.genres`).
- Dil `AppSettings.language` (`AppLanguage`, varsayılan `.system`) ile seçilir ve `L10n.apply` tabloyu yükler. `HomeView` içeriği `.id(settings.language)` ile yeniden kurulur, böylece dil değişimi anında uygulanır.
- `static let` içinde `L(...)` kullanmayın: değer ilk erişimdeki dilde donar.
- Tarih, sayı ve boyut formatlarında `L10n.locale` kullanın (`Format.relative`, `Format.percent`); `Locale(identifier: "tr_TR")` sabit yazmayın.
- Yüzde gibi `%` içeren metinleri interpolasyonla birleştirmeyin; `Format.percent` kullanın.
- Ekran klavyesinin harf dizilimi dile göre değişir (`ProfileEditorController.letterRows`).
- Yeni metin ekledikten sonra 7 dil dosyasına da çevirisini ekleyin ve `scripts/l10n_check.py` çalıştırın. Komut 0 dışında bir kodla çıkarsa eksik ya da bozuk çeviri var demektir.

**Demo modu (`DemoShowcase.swift`).** `--demo` ve `--export-screenshots`, depoları kurgusal oyunlar ve prosedürel çizilmiş görsellerle doldurur. `GameLibrary` ve `InputManager`, gerçek disk taramasını ve kontrolcü sorgusunu atlamak için bu bayrakları kendileri kontrol eder.

## Proje kuralları

- **Asla telifli içerik yok.** ROM, ISO, PKG, firmware/BIOS, anahtar veya ticari görsel eklemeyin ya da bunlara link vermeyin (`LEGAL_DISCLAIMER.md`, `CONTRIBUTING.md`). Ekran görüntüleri ve videolar `--demo` modundan alınmalı; `docs/screenshots/` içeriği `--export-screenshots` ile üretilir.
- Arayüz metinlerinin kaynağı Türkçedir ve `L(...)` içinde yazılır (bkz. Yerelleştirme). Demo modundaki kurgusal oyun içeriği (kupa adları vb.) bilerek çevrilmez. Kod yorumları İngilizcedir.
