import 'dart:ui';

import '../../domain/entities/armor_material.dart';

/// Birth color of an armor or hull part. Level 1 keeps the part's own color.
/// Damage then shifts that color toward dark red, so "forged harder" and
/// "breaking" stay distinct.
abstract final class ArmorMaterialColors {
  static const steel = Color(0xFFC5CCD6);
  static const alloy = Color(0xFF5B8DEF);
  static const composite = Color(0xFF3DDCFF);
  static const tempered = Color(0xFFE8EEF7);

  static Color of(int level, Color iron) => switch (ArmorMaterial.at(level)) {
    ArmorMaterial.iron => iron,
    ArmorMaterial.steel => steel,
    ArmorMaterial.alloy => alloy,
    ArmorMaterial.composite => composite,
    ArmorMaterial.tempered => tempered,
  };
}
