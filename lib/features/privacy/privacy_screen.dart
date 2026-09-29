import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../widgets/paper.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const sections = [
    (
      'Qué guarda Envés',
      'Tus posturas, las razones que elegiste, tus respuestas a las preguntas, tus reconstrucciones del otro lado, '
          'las distinciones de tu cuaderno y tus notas privadas. Nada más.'
    ),
    (
      'Dónde lo guarda',
      'Solo en este teléfono, dentro del espacio privado de la app. Envés no tiene servidores, cuentas ni '
          'conexión a internet, y no envía nada a nadie.'
    ),
    (
      'Copias de seguridad',
      'Envés desactiva las copias automáticas de Android, así que tus respuestas no se suben a la nube. '
          'Si cambias de teléfono, no se trasladan.'
    ),
    (
      'Qué no hace',
      'No usa publicidad, analítica ni inteligencia artificial. No crea un perfil de tu personalidad ni te '
          'compara con otras personas.'
    ),
    (
      'Cómo borrarlo',
      'En Ajustes, «Borrar mi historial» elimina todas tus respuestas de forma definitiva. Se conservan solo '
          'tus preferencias de apariencia. Desinstalar la app también lo borra todo.'
    ),
    (
      'Las perspectivas del otro lado',
      'Son simulaciones pedagógicas sintetizadas a partir de argumentos representativos de cada posición. '
          'No son testimonios de personas reales.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return PaperPage(
      title: 'Privacidad',
      onBack: () => context.canPop() ? context.pop() : context.go('/ajustes'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tus respuestas se quedan en tu teléfono.', style: context.text.headlineSmall),
          const Gap(20),
          for (final s in sections) ...[
            SectionLabel(s.$1),
            Text(s.$2, style: context.text.bodyLarge),
            const Gap(20),
          ],
        ],
      ),
    );
  }
}
