#!/usr/bin/env bash
# Costruisce l'APK di Spesa Dieta con Capacitor. Pensato per GitHub Actions (Ubuntu, Node 20, Java 17).
set -euo pipefail

ROOT="$(pwd)"
rm -rf app && mkdir app && cd app
mkdir www && cp "$ROOT/index.html" www/index.html

cat > package.json <<'EOF2'
{"name":"spesa-dieta","version":"1.0.0","private":true}
EOF2

npm install --no-audit --no-fund @capacitor/core@6 @capacitor/cli@6 @capacitor/android@6 sharp \
  pdfjs-dist@3.11.174 tesseract.js@5 tesseract.js-core@5 @tesseract.js-data/ita

# ---------- lettori di PDF e foto (OCR) inclusi nell'app: funzionano senza internet ----------
mkdir -p www/lib/tess
cp node_modules/pdfjs-dist/build/pdf.min.js node_modules/pdfjs-dist/build/pdf.worker.min.js www/lib/
cp node_modules/tesseract.js/dist/tesseract.min.js node_modules/tesseract.js/dist/worker.min.js www/lib/tess/
cp node_modules/tesseract.js-core/tesseract-core* www/lib/tess/
ITA="$(find node_modules/@tesseract.js-data/ita -name 'ita.traineddata.gz' | head -n 1)"
if [ -n "$ITA" ]; then cp "$ITA" www/lib/tess/ita.traineddata.gz
else
  ITA="$(find node_modules/@tesseract.js-data/ita -name 'ita.traineddata' | head -n 1)"
  gzip -c "$ITA" > www/lib/tess/ita.traineddata.gz
fi
ls -la www/lib www/lib/tess

cat > capacitor.config.json <<'EOF2'
{
  "appId": "it.spesadieta.app",
  "appName": "Spesa Dieta",
  "webDir": "www",
  "server": { "androidScheme": "https" },
  "android": { "backgroundColor": "#2f6be0" }
}
EOF2

npx cap add android

# ---------- icona: carrello bianco su blu ----------
cat > icons.js <<'EOF2'
const sharp = require('sharp');
const fs = require('fs');
const path = require('path');
const res = 'android/app/src/main/res';

const cart = `
<g transform="translate(-1.5,-3)">
  <path d="M31 38h6l7 24h27" fill="none" stroke="#fff" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M39 45h41l-5 17H44z" fill="#fff" stroke="#fff" stroke-width="3" stroke-linejoin="round"/>
  <circle cx="47" cy="72" r="4.5" fill="#fff"/>
  <circle cx="68" cy="72" r="4.5" fill="#fff"/>
</g>`;
const defs = `<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#5aa6ff"/><stop offset="1" stop-color="#2f6be0"/></linearGradient></defs>`;
const svg = (size, body) => Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 108 108">${defs}${body}</svg>`);
const big = `<g transform="translate(54 54) scale(0.86) translate(-54 -54)">${cart}</g>`;

const legacy = (s) => svg(s, `<rect width="108" height="108" rx="26" fill="url(#g)"/>${big}`);
const round = (s) => svg(s, `<circle cx="54" cy="54" r="54" fill="url(#g)"/>${big}`);
const foreground = (s) => svg(s, `<g transform="translate(54 54) scale(0.8) translate(-54 -54)">${cart}</g>`);

const dens = { mdpi: [48, 108], hdpi: [72, 162], xhdpi: [96, 216], xxhdpi: [144, 324], xxxhdpi: [192, 432] };

(async () => {
  for (const [d, [ic, fg]] of Object.entries(dens)) {
    const dir = path.join(res, 'mipmap-' + d);
    fs.mkdirSync(dir, { recursive: true });
    await sharp(legacy(ic)).png().toFile(path.join(dir, 'ic_launcher.png'));
    await sharp(round(ic)).png().toFile(path.join(dir, 'ic_launcher_round.png'));
    await sharp(foreground(fg)).png().toFile(path.join(dir, 'ic_fg.png'));
  }
  fs.mkdirSync(path.join(res, 'drawable'), { recursive: true });
  fs.writeFileSync(path.join(res, 'drawable', 'ic_bg.xml'),
    '<?xml version="1.0" encoding="utf-8"?>\n' +
    '<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">\n' +
    '  <gradient android:angle="315" android:startColor="#5AA6FF" android:endColor="#2F6BE0"/>\n' +
    '</shape>\n');
  const adaptive =
    '<?xml version="1.0" encoding="utf-8"?>\n' +
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n' +
    '  <background android:drawable="@drawable/ic_bg"/>\n' +
    '  <foreground android:drawable="@mipmap/ic_fg"/>\n' +
    '</adaptive-icon>\n';
  fs.mkdirSync(path.join(res, 'mipmap-anydpi-v26'), { recursive: true });
  fs.writeFileSync(path.join(res, 'mipmap-anydpi-v26', 'ic_launcher.xml'), adaptive);
  fs.writeFileSync(path.join(res, 'mipmap-anydpi-v26', 'ic_launcher_round.xml'), adaptive);
  console.log('Icone create');
})();
EOF2
node icons.js

# schermata di avvio con lo stesso sfondo verde dell'icona
sed -i 's#@drawable/splash#@drawable/ic_bg#g' android/app/src/main/res/values/styles.xml || true

cd android
chmod +x gradlew
./gradlew assembleDebug --no-daemon --console=plain

cp app/build/outputs/apk/debug/app-debug.apk "$ROOT/SpesaDieta.apk"
ls -la "$ROOT/SpesaDieta.apk"
