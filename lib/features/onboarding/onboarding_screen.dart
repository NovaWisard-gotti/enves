import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../widgets/balanza.dart';
import '../../widgets/hilo_vivo.dart';
import '../../widgets/paper.dart';

const kOnboardingQuestion = '¿Se puede entender a alguien sin darle la razón?';
const kFirstExperience = 'e1_mismo_descuido';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  int? _value;
  bool _confirmed = false;
  bool _saving = false;

  Future<void> _finish() async {
    final engine = ref.read(engineProvider);
    final user = ref.read(userStateProvider).valueOrNull;
    if (engine == null || user == null || _value == null) return;
    setState(() => _saving = true);
    final started = engine.start(engine.completeOnboarding(user, _value!), kFirstExperience);
    final saving = ref.read(userStateProvider.notifier).commit(started);
    if (mounted) context.go('/experiencia/$kFirstExperience');
    await saving;
  }

  @override
  Widget build(BuildContext context) {
    final reduced = reducedMotion(context, ref);
    final Widget body;
    final Widget bottom;
    switch (_step) {
      case 0:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Gap(56),
            const HiloFirma(width: 240, height: 52, tocable: true),
            const Gap(40),
            Semantics(header: true, child: Text(kOnboardingQuestion, style: context.text.displaySmall)),
            const Gap(20),
            Text(
              'Envés es un cuaderno para pensar. Aquí tus ideas se marcan, se cruzan y se recuerdan.',
              style: context.text.bodyLarge,
            ),
          ],
        );
        bottom = FilledButton(onPressed: () => setState(() => _step = 1), child: const Text('Seguir'));
      case 1:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Gap(32),
            Text(kOnboardingQuestion, style: context.text.headlineSmall),
            const Gap(32),
            Balanza(
              leftLabel: 'No',
              rightLabel: 'Sí',
              value: _value,
              prompt: kOnboardingQuestion,
              onZoneChanged: ref.read(feedbackProvider).selection,
              onChanged: (v) => setState(() {
                _value = v;
                _confirmed = false;
              }),
            ),
            const Gap(24),
            if (_confirmed) ...[
              MarginNote('Así funciona: hacia dónde vas es tu postura; qué tan lejos, tu seguridad.'),
              const Gap(12),
              Text(
                'Más adelante vas a cruzar al otro lado del eje. Tu punto se queda anclado aquí: no lo pierdes.',
                style: context.text.bodySmall,
              ),
            ],
          ],
        );
        bottom = _confirmed
            ? FilledButton(onPressed: () => setState(() => _step = 2), child: const Text('Seguir'))
            : FilledButton(
                onPressed: _value == null ? null : () => setState(() => _confirmed = true),
                child: const Text('Listo'),
              );
      default:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Gap(48),
            const HiloFirma(width: 180, height: 40, hueco: false),
            const Gap(24),
            Text(
              'Aquí nadie va a intentar convencerte.',
              style: context.text.displaySmall,
            ),
            const Gap(16),
            Text(
              'Vamos a mirar juntos por qué piensas lo que piensas, y cómo lo ve quien piensa distinto.',
              style: context.text.bodyLarge,
            ),
            const Gap(32),
            Text('Tus respuestas se quedan en tu teléfono.', style: context.text.bodySmall),
          ],
        );
        bottom = FilledButton(onPressed: _saving ? null : _finish, child: const Text('Empezar'));
    }
    return PaperPage(
      showAppBar: false,
      bottom: bottom,
      child: AnimatedSwitcher(
        duration: reduced ? Duration.zero : Motion.medium,
        child: KeyedSubtree(key: ValueKey(_step), child: body),
      ),
    );
  }
}
