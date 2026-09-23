#!/bin/bash
# install.sh'in yaptigi sistem degisikliklerini geri alir.
set -e

echo "=== Roblox Studio TR Bypass kaldiriliyor ==="

pkill -f "byedpi/ciadpi" 2>/dev/null || true

ACTIVE_IF=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
ACTIVE_SERVICE=$(networksetup -listnetworkserviceorder | grep -B1 "Device: $ACTIVE_IF" | head -1 | sed -E 's/^\([0-9]+\) //')
[ -z "$ACTIVE_SERVICE" ] && ACTIVE_SERVICE="Wi-Fi"

echo "--- Sistem DNS'i eski haline donduruluyor (admin sifresi gerekiyor) ---"
sudo bash -c "
  networksetup -setdnsservers '$ACTIVE_SERVICE' empty
  dscacheutil -flushcache
  killall -HUP mDNSResponder
  brew services stop dnscrypt-proxy 2>/dev/null || true
"

rm -f "$HOME/Desktop/RobloxStudioAc.command"
echo
echo "Kaldirildi. '$HOME/RobloxStudioTRBypass' klasorunu (ciadpi kaynagi + loglar) istersen"
echo "elle silebilirsin: rm -rf '$HOME/RobloxStudioTRBypass'"
