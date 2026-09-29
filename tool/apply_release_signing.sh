#!/usr/bin/env bash
# Configura la firma release con una keystore propia (secretos de GitHub).
# Sin estos secretos, el APK release se firma con la clave de depuración:
# sirve para probar e instalar, no para publicar en Google Play.
set -euo pipefail
cd "$(dirname "$0")/.."
: "${KEYSTORE_BASE64:?}" "${KEYSTORE_PASSWORD:?}" "${KEY_ALIAS:?}" "${KEY_PASSWORD:?}"

echo "$KEYSTORE_BASE64" | base64 --decode > android/app/upload-keystore.jks
cat > android/key.properties <<PROPS
storePassword=$KEYSTORE_PASSWORD
keyPassword=$KEY_PASSWORD
keyAlias=$KEY_ALIAS
storeFile=upload-keystore.jks
PROPS

python3 - <<'PY'
from pathlib import Path
p = Path("android/app/build.gradle.kts")
if not p.exists():
    raise SystemExit("Se esperaba android/app/build.gradle.kts")
s = p.read_text()
if "keystoreProperties" not in s:
    s = ("import java.io.FileInputStream\nimport java.util.Properties\n\n" + s)
    s = s.replace("android {", '''val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }''', 1)
    s = s.replace('signingConfig = signingConfigs.getByName("debug")', 'signingConfig = signingConfigs.getByName("release")')
    p.write_text(s)
print("Firma release configurada")
PY
