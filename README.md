# Roblox Studio TR Bypass

Türkiye'de Roblox ve Roblox Studio, SNI-tabanlı DPI (Derin Paket İnceleme) ile
engelleniyor — DNS'i değiştirmek tek başına yetmiyor. Bu araç **macOS**'ta,
üçüncü parti VPN uygulaması veya abonelik olmadan, Roblox Studio'nun düzgün
çalışmasını sağlar.

> **English:** Roblox and Roblox Studio are blocked in Turkey via SNI-based
> DPI (not just DNS). This tool gets Roblox Studio working on macOS without
> a commercial VPN app or subscription — it fragments the TLS ClientHello so
> the DPI can't pattern-match the SNI, and routes DNS over HTTPS since plain
> UDP DNS queries for these domains are also dropped. See `install.sh`.

## Nasıl çalışıyor

Türkiye'deki engel iki katmanlı:

1. **DNS**: `roblox.com`/`rbxcdn.com` için düz UDP DNS sorguları (hangi
   sunucuya sorarsan sor) sessizce düşürülüyor.
2. **SNI**: DNS çözümlense bile, TLS bağlantısının ilk paketindeki SNI alanı
   ("roblox.com" gibi bir string) görülünce bağlantı RST ile kesiliyor.

Bu araç ikisini de aşıyor:

- **[dnscrypt-proxy](https://github.com/DNSCrypt/dnscrypt-proxy)** — DNS
  sorgularını şifreli DNS-over-HTTPS ile Cloudflare'e gönderir, düz UDP
  engelini atlatır.
- **[byedpi (ciadpi)](https://github.com/hufrea/byedpi)** — TLS
  ClientHello'yu SNI'nin ortasından iki ayrı TLS kaydına böler; DPI kutusu
  paket bazında baktığı için tam string'i bir arada görmüyor, gerçek sunucu
  ise TLS seviyesinde doğru şekilde yeniden birleştiriyor.
- Roblox Studio'nun kendi ağ kütüphanesi standart `HTTPS_PROXY` ortam
  değişkenine saygı gösteriyor (macOS'un genel sistem proxy ayarını
  **görmüyor** — bu yüzden macOS'un `pf` güvenlik duvarıyla şeffaf yönlendirme
  denendi ve çalışmadı; native uygulamalar için ortam değişkeni çok daha
  güvenilir çıktı).

## Kurulum

```bash
git clone https://github.com/<kullanici-adin>/roblox-studio-tr-bypass.git
cd roblox-studio-tr-bypass
chmod +x install.sh
./install.sh
```

Gereksinimler: [Homebrew](https://brew.sh), Xcode Command Line Tools
(`xcode-select --install`). Script bir kere admin şifresi soracak (sistem
DNS'ini yerel dnscrypt-proxy'ye yönlendirmek için).

Kurulum bitince masaüstünde **`RobloxStudioAc.command`** oluşur — Roblox
Studio'yu açmak için bundan sonra hep buna çift tıkla.

## Güncelleme indirme zaman aşımı

Roblox Studio kendini güncellerken (~500-600 MB) proxy üzerinden tek akış
bazen yavaş kalıp Studio'nun kendi zaman aşımına takılabilir
("Installer cannot connect to the Internet"). Bu durumda `parallel_dl.sh`
dosyayı paralel parçalar halinde indirir (zaman sınırı yok, kesintide kaldığı
yerden devam eder):

```bash
# Studio'nun log'undan indirme linkini bul:
tail -100 ~/Library/Logs/Roblox/RobloxStudioInstaller_*.log | grep "Failed to GET Target"

./parallel_dl.sh "<bulunan-URL>" RobloxStudioApp.zip 8
unzip RobloxStudioApp.zip -d extracted
mv /Applications/RobloxStudio.app /Applications/RobloxStudio.app.eski
mv extracted/RobloxStudio.app /Applications/RobloxStudio.app
```

## Kaldırma

```bash
./uninstall.sh
```

Sistem DNS'ini ve ciadpi'yi kapatır, masaüstündeki başlatıcıyı siler.

## Sınırlar

- Sadece **macOS**. Windows/Linux için `byedpi` kendi başına çalışır ama bu
  reponun kurulum/başlatıcı scriptleri macOS'a özel.
- ciadpi varsayılan olarak Mac'i yeniden başlattığında otomatik açılmıyor —
  `RobloxStudioAc.command`'ı çalıştırmak yeterli, kendini başlatıyor.
- Türkiye'nin engelleme yöntemi değişirse (örn. IP bazlı engele geçilirse)
  bu yöntem yetersiz kalabilir.

## Lisans

MIT — bkz. `LICENSE`. Bağımlılıklar (`dnscrypt-proxy`, `byedpi`) kendi
lisanslarıyla, bu repo tarafından indirilip derlenir, kaynak kodları
yeniden dağıtılmaz.
