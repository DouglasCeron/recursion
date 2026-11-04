/// Resistance of an armor or hull part. [iron] is level 1, and each step is
/// what a zone becomes after another generation focused on it.
enum ArmorMaterial {
  iron,
  steel,
  alloy,
  composite,
  tempered;

  static const maxLevel = 5;

  static ArmorMaterial at(int level) =>
      values[(level - 1).clamp(0, values.length - 1)];

  String get label => switch (this) {
    ArmorMaterial.iron => 'Iron',
    ArmorMaterial.steel => 'Steel',
    ArmorMaterial.alloy => 'Alloy',
    ArmorMaterial.composite => 'Composite',
    ArmorMaterial.tempered => 'Tempered',
  };
}
