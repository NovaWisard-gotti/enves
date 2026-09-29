import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ink_marks.dart';

/// Página de papel: espacio, márgenes y tipografía; sin tarjetas.
class PaperPage extends StatelessWidget {
  const PaperPage({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.onBack,
    this.reverse = false,
    this.bottom,
    this.banner,
    this.showAppBar = true,
  });

  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final bool reverse;
  final Widget? bottom;
  final Widget? banner;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final bg = reverse ? context.enves.reverse : context.enves.paper;
    return Scaffold(
      backgroundColor: bg,
      appBar: showAppBar
          ? AppBar(
              backgroundColor: bg,
              automaticallyImplyLeading: false,
              leading: onBack == null
                  ? null
                  : IconButton(
                      tooltip: 'Volver',
                      icon: const Icon(Icons.arrow_back),
                      onPressed: onBack,
                    ),
              title: title == null ? null : Text(title!),
              actions: actions,
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            if (banner != null) banner!,
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: child),
                ),
              ),
            ),
            if (bottom != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: bottom!),
              ),
          ],
        ),
      ),
    );
  }
}

/// Opción sobre una línea horizontal. Seleccionable, con semántica de botón.
class RuledOption extends StatelessWidget {
  const RuledOption({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.leading,
    this.detail,
    this.serif = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final Widget? leading;
  final String? detail;
  final bool serif;

  @override
  Widget build(BuildContext context) {
    final e = context.enves;
    final style = serif ? context.text.bodyLarge : context.text.bodyMedium;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: e.divider))),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: leading ?? InkDot(style: selected ? DotStyle.filled : DotStyle.hollow, size: 16),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: style?.copyWith(fontWeight: selected ? FontWeight.w700 : null)),
                    if (detail != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(detail!, style: context.text.bodySmall),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nota al margen en azafrán, con una regla vertical.
class MarginNote extends StatelessWidget {
  const MarginNote(this.text, {super.key, this.child});
  final String text;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 14),
      decoration: BoxDecoration(border: Border(left: BorderSide(color: context.enves.saffron, width: 2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: context.marginNote),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class Gap extends StatelessWidget {
  const Gap(this.size, {super.key});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(height: size, width: size);
}

/// Etiqueta pequeña de sección, en tipografía normal (sin mayúsculas).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(text, style: context.text.labelMedium),
        ),
      );
}

/// Selector de cinco pasos accesible (sin puntos ni calificaciones).
class FiveStepSelector extends StatelessWidget {
  const FiveStepSelector({
    super.key,
    required this.value,
    required this.onChanged,
    required this.lowLabel,
    required this.highLabel,
    required this.semanticsLabel,
    this.stepLabels,
  });

  final int? value;
  final ValueChanged<int> onChanged;
  final String lowLabel;
  final String highLabel;
  final String semanticsLabel;
  final List<String>? stepLabels;

  @override
  Widget build(BuildContext context) {
    String labelFor(int i) => stepLabels != null && stepLabels!.length == 5 ? stepLabels![i - 1] : '$i de 5';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 1; i <= 5; i++)
              Semantics(
                button: true,
                selected: value == i,
                label: '$semanticsLabel: ${labelFor(i)}',
                child: InkResponse(
                  onTap: () => onChanged(i),
                  radius: 28,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: InkDot(
                        style: value != null && i <= value! ? DotStyle.filled : DotStyle.hollow,
                        size: 14 + i * 2.0,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        Row(
          children: [
            Expanded(child: Text(lowLabel, style: context.text.bodySmall)),
            Expanded(child: Text(highLabel, style: context.text.bodySmall, textAlign: TextAlign.right)),
          ],
        ),
        if (value != null && stepLabels != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(labelFor(value!), style: context.text.labelMedium),
          ),
      ],
    );
  }
}

/// Aviso discreto en la parte superior (recuperación, guardado, demostración).
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({super.key, required this.text, this.actionLabel, this.onAction, this.emphasis = false});
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final e = context.enves;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 10, 12, 10),
        decoration: BoxDecoration(
          color: emphasis ? e.ink : e.reverse,
          border: Border(bottom: BorderSide(color: e.divider)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: context.text.bodySmall?.copyWith(color: emphasis ? e.paper : e.ink, fontWeight: emphasis ? FontWeight.w700 : null),
              ),
            ),
            if (actionLabel != null)
              TextButton(
                onPressed: onAction,
                style: emphasis ? TextButton.styleFrom(foregroundColor: e.paper) : null,
                child: Text(actionLabel!),
              ),
          ],
        ),
      ),
    );
  }
}
