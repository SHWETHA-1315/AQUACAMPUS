/// Demand allocation estimated from manual tank readings and user requests.
///
/// Essential access is prioritised over flexible activities. This planner is
/// informational: no meter, pump or valve is read or controlled.
class WaterBudget {
  const WaterBudget({
    required this.stored,
    required this.reserve,
    required this.essential,
    required this.optional,
    required this.availableForPlan,
    required this.essentialShortfall,
    required this.optionalShortfall,
  });

  final double stored;
  final double reserve;
  final double essential;
  final double optional;
  final double availableForPlan;
  final double essentialShortfall;
  final double optionalShortfall;

  double get totalDemand => essential + optional;
  double get totalShortfall => essentialShortfall + optionalShortfall;
  double get coveredFraction => totalDemand <= 0
      ? 1.0
      : (availableForPlan / totalDemand).clamp(0.0, 1.0).toDouble();
  bool get essentialAtRisk => essentialShortfall > 0.001;

  static WaterBudget estimate({
    required double storedLitres,
    required int residents,
    required double essentialLitresPerResident,
    required double requestedExtraLitres,
    double reserveFraction = 0.15,
  }) {
    double safe(double n) => n.isFinite && n > 0 ? n : 0.0;
    final stored = safe(storedLitres);
    final essential =
        residents > 0 ? residents * safe(essentialLitresPerResident) : 0.0;
    final optional = safe(requestedExtraLitres);
    final reserve = stored * reserveFraction.clamp(0.0, 1.0).toDouble();
    final usable = stored - reserve;
    final essentialDeficit =
        (essential - usable).clamp(0.0, double.infinity).toDouble();
    final afterEssential =
        (usable - essential).clamp(0.0, double.infinity).toDouble();
    final optionalDeficit =
        (optional - afterEssential).clamp(0.0, double.infinity).toDouble();
    return WaterBudget(
      stored: stored,
      reserve: reserve,
      essential: essential,
      optional: optional,
      availableForPlan: usable,
      essentialShortfall: essentialDeficit,
      optionalShortfall: optionalDeficit,
    );
  }
}
