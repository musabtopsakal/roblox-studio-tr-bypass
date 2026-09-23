#!/bin/bash
# Yardimci arac: Roblox Studio kendi guncellemesini indirirken proxy uzerinden tek akis
# yavas kalip zaman asimina ugrarsa ("Installer cannot connect to the Internet" hatasi),
# ayni dosyayi burada N paralel parcaya bolup indirip birlestirebilirsin.
#
# Kullanim:
#   1. Studio'yu ac, guncelleme hatasi aldiginda log dosyasindaki indirme linkini bul:
#        tail -f ~/Library/Logs/Roblox/RobloxStudioInstaller_*.log | grep "Failed to GET"
#      "Failed to GET Target: https://setup.rbxcdn.com/..." satirindaki URL'yi kopyala.
#   2. ./parallel_dl.sh "<URL>" RobloxStudioApp.zip 8
#   3. Bittiginde: RobloxStudio.app'i ziple ac, eski /Applications/RobloxStudio.app'i
#      yedekleyip (mv ... .eski) yenisiyle degistir.
#
# set -e YOK: parca indirmeleri kendi ic retry donguleriyle hatalari yonetiyor.
URL="$1"
OUT="$2"
PARTS="${3:-8}"
SOCKS_PORT="${SOCKS_PORT:-1080}"

if [ -z "$URL" ] || [ -z "$OUT" ]; then
  echo "Kullanim: $0 <URL> <cikti-dosyasi> [parca-sayisi=8]"
  exit 1
fi

SIZE=$(curl -sS --socks5-hostname "127.0.0.1:$SOCKS_PORT" -I "$URL" | grep -i "^content-length:" | tr -d '\r' | awk '{print $2}')
if [ -z "$SIZE" ]; then
  echo "HATA: dosya boyutu alinamadi (proxy calisiyor mu? URL dogru mu?)"
  exit 1
fi
echo "Toplam boyut: $SIZE bayt, $PARTS parcaya bolunuyor"

CHUNK=$(( SIZE / PARTS ))
PIDS=()
for i in $(seq 0 $((PARTS - 1))); do
  START=$(( i * CHUNK ))
  if [ "$i" -eq $((PARTS - 1)) ]; then
    END=$(( SIZE - 1 ))
  else
    END=$(( START + CHUNK - 1 ))
  fi
  PART_FILE="${OUT}.part${i}"
  HAVE=0
  [ -f "$PART_FILE" ] && HAVE=$(stat -f%z "$PART_FILE" 2>/dev/null || echo 0)
  RANGE_START=$(( START + HAVE ))
  if [ "$RANGE_START" -gt "$END" ]; then
    echo "Parca $i zaten tamam, atlaniyor"
    continue
  fi
  (
    TMP="${PART_FILE}.tmp"
    while true; do
      CUR=$(stat -f%z "$PART_FILE" 2>/dev/null || echo 0)
      RS=$(( START + CUR ))
      if [ "$RS" -gt "$END" ]; then break; fi
      rm -f "$TMP"
      if curl -sS --socks5-hostname "127.0.0.1:$SOCKS_PORT" --max-time 60 \
        -r "${RS}-${END}" -o "$TMP" "$URL"; then
        cat "$TMP" >> "$PART_FILE"; rm -f "$TMP"; break
      fi
      [ -f "$TMP" ] && { cat "$TMP" >> "$PART_FILE"; rm -f "$TMP"; }
      sleep 1
    done
  ) &
  NEWPID=$!
  PIDS+=("$NEWPID")
  echo "Parca $i: bayt $RANGE_START-$END baslatildi (PID $NEWPID)"
done

echo "Tum parcalar icin bekleniyor (zaman siniri yok, kesintide otomatik devam eder)..."
for pid in "${PIDS[@]}"; do
  wait "$pid"
done

echo "Birlestiriliyor..."
rm -f "$OUT"
for i in $(seq 0 $((PARTS - 1))); do
  cat "${OUT}.part${i}" >> "$OUT"
done

FINAL_SIZE=$(stat -f%z "$OUT")
echo "Bitti. Son boyut: $FINAL_SIZE (beklenen: $SIZE)"
if [ "$FINAL_SIZE" -eq "$SIZE" ]; then
  echo "BASARILI"
  rm -f "${OUT}".part*
else
  echo "BOYUT UYUSMUYOR - tekrar calistirmayi dene, kalinan yerden devam eder"
fi
