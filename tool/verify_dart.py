"""Verificación estática aproximada del código Dart (sin compilador).

No sustituye a `flutter analyze`: detecta llaves desbalanceadas, imports
relativos rotos, imports de archivos del proyecto sin uso y tipos en
mayúscula que no están declarados en el proyecto ni en la lista conocida.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FILES = sorted([*ROOT.glob("lib/**/*.dart"), *ROOT.glob("test/**/*.dart"), *ROOT.glob("integration_test/**/*.dart")])


def strip(src):
    """Quita comentarios y contenido de cadenas (conserva interpolaciones simples)."""
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if src.startswith("//", i):
            j = src.find("\n", i)
            i = n if j < 0 else j
            continue
        if src.startswith("/*", i):
            j = src.find("*/", i)
            i = n if j < 0 else j + 2
            continue
        if c in "'\"":
            triple = src[i:i + 3] in ("'''", '"""')
            q = src[i:i + 3] if triple else c
            raw = i > 0 and src[i - 1] == "r"
            j = i + len(q)
            buf = []
            while j < n and not src.startswith(q, j):
                if src[j] == "\\" and not raw:
                    j += 2
                    continue
                if src.startswith("${", j) and not raw:
                    depth, k = 1, j + 2
                    while k < n and depth:
                        if src[k] == "{": depth += 1
                        elif src[k] == "}": depth -= 1
                        k += 1
                    buf.append(" " + strip(src[j + 2:k - 1]) + " ")
                    j = k
                    continue
                if src[j] == "$" and not raw:
                    m = re.match(r"\$([A-Za-z_]\w*)", src[j:])
                    if m:
                        buf.append(" " + m.group(1) + " ")
                        j += len(m.group(0))
                        continue
                j += 1
            out.append('""' + "".join(buf))
            i = j + len(q)
            continue
        out.append(c)
        i += 1
    return "".join(out)


DECL = re.compile(r"^(?:abstract\s+|final\s+|sealed\s+|base\s+|mixin\s+)*(?:class|enum|mixin|extension|typedef)\s+([A-Za-z_]\w*)", re.M)
TOPFN = re.compile(r"^(?:[\w<>?,\s\[\]]+?\s+)?([A-Za-z_]\w*)\s*(?:<[^>]*>)?\s*\(", re.M)
TOPVAR = re.compile(r"^(?:const|final|var|late\s+final)\s+(?:[\w<>?,\s]+\s+)?([A-Za-z_]\w*)\s*=", re.M)

decls = {}
for f in FILES:
    s = strip(f.read_text(encoding="utf-8"))
    names = set(DECL.findall(s)) | set(TOPVAR.findall(s))
    # Miembros de extensiones: se usan como `.nombre`.
    for ext in re.finditer(r"^extension\s+\w*\s*on\s+\w+\s*\{(.*?)^\}", s, re.M | re.S):
        names |= set(re.findall(r"\bget\s+(\w+)", ext.group(1)))
    for line in s.splitlines():
        if line and not line.startswith((" ", "\t", "}", ")", "import", "export", "part", "library", "@")):
            m = TOPFN.match(line)
            if m and m.group(1) not in ("if", "for", "while", "switch", "return"):
                names.add(m.group(1))
    decls[f] = names
ALL = set().union(*decls.values())

