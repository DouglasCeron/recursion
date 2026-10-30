import 'weapon_exposure_profile.dart';

/// One transmission received by the enemy faction.
class IntelReport {
  const IntelReport({required this.sequence, required this.profile});

  /// Order in which the report was received, starting at 1.
  final int sequence;
  final WeaponExposureProfile profile;
}

/// Everything the enemy faction has actually received from its observers.
///
/// Knowledge only grows: a battle whose observer was destroyed adds nothing,
/// but never erases earlier reports.
class BossIntel {
  const BossIntel([this.reports = const []]);

  final List<IntelReport> reports;

  bool get isEmpty => reports.isEmpty;
  IntelReport? get latest => reports.isEmpty ? null : reports.last;

  BossIntel withReport(WeaponExposureProfile profile) => BossIntel(
    List.unmodifiable([
      ...reports,
      IntelReport(sequence: reports.length + 1, profile: profile),
    ]),
  );
}
