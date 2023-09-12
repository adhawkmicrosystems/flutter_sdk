import 'package:flutter/material.dart';

CardTheme deviceInformationTheme(context) {
  final base = Theme.of(context);
  return CardTheme(
    elevation: 0,
    margin: const EdgeInsets.all(16),
    shape: RoundedRectangleBorder(
      side: BorderSide(
        color: base.colorScheme.outlineVariant,
      ),
      borderRadius: const BorderRadius.all(Radius.circular(12)),
    ),
  );
}
