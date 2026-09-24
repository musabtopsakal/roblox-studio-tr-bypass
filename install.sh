#!/bin/bash
# Roblox Studio TR Bypass - kurulum
# Turkiye'de Roblox/Roblox Studio SNI-tabanli DPI ile engelleniyor. Bu script:
#   1. dnscrypt-proxy kurar (DNS sorgulari sifreli/DoH ile cozulur, duz UDP DNS engeli asilir)
#   2. ciadpi (byedpi) kurar+derler (TLS ClientHello'yu SNI ortasindan iki ayri kayda bolerek
#      basit DPI string-eslestirmesini atlatir) - kaynak: https://github.com/hufrea/byedpi
#   3. SADECE Roblox alan adlarinin DNS'ini yerel dnscrypt-proxy'ye yonlendirir (/etc/resolver,
#      sistem DNS'i degismez, sudo ister)
#   4. Roblox Studio'yu proxy uzerinden acan bir .command dosyasi olusturur: ciadpi + sistem
#      proxy'si sadece Studio acikken calisir, Studio kapaninca otomatik kapanir
#
# Hicbir adim Roblox'un kendisini veya App Store disi bir uygulama indirmez;
# sadece acik kaynakli iki kucuk arac (dnscrypt-proxy, byedpi) kurulur.

set -e

INSTALL_DIR="$HOME/RobloxStudioTRBypass"
CIADPI_DIR="$INSTALL_DIR/byedpi"
SOCKS_PORT=1080
ROBLOX_DOMAINS="roblox.com rbxcdn.com rbx.com robloxlabs.com"

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

# --- 4) sadece Roblox alan adlari icin DNS (tek sudo adimi) ---
# Sistem DNS'ine dokunulmaz: /etc/resolver/<alan> ile SADECE Roblox sorgulari yerel
# dnscrypt-proxy'ye gider, diger her sey normal DNS'ten. Internet yavaslamaz.
echo
echo "--- Roblox DNS yonlendirmesi icin admin sifresi gerekiyor ---"
sudo bash -c "
  brew services restart dnscrypt-proxy
  mkdir -p /etc/resolver
  for d in $ROBLOX_DOMAINS; do echo 'nameserver 127.0.0.1' > /etc/resolver/\$d; done
  dscacheutil -flushcache
  killall -HUP mDNSResponder
"

# --- 5) Roblox Studio baslatici ---
# Acilista ciadpi + sistem SOCKS proxy'sini acar (Studio'nun guncelleyicisi ortam degiskenini
# degil sistem proxy'sini kullaniyor). Studio tamamen kapaninca ikisini de otomatik kapatir.
LAUNCHER="$INSTALL_DIR/RobloxStudioAc.command"
cat > "$LAUNCHER" << LAUNCHEREOF
#!/bin/bash
# Roblox Studio TR Bypass - gunluk baslatici. Cift tikla.
# Studio acikken proxy acik, Studio kapaninca her sey otomatik kapanir.
SOCKS_PORT=$SOCKS_PORT
SERVICE="$ACTIVE_SERVICE"
CIADPI_BIN="$CIADPI_DIR/ciadpi"

STUDIO="/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio"
if [ ! -x "\$STUDIO" ]; then
  echo "RobloxStudio.app bulunamadi (/Applications altinda). Once Roblox Studio'yu kur:"
  echo "https://www.roblox.com/create"
  read -p "Devam etmek icin Enter'a bas..."
  exit 1
fi

echo "Sistem proxy'si icin admin sifresi gerekiyor (Studio kapaninca otomatik kapanir):"
sudo -v || exit 1

if ! lsof -iTCP:\$SOCKS_PORT -sTCP:LISTEN -P >/dev/null 2>&1; then
  echo "ciadpi baslatiliyor..."
  nohup "\$CIADPI_BIN" -i 127.0.0.1 -p \$SOCKS_PORT --disorder 1 --tlsrec 1+s \\
    -b 131072 -c 1024 > "$INSTALL_DIR/ciadpi.log" 2>&1 &
  disown
  sleep 2
fi

sudo networksetup -setsocksfirewallproxy "\$SERVICE" 127.0.0.1 \$SOCKS_PORT
sudo networksetup -setsocksfirewallproxystate "\$SERVICE" on

# Bekci: "RobloxStudio" ile baslayan hic surec (Studio + RobloxStudioInstaller) kalmayinca
# proxy'yi kapatir, ciadpi'yi oldurur. ciadpi SIGTERM'i yok sayiyor, -9 sart.
sudo nohup bash -c "
  sleep 20
  while pgrep -q '^RobloxStudio'; do sleep 5; done
  networksetup -setsocksfirewallproxystate '\$SERVICE' off
  pkill -9 -f 'ciadpi -i 127.0.0.1 -p \$SOCKS_PORT'
" >/dev/null 2>&1 &

export HTTPS_PROXY="socks5h://127.0.0.1:\$SOCKS_PORT"
export HTTP_PROXY="socks5h://127.0.0.1:\$SOCKS_PORT"
export ALL_PROXY="socks5h://127.0.0.1:\$SOCKS_PORT"
export https_proxy="socks5h://127.0.0.1:\$SOCKS_PORT"
export http_proxy="socks5h://127.0.0.1:\$SOCKS_PORT"
export all_proxy="socks5h://127.0.0.1:\$SOCKS_PORT"

# Turkce locale'de Studio "5.5" gibi ondalik sayilari okuyamiyor ("Malformed number").
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

echo "Roblox Studio proxy uzerinden aciliyor..."
"\$STUDIO" &
disown
sleep 1
exit 0
LAUNCHEREOF
chmod +x "$LAUNCHER"
cp "$LAUNCHER" "$HOME/Desktop/RobloxStudioAc.command" 2>/dev/null || true
chmod +x "$HOME/Desktop/RobloxStudioAc.command" 2>/dev/null || true

echo
echo "=== Kurulum tamamlandi ==="
echo "Roblox Studio'yu acmak icin: Masaustundeki 'RobloxStudioAc.command' dosyasina cift tikla."
echo
echo "Studio acikken proxy acik; Studio tamamen kapaninca proxy ve ciadpi otomatik kapanir."
