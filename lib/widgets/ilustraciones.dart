import 'package:flutter/material.dart';

/// La ilustración cede espacio al texto: a escala grande se reduce o se oculta.
bool ilustracionCabe(BuildContext context, {double hasta = 1.6}) =>
    MediaQuery.textScalerOf(context).scale(16) / 16 <= hasta;
