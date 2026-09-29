import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ink_marks.dart';
import '../../widgets/paper.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _wipe(BuildContext context, WidgetRef ref) async {
    final first = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Borrar mi historial'),
        content: const Text(
          'Se borrarán tus posturas, razones, reconstrucciones, cuaderno y notas. Se conservan tus preferencias de apariencia.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Continuar')),
        ],
      ),
    );
    if (first != true || !context.mounted) return;
    final second = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('¿Seguro?'),
        content: const Text('Esto no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          TextButton(
            key: const ValueKey('wipe_confirm'),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Borrar todo'),
          ),
        ],
      ),
    );
    if (second != true) return;
    await ref.read(userStateProvider.notifier).wipe();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tu historial se borró.')));
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(currentPrefsProvider);
    final ctrl = ref.read(prefsProvider.notifier);

    Widget toggle(String title, String detail, bool value, ValueChanged<bool> onChanged) => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title, style: context.text.bodyMedium),
          subtitle: Text(detail, style: context.text.bodySmall),
          value: value,
          onChanged: onChanged,
        );

    return PaperPage(
      title: 'Ajustes',
      onBack: () => context.canPop() ? context.pop() : context.go('/'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel('Apariencia'),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'system', label: Text('Sistema')),
              ButtonSegment(value: 'light', label: Text('Claro')),
              ButtonSegment(value: 'dark', label: Text('Oscuro')),
            ],
            selected: {prefs.themeMode},
            showSelectedIcon: false,
            onSelectionChanged: (s) => ctrl.updatePrefs((p) => p.copyWith(themeMode: s.first)),
          ),
          const Gap(12),
          toggle(
            'Reducir movimiento',
            'El cruce y otras transiciones se vuelven fundidos breves',
            prefs.motion == 'reduced',
            (v) => ctrl.updatePrefs((p) => p.copyWith(motion: v ? 'reduced' : 'system')),
          ),
          toggle('Vibración sutil', 'Al elegir y al cruzar', prefs.haptics, (v) => ctrl.updatePrefs((p) => p.copyWith(haptics: v))),
          toggle('Sonido', 'Un clic discreto en los momentos clave', prefs.sound, (v) => ctrl.updatePrefs((p) => p.copyWith(sound: v))),
          toggle(
            'Modo discreto',
            'No mostrar citas de tus respuestas en el inicio',
            prefs.discreet,
            (v) => ctrl.updatePrefs((p) => p.copyWith(discreet: v)),
          ),
          const Gap(24),
          SectionLabel('Recorrido'),
          RuledOption(
            label: 'Ver un recorrido de demostración',
            detail: 'Un mapa de ejemplo, separado de tus respuestas',
            leading: const InkDot(style: DotStyle.hollow, size: 12),
            onTap: () => context.push('/mapa?demo=1'),
          ),
          const Gap(24),
          SectionLabel('Tus datos'),
          RuledOption(
            label: 'Privacidad',
            leading: const InkDot(style: DotStyle.hollow, size: 12),
            onTap: () => context.push('/ajustes/privacidad'),
          ),
          RuledOption(
            label: 'Fuentes',
            leading: const InkDot(style: DotStyle.hollow, size: 12),
            onTap: () => context.push('/fuentes'),
          ),
          RuledOption(
            key: const ValueKey('wipe'),
            label: 'Borrar mi historial',
            detail: 'Elimina todas tus respuestas de este teléfono',
            leading: const InkDot(style: DotStyle.dashed, size: 12),
            onTap: () => _wipe(context, ref),
          ),
          const Gap(24),
          RuledOption(
            label: 'Acerca de Envés',
            leading: const InkDot(style: DotStyle.hollow, size: 12),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Envés',
              applicationVersion: '1.0.0',
              applicationIcon: const CrossGlyph(),
              applicationLegalese: 'Comprender no es ceder.',
            ),
          ),
        ],
      ),
    );
  }
}
