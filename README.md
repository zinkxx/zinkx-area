<div align="center">

![Zinkx Arena Hero Banner](docs/screenshots/hero-banner.png)

# ⚡ ZINKX ARENA

**macOS (Apple Silicon & Intel) için PlayStation 5 Tarzı Tam Ekran Konsol Arayüzü, Kupa Motoru ve Kütüphane Yöneticisi**  
*Next-Generation Native SwiftUI & AppKit Console Frontend, Trophy Parser, and Smart Controller Suite for macOS*

[![Platform](https://img.shields.io/badge/Platform-macOS%2015%2B%20(Apple%20Silicon%20%26%20Intel)-0070F2?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/zinkxx/zinkx-area)
[![Swift](https://img.shields.io/badge/Swift-5.10%20%2F%206.0-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![UI](https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-5E5CE6?style=for-the-badge)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-MIT-22C55E?style=for-the-badge)](LICENSE)
[![Legal](https://img.shields.io/badge/Policy-Zero%20ROMs%20%7C%20Anti--Piracy-EAB308?style=for-the-badge)](LEGAL_DISCLAIMER.md)

[**🇹🇷 Türkçe Dokümantasyon**](#-türkçe-dokümantasyon) · [**📸 Ekran Görüntüleri**](#-ekran-görüntüleri--screenshots) · [**✨ Özellikler**](#-öne-çıkan-özellikler) · [**🚀 Kurulum**](#-kurulum-ve-derleme) · [**🇬🇧 English Documentation**](#-english-documentation) · [**⚖️ Yasal Uyarı**](LEGAL_DISCLAIMER.md)

</div>

---

> [!IMPORTANT]
> **⚖️ Yasal Uyarı ve Korsan Karşıtı Politika (Legal & Anti-Piracy Notice)**  
> **Zinkx Arena**, yalnızca yerel medya kütüphanenizi yönetmek için geliştirilmiş **bağımsız ve açık kaynaklı bir grafiksel kullanıcı arayüzüdür (Frontend / Launcher)**.  
> - Bu depoda **hiçbir ticari oyun dosyası (`ISO`, `ROM`, `PKG`, `EBOOT.BIN`), Sony sistem yazılımı (`PS3UPDAT.PUP`), BIOS dökümü, şifreleme anahtarı veya telifli görsel/ses materyali bulunmamaktadır**.  
> - Uygulama içerisinde hiçbir oyun indirme bağlantısı veya korsan içerik sağlayıcısı yer almaz.  
> - Bu sayfada ve `--demo` modunda yer alan tüm oyun isimleri (*Cyber Drift: Neon Horizon*, *Aether Chronicles: Odyssey*, *Valkyrie Protocol Zero* vb.) ile kapak görselleri, CoreGraphics ile prosedürel olarak çizilmiş **%100 özgün ve kurgusal (homebrew) vitrin içerikleridir**.  
> - Kullanıcılar bu arayüzü yalnızca **yasal olarak satın aldıkları fiziksel disklerinden kendi oluşturdukları kişisel yedekleriyle** veya yasal homebrew yazılımlarla kullanmakla yükümlüdür. Detaylar için [LEGAL_DISCLAIMER.md](LEGAL_DISCLAIMER.md) dosyasına göz atabilirsiniz.

---

## 📸 Ekran Görüntüleri / Screenshots

### 1. Ana Konsol Medya Merkezi (Home Media Hub)
Oyun kartları, dinamik arka plan görselleri, disk medya galerisi, canlı kontrolcü pil durumu, aktif ekran seçici (`⌘E`) ve alt bilgi rafı (`InfoShelf`).

![Ana Konsol Ekranı](docs/screenshots/01-home-hub.png)

---

### 2. Oyun Detayları, `PARAM.SFO` Analizi ve Oyun Bazlı Performans Profili
Her oyun için ikili `PARAM.SFO` başlık okuyucu, çözünürlük/FPS/Shader profili seçici, açılan kupalar ve kayıt dosyası (`savedata`) kartları.

![Oyun Detayları ve Performans Profili](docs/screenshots/02-game-details.png)

---

### 3. Kupa Odası ve Seviye Hesaplayıcı (`TROPHY.TRP` & `TROPUSR.DAT`)
Harici bir veritabanına ihtiyaç duymadan doğrudan arşivlenmiş `TROPHY.TRP` ve `TROPUSR.DAT` ikili dosyalarını ayrıştırarak Platin, Altın, Gümüş ve Bronz kupaları ve oyuncu kupa seviyesini hesaplar.

![Kupa Odası](docs/screenshots/03-trophy-room.png)

---

### 4. Oyuncu Profili, Haftalık Aktivite Grafiği ve Rozetler (Gamer Wrap-Up)
Son 7 günlük oynama süresi sütun grafiği, kazanılabilir oyuncu rozetleri (*Arena Kurucusu*, *Koleksiyoncu*, *Gece Kuşu*, *Kupa Avcısı*, *Maratoncu*) ve en çok oynanan oyunlar vitrini.

![Oyuncu Profili ve Aktivite](docs/screenshots/04-profile-wrapup.png)

---

### 5. Hızlı Kontrol Merkezi (Bottom Control Center Dock)
Oyun kumandasındaki **Options / Menü** tuşuyla açılan PS5 tarzı alt hızlı erişim çubuğu: sekme geçişi, çoklu monitör değiştirme, disk müziği kontrolü, kütüphane yenileme ve uyku modu.

![Kontrol Merkezi](docs/screenshots/05-control-center.png)

---

### 6. "Kim Oynuyor?" Çoklu Kullanıcı Girişi ve Kontrolcü Ekran Klavyesi
Tamamen gamepad ile yönetilebilen çoklu oyuncu profili seçici ve konsol tarzı sanal ekran klavyesi (`On-Screen Keyboard`).

![Çoklu Kullanıcı Girişi](docs/screenshots/06-user-login.png)

---

## 🇹🇷 Türkçe Dokümantasyon

### ✨ Öne Çıkan Özellikler

* **🎮 %100 Kontrolcü Odaklı Konsol Deneyimi (`GameController.framework`)**
  * DualShock 4, DualSense ve Xbox kontrolcüleriyle sıfır gecikmeli menü gezintisi.
  * **Akıllı Işık Çubuğu (Smart Lightbar / Ambilight)**: Seçili oyunun kapak görselinden baskın renk paletini gerçek zamanlı örnekleyerek DualShock 4 / DualSense LED ışık çubuğuna yansıtır. Ayrıca *Tema Rengi*, *Polis Sireni* ve *Altın Kupa* ışık efektleri içerir.
  * **Oyun İçi Çakışma Koruması**: Emülatör başladığında arka plan USB HID pil ve LED sorgularını otomatik askıya alarak USB-C çoklayıcılarda yaşanan kontrolcü/ses kopmalarını önler.
* **🏆 Yerel `TROPHY.TRP` ve `TROPUSR.DAT` İkili Kupa Motoru**
  * Oyun klasöründeki `TROPHY.TRP` arşivlerini ve `TROPUSR.DAT` durum tablolarını doğrudan Swift ile byte düzeyinde ayrıştırır (`0xDCA24D00` ve `0x818F54AD` big-endian tabloları).
  * Kupa ikonlarını (`TROP000.PNG`..), kupa açıklamalarını (`TROPCONF.SFM`) ve kilit açılma zaman damgalarını otomatik çıkarır.
* **💿 Otomatik Disk Medya Çıkarıcı (`SND0.AT3`, `.PAM`, `.BIK`, `PIC1.PNG`)**
  * Oyun üzerinde gezinirken arka plan tema müziğini (`SND0.AT3`) ve tanıtım videolarını (`ffmpeg` entegrasyonuyla) önbelleğe alarak konsol ana ekranında oynatır.
* **🖥️ Çoklu Monitör ve Tam Ekran Pencere Yöneticisi (`⌘E`)**
  * Özel AppKit `ConsoleWindow` mimarisi sayesinde macOS kısıt döngüsü (constraint loop) çökmelerine yol açmadan anında kenarlıksız tam ekran (`1920×1080` / Retina) açılır.
  * Tek tuşla (`⌘E`, üst çubuk ekran hapı veya Kontrol Merkezi) hem **Zinkx Arena** arayüzünü hem de RPCS3 tam ekran hedef monitörünü (`CurrentSettings.ini` -> `[GSFrame]`) harici monitör ile MacBook ekranı arasında taşır.
* **⚙️ Oyun Bazlı Performans Profilleri (`custom_configs`)**
  * Her oyun için ayrı çözünürlük ölçeği (`540p %75`, `720p %100`, `1080p %150`, `1440p %200`), kare hızı sınırı (`30 FPS`, `60 FPS`, `Otomatik`) ve Shader derleyici modu (`Async Multi-threaded` / `Legacy`) yapılandırması üretir.
* **🧪 Dahili Demo Vitrin Modu (`--demo`)**
  * Bilgisayarında henüz oyun yedeği bulunmayan geliştiriciler ve kullanıcılar, `--demo` bayrağıyla tamamen prosedürel üretilmiş 6 kurgusal oyun, kupa seti ve aktivite verisiyle tüm konsol arayüzünü deneyimleyebilir.

---

### 🚀 Kurulum ve Derleme

#### Gereksinimler
* **macOS 15.0+** (Apple Silicon M1/M2/M3/M4 veya Intel)
* **Xcode Command Line Tools** (`xcode-select --install`)
* *(İsteğe bağlı)* Yasal oyun yedeklerinizi çalıştırmak için `/Applications/RPCS3.app`
* *(İsteğe bağlı)* Disk içi `.AT3` / `.BIK` medya dönüştürmesi için `ffmpeg` (`brew install ffmpeg`)

#### 1. Depoyu Klonlayın ve Derleyin
```bash
git clone https://github.com/zinkxx/zinkx-area.git
cd zinkx-area
./build.sh
```
Derleme tamamlandığında imzalanmış uygulama paketi `build/Zinkx Arena.app` konumunda oluşturulur.

#### 2. Uygulamayı Başlatın
```bash
# Uygulamalar klasörüne kopyalayıp başlatmak için:
cp -R "build/Zinkx Arena.app" "/Applications/Zinkx Arena.app"
open "/Applications/Zinkx Arena.app"

# Veya kurgusal vitrin oyunlarıyla Demo Modunda test etmek için:
open "build/Zinkx Arena.app" --args --demo
```

#### 3. Kendi Yasal Oyun Yedeklerinizi Tanıtma
**Zinkx Arena** açılışta şu konumları otomatik tarar:
1. `~/Games/PS3` klasörü
2. Bağlı harici disklerdeki `/Volumes/*/PS3 Games` klasörleri (disk takıldığında veya çıkarıldığında otomatik yenilenir)
3. RPCS3'ün `~/Library/Application Support/rpcs3/games.yml` ve `dev_hdd0/game` dizinleri
4. Uygulama içinden **Ayarlar → Oyun Klasörü Ekle** seçeneğiyle eklediğiniz özel klasörler

---

### 🗂️ Proje Mimarisi

| Dosya | Açıklama |
| :--- | :--- |
| `Sources/PlayHub/PlayHubApp.swift` | Özel AppKit `ConsoleWindow` tam ekran pencere yöneticisi ve uygulama yaşam döngüsü |
| `Sources/PlayHub/HomeView.swift` | Ana konsol ekranı, sekme yönetimi, kısayollar ve katman geçişleri |
| `Sources/PlayHub/GameLibrary.swift` | Disk/klasör tarayıcı, otomatik harici disk algılama ve oynama süresi istatistikleri |
| `Sources/PlayHub/Models.swift` | `Game` modeli ve ikili `PARAM.SFO` (System File Object) ayrıştırıcısı |
| `Sources/PlayHub/GameDetails.swift` | `TROPHY.TRP` arşiv açıcı, `TROPUSR.DAT` okuyucu, `savedata` analizörü ve uyumluluk API istemcisi |
| `Sources/PlayHub/GameMedia.swift` | `SND0.AT3` ses ve `.PAM` / `.BIK` video önbellekleme motoru |
| `Sources/PlayHub/GameLauncher.swift` | RPCS3 süreç başlatıcı, çoklu monitör tam ekran senkronizasyonu ve watchdog |
| `Sources/PlayHub/InputManager.swift` | `GCController` gamepad ve klavye navigasyon motoru |
| `Sources/PlayHub/SmartControllerAndOverlay.swift` | DualShock 4 / DualSense Ambilight LED yöneticisi, oyun bazlı performans profili üreticisi ve oyun içi hızlı menü |
| `Sources/PlayHub/ConsoleFeatures.swift` | PS5 tarzı bildirim tostları (`PS5ToastOverlay`), Kupa Odası (`TrophyRoomView`) ve alt Kontrol Merkezi (`ControlCenterDock`) |
| `Sources/PlayHub/UsersAndWrapUp.swift` | 7 günlük aktivite grafiği, oyuncu rozetleri ve "Kim Oynuyor?" çoklu profil ekranı |
| `Sources/PlayHub/OnScreenKeyboard.swift` | Kontrolcüyle yönetilen profil düzenleyici ve konsol ekran klavyesi |
| `Sources/PlayHub/DemoShowcase.swift` | Telifsiz kurgusal vitrin oyunları, prosedürel kapak çizici ve otomatik ekran görüntüsü üreticisi (`--export-screenshots`) |

---

### 🎮 Kontrolcü ve Klavye Kısayolları

| Eylem | DualShock / DualSense | Klavye |
| :--- | :--- | :--- |
| **Seç / Oyunu Başlat** | `✕` (Cross) | `Enter` veya `Space` |
| **Geri / İptal** | `○` (Circle) | `Esc` veya `Backspace` |
| **Oyun Detayları / Yenile** | `△` (Triangle) | `T` |
| **Favorilere Ekle / Çıkar** | `□` (Square) | `F` |
| **Sekme Değiştir** | `L1` / `R1` | `Q` / `E` |
| **Hızlı Kontrol Merkezi** | `Options` | `Tab` |
| **Aktif Monitörü Değiştir** | Kontrol Merkezi → Ekran | `⌘E` |
| **Oyunu Kapat (Oyun İçinde)** | `Share + Options` (1.5 sn basılı tut) | `⌘Q` |

---

## 🇬🇧 English Documentation

### Overview
**Zinkx Arena** is a native macOS console-style launcher and library organizer for [RPCS3](https://rpcs3.net), crafted purely in **SwiftUI and AppKit** with zero external Swift package dependencies. It transforms your Mac into a living-room console experience with full gamepad navigation, DualShock 4 / DualSense Ambilight LED synchronization, binary `TROPHY.TRP` & `PARAM.SFO` parsing, multi-monitor switching, and per-game performance profiles.

### Key Highlights
* **Borderless Instant Fullscreen Architecture**: Custom `ConsoleWindow: NSWindow` avoids SwiftUI window constraint loops and supports seamless multi-display switching (`⌘E`).
* **Binary `PARAM.SFO`, `TROPHY.TRP` & `TROPUSR.DAT` Parsers**: Built-in big-endian binary parsers unpack trophy icons, localized XML metadata, unlock timestamps, and save-data headers directly from your legally dumped game folders.
* **Smart Controller Lightbar & USB HID Guard**: Extracts vibrant cover colors for Ambilight controller LEDs and automatically suspends background `GCController` XPC polling while a game is running so RPCS3 retains exclusive, uninterrupted USB HID access.
* **100% DMCA & Copyright Safe**: Includes a procedural `--demo` and `--export-screenshots` engine (`DemoShowcase.swift`) that generates original fictional homebrew titles and vector cover art—no copyrighted assets, ROMs, BIOS, or keys are ever stored or linked.

### Quick Start (English)
```bash
git clone https://github.com/zinkxx/zinkx-area.git
cd zinkx-area
./build.sh

# Launch with your local game backups:
open "build/Zinkx Arena.app"

# Or preview the UI with procedurally generated demo games:
open "build/Zinkx Arena.app" --args --demo
```

---

## 📄 Lisans / License

Bu proje [MIT Lisansı](LICENSE) altında lisanslanmıştır. Hukuki bilgilendirme, ticari marka beyanı ve korsan karşıtı kullanım politikası için [LEGAL_DISCLAIMER.md](LEGAL_DISCLAIMER.md) dosyasını inceleyebilirsiniz.