KNOWN = set("""
Object String int double num bool List Map Set Iterable Future FutureOr Stream Duration DateTime Exception StateError
FormatException RegExp RegExpMatch Match Function Null Never Type Symbol Comparable Record Error ArgumentError
File Directory Platform MapEntry StringBuffer Uri Random JsonEncoder
Widget StatelessWidget StatefulWidget State BuildContext Key ValueKey Text TextStyle TextTheme Theme ThemeData ThemeMode
ThemeExtension Color Colors Brightness ColorScheme FontWeight FontStyle TextDecoration TextAlign EdgeInsets Padding
Column Row Expanded Flexible SizedBox Container BoxDecoration Border BorderSide BorderRadius Radius BoxConstraints
ConstrainedBox Align Alignment Center Stack Positioned Wrap Divider VerticalDivider Spacer Scaffold AppBar SafeArea
SingleChildScrollView ListView IconButton Icon Icons InkWell InkResponse InkRipple GestureDetector HitTestBehavior
Semantics ExcludeSemantics MergeSemantics CustomPaint CustomPainter Canvas Paint PaintingStyle Offset Size Rect Path
StrokeCap LayoutBuilder BoxConstraints MediaQuery Opacity AnimatedSwitcher KeyedSubtree TweenAnimationBuilder Tween
AnimationController AnimatedBuilder SingleTickerProviderStateMixin Transform Matrix4 Curves Curve Navigator
FilledButton OutlinedButton TextButton ElevatedButton ButtonStyle ButtonSegment SegmentedButton SwitchListTile Switch
Slider SliderThemeData TextField TextEditingController InputDecoration UnderlineInputBorder AlertDialog SnackBar
ScaffoldMessenger showDialog showModalBottomSheet showAboutDialog DraggableScrollableSheet Material MaterialApp
RoundedRectangleBorder Size Locale GlobalMaterialLocalizations GlobalWidgetsLocalizations GlobalCupertinoLocalizations
ValueChanged VoidCallback WidgetStateProperty WidgetState DividerThemeData AppBarTheme FilledButtonThemeData
OutlinedButtonThemeData TextButtonThemeData BottomSheetThemeData SnackBarThemeData SnackBarBehavior InputDecorationTheme
SwitchThemeData SegmentedButtonThemeData PopScope IntrinsicHeight CrossAxisAlignment MainAxisAlignment MainAxisSize
LongPressDraggable Draggable DragTarget DragTargetDetails WidgetsBinding WidgetsFlutterBinding SystemChrome
DeviceOrientation LicenseRegistry LicenseEntryWithLineBreaks HapticFeedback SystemSound SystemSoundType
TextScaler Placeholder StatefulBuilder SemanticsAction
ConsumerWidget ConsumerStatefulWidget ConsumerState WidgetRef Ref Provider StateProvider FutureProvider AsyncNotifier
AsyncNotifierProvider AsyncValue AsyncData AsyncError ProviderScope ProviderContainer ProviderSubscription Override
GoRouter GoRoute GoRouterState ChangeNotifier Listenable
Widget test group expect setUp tearDown testWidgets WidgetTester find findsOneWidget findsNothing findsWidgets
isTrue isFalse isNull isNotNull equals contains isEmpty isNotEmpty greaterThan lessThan greaterThanOrEqualTo
lessThanOrEqualTo closeTo throwsA isA returnsNormally everyElement anyElement matches startsWith
IntegrationTestWidgetsFlutterBinding TestWidgetsFlutterBinding ByType Finder
""".split())

errors = []
for f in FILES:
    raw = f.read_text(encoding="utf-8")
    s = strip(raw)
    rel = f.relative_to(ROOT)
    for a, b in ("()", "[]", "{}"):
        if s.count(a) != s.count(b):
            errors.append(f"{rel}: '{a}' {s.count(a)} vs '{b}' {s.count(b)}")
    imports = re.findall(r"^import\s+'([^']+)'(?:\s+as\s+(\w+))?", raw, re.M)
    body = re.sub(r"^import .*$", "", s, flags=re.M)
    visible = set(decls[f])
    for path, alias in imports:
        if path.startswith("package:enves/"):
            target = ROOT / "lib" / path[len("package:enves/"):]
        elif path.startswith(("package:", "dart:")):
            if alias and not re.search(r"\b" + alias + r"\.", body):
                errors.append(f"{rel}: alias sin uso {alias}")
            continue
        else:
            target = (f.parent / path).resolve()
        if not target.exists():
            errors.append(f"{rel}: import inexistente {path}")
            continue
        names = decls.get(target, set())
        visible |= names
        if not any(re.search(r"\b" + re.escape(n) + r"\b", body) for n in names):
            errors.append(f"{rel}: import sin uso {path}")
    # Tipos en mayúscula usados y no declarados en lo visible ni conocidos.
    for name in sorted(set(re.findall(r"\b([A-Z][A-Za-z0-9_]*)\b", body))):
        if name in KNOWN or name in visible:
            continue
        if name in ALL:
            errors.append(f"{rel}: usa {name} sin importarlo")
        else:
            errors.append(f"{rel}: símbolo desconocido {name}")
    for bad in ("TODO", "FIXME", "UnimplementedError"):
        if re.search(r"\b" + bad + r"\b", s):
            errors.append(f"{rel}: contiene {bad}")
    if not str(rel).endswith("palette.dart") and re.search(r"Color\(0x", s) and str(rel).startswith("lib"):
        errors.append(f"{rel}: color literal fuera de palette.dart")

for e in errors:
    print(e)
print(f"{len(FILES)} archivos, {len(errors)} avisos")
sys.exit(1 if errors else 0)
