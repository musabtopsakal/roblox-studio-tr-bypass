#!/bin/bash
# Roblox Studio TR Bypass - kurulum
# Turkiye'de Roblox/Roblox Studio SNI-tabanli DPI ile engelleniyor. Bu script:
#   1. dnscrypt-proxy kurar (DNS sorgulari sifreli/DoH ile cozulur, duz UDP DNS engeli asilir)
#   2. ciadpi (byedpi) kurar+derler (TLS ClientHello'yu SNI ortasindan iki ayri kayda bolerek
#      basit DPI string-eslestirmesini atlatir) - kaynak: https://github.com/hufrea/byedpi
#   3. Sistem DNS'ini yerel dnscrypt-proxy'ye yonlendirir (sadece bu adim sudo ister)
#   4. Roblox Studio'yu proxy uzerinden acan bir .command dosyasi olusturur (ciadpi calismiyorsa
#      onu da kendisi baslatir - kalici/otomatik bir sistem servisi KURULMAZ, bilincli tercih)
#
# Hicbir adim Roblox'un kendisini veya App Store disi bir uygulama indirmez;
# sadece acik kaynakli iki kucuk arac (dnscrypt-proxy, byedpi) kurulur.

set -e

INSTALL_DIR="$HOME/RobloxStudioTRBypass"
CIADPI_DIR="$INSTALL_DIR/byedpi"
SOCKS_PORT=1080

echo "=== Roblox Studio TR Bypass kurulumu ==="
echo "Kurulum klasoru: $INSTALL_DIR"
echo

# --- on kosullar ---
if ! command -v brew >/dev/null 2>&1; then
  echo "HATA: Homebrew bulunamadi. Once https://brew.sh adresinden kurup tekrar calistir."
  exit 1
fi
if ! command -v git >/dev/null 2>&1 || ! command -v make >/dev/null 2>&1 || ! command -v clang >/dev/null 2>&1; then
  echo "HATA: Xcode Command Line Tools eksik. Terminal'de 'xcode-select --install' calistirip"
  echo "kurulum bittikten sonra bu scripti tekrar calistir."
  exit 1
fi

mkdir -p "$INSTALL_DIR"

# --- 1) dnscrypt-proxy ---
echo "--- dnscrypt-proxy kuruluyor ---"
if ! brew list dnscrypt-proxy >/dev/null 2>&1; then
  brew install dnscrypt-proxy
fi
DNSCRYPT_CONF="/usr/local/etc/dnscrypt-proxy.toml"
if [ -f "$DNSCRYPT_CONF" ]; then
  if grep -q "^# server_names" "$DNSCRYPT_CONF" 2>/dev/null; then
    sed -i '' "s/^# server_names.*/server_names = ['cloudflare']/" "$DNSCRYPT_CONF"
  fi
fi

# --- 2) ciadpi (byedpi) kaynak koddan derleniyor ---
echo "--- byedpi (ciadpi) indirilip derleniyor ---"
if [ ! -d "$CIADPI_DIR" ]; then
  git clone --depth 1 https://github.com/hufrea/byedpi.git "$CIADPI_DIR"
fi
(cd "$CIADPI_DIR" && make)

# --- 3) aktif ag servisini bul ---
ACTIVE_IF=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
ACTIVE_SERVICE=$(networksetup -listnetworkserviceorder | grep -B1 "Device: $ACTIVE_IF" | head -1 | sed -E 's/^\([0-9]+\) //')
if [ -z "$ACTIVE_SERVICE" ]; then
  echo "UYARI: aktif ag servisi otomatik bulunamadi, 'Wi-Fi' varsayilacak."
  ACTIVE_SERVICE="Wi-Fi"
fi
echo "Aktif ag servisi: $ACTIVE_SERVICE"

# --- 4) sistem DNS'i (tek sudo adimi) ---
echo
echo "--- Sistem DNS'ini yerel dnscrypt-proxy'ye yonlendirmek icin admin sifresi gerekiyor ---"
sudo bash -c "
  brew services restart dnscrypt-proxy
  networksetup -setdnsservers '$ACTIVE_SERVICE' 127.0.0.1
  dscacheutil -flushcache
  killall -HUP mDNSResponder
"

# --- 5) ciadpi'yi simdi baslat (kalici servis degil, sadece bu oturum icin) ---
if ! lsof -iTCP:$SOCKS_PORT -sTCP:LISTEN -P >/dev/null 2>&1; then
  nohup "$CIADPI_DIR/ciadpi" -i 127.0.0.1 -p "$SOCKS_PORT" --disorder 1 --tlsrec 1+s \
    -b 131072 -c 1024 > "$INSTALL_DIR/ciadpi.log" 2>&1 &
  disown
fi

# --- 6) Roblox Studio baslatici ---
LAUNCHER="$INSTALL_DIR/RobloxStudioAc.command"
cat > "$LAUNCHER" << LAUNCHEREOF
#!/bin/bash
# Roblox Studio TR Bypass - gunluk baslatici. Cift tikla.
SOCKS_PORT=$SOCKS_PORT
CIADPI_BIN="$CIADPI_DIR/ciadpi"

if ! lsof -iTCP:\$SOCKS_PORT -sTCP:LISTEN -P >/dev/null 2>&1; then
  echo "ciadpi baslatiliyor..."
  nohup "\$CIADPI_BIN" -i 127.0.0.1 -p \$SOCKS_PORT --disorder 1 --tlsrec 1+s \\
    -b 131072 -c 1024 > "$INSTALL_DIR/ciadpi.log" 2>&1 &
  disown
  sleep 2
fi

export HTTPS_PROXY="socks5h://127.0.0.1:\$SOCKS_PORT"
export HTTP_PROXY="socks5h://127.0.0.1:\$SOCKS_PORT"
export ALL_PROXY="socks5h://127.0.0.1:\$SOCKS_PORT"
export https_proxy="socks5h://127.0.0.1:\$SOCKS_PORT"
export http_proxy="socks5h://127.0.0.1:\$SOCKS_PORT"
export all_proxy="socks5h://127.0.0.1:\$SOCKS_PORT"

STUDIO="/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio"
if [ ! -x "\$STUDIO" ]; then
  echo "RobloxStudio.app bulunamadi (/Applications altinda). Once Roblox Studio'yu kur:"
  echo "https://www.roblox.com/create"
  read -p "Devam etmek icin Enter'a bas..."
  exit 1
fi

echo "Roblox Studio proxy uzerinden aciliyor..."
"\$STUDIO" &
sleep 1
LAUNCHEREOF
chmod +x "$LAUNCHER"
cp "$LAUNCHER" "$HOME/Desktop/RobloxStudioAc.command" 2>/dev/null || true
chmod +x "$HOME/Desktop/RobloxStudioAc.command" 2>/dev/null || true

echo
echo "=== Kurulum tamamlandi ==="
echo "Roblox Studio'yu acmak icin: Masaustundeki 'RobloxStudioAc.command' dosyasina cift tikla."
echo
echo "NOT: ciadpi su an calisiyor ama Mac'i yeniden baslattiginda otomatik acilmiyor"
echo "(bilincli tercih: sessiz arka plan servisi kurmadik). Bir sonraki sefer sadece"
echo "RobloxStudioAc.command'a cift tikla, ciadpi'yi kendisi baslatir."
