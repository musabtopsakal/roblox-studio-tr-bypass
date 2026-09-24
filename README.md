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
- Roblox Studio'nun kendisi standart `HTTPS_PROXY` ortam değişkenine,
  açılıştaki güncelleyicisi (`RobloxStudioInstaller`) ise macOS'un **sistem
  proxy** ayarına bakıyor — başlatıcı ikisini de sadece Studio açıkken ayarlar.
  (macOS `pf` ile şeffaf yönlendirme denendi, Mac'in kendi ürettiği trafiği
  yakalamadığı için çalışmadı.)

## Kurulum

```bash
git clone https://github.com/musabtopsakal/roblox-studio-tr-bypass.git
cd roblox-studio-tr-bypass
chmod +x install.sh
./install.sh
```

Gereksinimler: [Homebrew](https://brew.sh), Xcode Command Line Tools
(`xcode-select --install`). Script bir kere admin şifresi soracak (sadece
Roblox alan adlarının DNS'ini `/etc/resolver/` ile yerel dnscrypt-proxy'ye
yönlendirmek için — sistem DNS'in değişmez, diğer siteler etkilenmez).

Kurulum bitince masaüstünde **`RobloxStudioAc.command`** oluşur — Roblox
Studio'yu açmak için bundan sonra hep buna çift tıkla. Her açılışta admin
şifresi sorar, çünkü:

- Studio açıkken ciadpi ve **sistem SOCKS proxy'si** açılır (Studio'nun
  güncelleyicisi ortam değişkenini değil sistem proxy'sini kullanıyor).
- Studio (ve güncelleyicisi) **tamamen kapanınca** (Cmd+Q) proxy ve ciadpi
  **otomatik kapanır** — arka planda hiçbir şey açık kalmaz, internetin
  gereksiz yere yavaşlamaz.

> Studio açıkken tüm trafik proxy'den geçtiği için internet biraz
> yavaşlayabilir; bu normaldir, Studio'yu kapatınca geçer.

### Eski sürümden (v1) güncelleyenler

v1 sistem DNS'ini kalıcı olarak `127.0.0.1` yapıyor ve ciadpi'yi arka planda
açık bırakıyordu (internet yavaşlığı buradan). Önce `./uninstall.sh`, sonra
`git pull` ve `./install.sh` çalıştır.

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

Proxy'yi, Roblox DNS yönlendirmesini ve ciadpi'yi kapatır, masaüstündeki başlatıcıyı siler.

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
