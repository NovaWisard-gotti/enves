# Envés

**Comprender no es ceder.**

Envés es una app Android (Flutter) de experiencias filosóficas para personas desde 15 años. En cada una eliges una postura, examinas tus razones con preguntas que recuerdan lo que respondiste antes, cruzas al otro lado para reconstruir la mejor versión de quien piensa distinto y vuelves a tu lado con algo más.

Ciclo: **Elige → Razona → Cruza → Vuelve**. Nueve preguntas en tres tramos, un Mapa de Pensamiento que se construye solo con tus decisiones y un Cuaderno de distinciones.

Funciona sin conexión, sin cuentas, sin anuncios, sin analítica y sin IA. La versión release no pide permiso de internet y desactiva las copias de seguridad de Android: las respuestas se quedan en el teléfono.

---

## Estado de esta entrega

El código se escribió en un entorno sin Flutter ni Dart instalables (sus servidores de descarga estaban bloqueados). Por eso **no se compiló localmente**. Se hizo, en cambio:

- Verificación estática con `tool/verify_dart.py`: llaves balanceadas, imports que resuelven, imports sin uso, tipos no declarados, colores fuera de la paleta y marcadores de trabajo pendiente. Resultado: 0 avisos.
- Réplica en Python de las reglas del validador de contenido y del motor socrático (selección de preguntas y memoria). El perfil de demostración se genera con esa réplica, así que muestra exactamente las preguntas que el motor elegiría.
- Comprobación del simulador de *Cien becas*: 8 combinaciones cumplen el criterio 1, 5 el criterio 2 y **ninguna** ambos.

La compilación, `flutter analyze` y las pruebas se ejecutan en **GitHub Actions** (ver abajo). Si la primera ejecución señala algún detalle del compilador, el registro de Actions indica el archivo y la línea exactos.

---

## Estructura

```
lib/
  core/            utilidades JSON tolerantes
  domain/          modelos de contenido y registros del usuario
  content/         carga y validación del contenido
  engine/          lógica pura, sin Flutter:
    rules/           condiciones, hechos y plantillas
    memory/          recuerdos citados literalmente y rastreables
    socratic/        selección determinista (máximo dos preguntas)
    cruza/           mesa de piezas y evaluación del reconocimiento
    fairness/        modelo real del simulador de becas
    map/             Mapa de Pensamiento calculado desde los registros
    progress/        siguiente pregunta, orden recomendado, eco
    experience/      máquina de etapas común a las nueve experiencias
  data/            persistencia local atómica con copia y migraciones
  app/             proveedores Riverpod, rutas y pantallas de error
  theme/           paleta Papel y tinta, tema, movimiento y háptica
  widgets/         balanza, marcas de tinta, botones de tensión
  features/        pantallas: inicio, preguntas, experiencia, mapa, cuaderno, ajustes…
assets/
  content/es/      contenido (generado por tool/content/build.py)
  demo/            perfil de demostración de solo lectura
  fonts/           Newsreader y Atkinson Hyperlegible Next (licencia OFL)
android/           manifiesto, iconos, temas y MainActivity propios
tool/              verificador, generadores y scripts de Android
test/              pruebas unitarias y de widgets
integration_test/  recorrido en dispositivo
```

Arquitectura: **MVVM con Riverpod**. Los widgets solo llaman a `ExperienceActions`; las reglas viven en `engine/` y son funciones puras (estado → nuevo estado), probadas sin interfaz.

---

## Ejecutar en tu computadora

Requisitos: Flutter estable (3.24 o superior), Android SDK y Java 17.

```bash
bash tool/prepare_android.sh   # completa android/ con Gradle sin tocar lo propio de Envés
flutter pub get
flutter run                    # con un teléfono o emulador conectado
```

`prepare_android.sh` ejecuta `flutter create` solo para los archivos que faltan (Gradle, wrapper), fija el identificador `com.enves.app` y comprueba que el manifiesto no pida internet.

Pruebas:

```bash
flutter analyze
flutter test
flutter test integration_test/app_test.dart   # requiere dispositivo o emulador
python3 tool/verify_dart.py
```

Si cambias textos del contenido, edita `tool/content/*.py` y regenera:

```bash
python3 tool/content/build.py     # escribe y valida assets/content/es
python3 tool/generate_demo.py     # regenera el perfil de demostración
```

---

## Obtener el APK con GitHub Actions

1. Crea un repositorio en GitHub y sube esta carpeta:
   ```bash
   git init
   git add .
   git commit -m "Envés 1.0.0"
   git branch -M main
   git remote add origin https://github.com/TU_USUARIO/enves.git
   git push -u origin main
   ```
2. En la pestaña **Actions** se ejecuta el flujo *Android* (`.github/workflows/build-android.yml`): prepara Android, verifica contenido y demostración, ejecuta `flutter analyze` y `flutter test`, compila el APK release y comprueba que no pida permiso de internet.
3. Al terminar, abre la ejecución y descarga el artefacto **enves-apk** (contiene `app-release.apk`).
4. Para instalarlo, cópialo al teléfono y ábrelo (Android pedirá permitir instalar desde esa fuente).

También puedes lanzarlo a mano con **Run workflow** (`workflow_dispatch`).

### Firma

Sin configuración adicional, el APK release se firma con la clave de depuración: sirve para probar e instalar, **no para publicar en Google Play**. Para firmar con tu propia clave:

1. Crea una keystore (una sola vez, y guárdala bien):
   ```bash
   keytool -genkey -v -keystore enves-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias enves
   base64 -w0 enves-upload.jks > keystore.b64
   ```
2. En GitHub: *Settings → Secrets and variables → Actions* y añade `KEYSTORE_BASE64` (contenido de `keystore.b64`), `KEYSTORE_PASSWORD`, `KEY_ALIAS` y `KEY_PASSWORD`.
3. La siguiente ejecución aplica `tool/apply_release_signing.sh` y firma con esa clave. La keystore y `key.properties` están en `.gitignore`: nunca se suben al repositorio.

---

## Privacidad

- Datos filosóficos en `state.json` (con copia `state.json.bak`), dentro del almacenamiento privado de la app; preferencias aparte en `prefs.json`.
- «Borrar mi historial» elimina `state.json`, la copia y los temporales; conserva solo las preferencias.
- `allowBackup=false` y reglas de extracción que excluyen todo de la nube y de la transferencia entre dispositivos.
- El perfil de demostración es de solo lectura y nunca se mezcla con los datos reales.

## Contenido y fuentes

Las perspectivas del otro lado son **simulaciones pedagógicas** sintetizadas a partir de argumentos representativos de cada posición; no son testimonios reales. Solo se muestran referencias marcadas como verificadas (ver *Ajustes → Fuentes*).

## Licencias

Tipografías Newsreader y Atkinson Hyperlegible Next bajo SIL Open Font License 1.1 (textos en `assets/fonts/`, visibles también en *Ajustes → Acerca de Envés → Licencias*).
