#!/usr/bin/env bash
# Completa la carpeta android/ con los archivos que genera Flutter (Gradle,
# wrapper, etc.) SIN sobrescribir los que ya trae Envés (manifiesto, iconos,
# temas, MainActivity). Después fija el identificador com.enves.app.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter create --platforms=android --org com.enves --project-name enves --no-pub . >/dev/null

# flutter create genera una actividad en com/enves/enves: Envés usa com/enves/app.
rm -rf android/app/src/main/kotlin/com/enves/enves

# flutter create añade un fondo de arranque para API 21+ que ignoraría el color papel.
mkdir -p android/app/src/main/res/drawable-v21
cp android/app/src/main/res/drawable/launch_background.xml android/app/src/main/res/drawable-v21/launch_background.xml

# Prueba de ejemplo que genera flutter create (usa MyApp, que no existe aquí).
if [ -f test/widget_test.dart ] && grep -q "MyApp" test/widget_test.dart; then
  rm test/widget_test.dart
fi

for f in android/app/build.gradle.kts android/app/build.gradle; do
  [ -f "$f" ] || continue
  sed -i.bak -e 's/com\.enves\.enves/com.enves.app/g' "$f" && rm -f "$f.bak"
done

grep -q 'com.enves.app' android/app/build.gradle* || { echo "No se pudo fijar applicationId" >&2; exit 1; }
if grep -q 'android.permission.INTERNET' android/app/src/main/AndroidManifest.xml; then
  echo "El manifiesto principal no debe pedir INTERNET" >&2; exit 1
fi
echo "Android listo: com.enves.app"
