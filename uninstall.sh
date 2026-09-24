#!/bin/bash
# install.sh'in yaptigi sistem degisikliklerini geri alir.
set -e

echo "=== Roblox Studio TR Bypass kaldiriliyor ==="

pkill -9 -f "byedpi/ciadpi" 2>/dev/null || true  # SIGTERM yok sayiliyor

ACTIVE_IF=$(route -n get default 2>/dev/null | awk '/interface:/{print $2}')
ACTIVE_SERVICE=$(networksetup -listnetworkserviceorder | grep -B1 "Device: $ACTIVE_IF" | head -1 | sed -E 's/^\([0-9]+\) //')
[ -z "$ACTIVE_SERVICE" ] && ACTIVE_SERVICE="Wi-Fi"

echo "--- Proxy ve Roblox DNS yonlendirmesi kaldiriliyor (admin sifresi gerekiyor) ---"
sudo bash -c "
  networksetup -setsocksfirewallproxystate '$ACTIVE_SERVICE' off
  rm -f /etc/resolver/roblox.com /etc/resolver/rbxcdn.com /etc/resolver/rbx.com /etc/resolver/robloxlabs.com
  # eski surum (v1) sistem DNS'ini 127.0.0.1 yapiyordu; onu da geri al
  [ \"\$(networksetup -getdnsservers '$ACTIVE_SERVICE')\" = 127.0.0.1 ] && networksetup -setdnsservers '$ACTIVE_SERVICE' empty
  dscacheutil -flushcache
  killall -HUP mDNSResponder
  brew services stop dnscrypt-proxy 2>/dev/null || true
"

rm -f "$HOME/Desktop/RobloxStudioAc.command"
echo
echo "Kaldirildi. '$HOME/RobloxStudioTRBypass' klasorunu (ciadpi kaynagi + loglar) istersen"
echo "elle silebilirsin: rm -rf '$HOME/RobloxStudioTRBypass'"
