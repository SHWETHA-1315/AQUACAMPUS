import 'dart:math' as math;

/// Tank readings are manual (measured with a ruler/dipstick).
/// Supports rectangular tanks and UPRIGHT cylindrical tanks only.
/// Dimensions and water height are in centimetres; output is litres.
class WaterMath {
  static double capacityLitres({
    required String shape,
    required double heightCm,
    double lengthCm = 0,
    double widthCm = 0,
    double diameterCm = 0,
  }) {
    if (heightCm <= 0 || !heightCm.isFinite) return 0;
    final volume = shape == 'cylinder'
        ? math.pi * math.pow(diameterCm / 2, 2) * heightCm
        : lengthCm * widthCm * heightCm;
    if (!volume.isFinite || volume < 0) return 0;
    return volume / 1000;
  }

  static double availableLitres({
    required String shape,
    required double heightCm,
    required double waterHeightCm,
    double lengthCm = 0,
    double widthCm = 0,
    double diameterCm = 0,
  }) {
    final safeWaterHeight = waterHeightCm.clamp(0, heightCm);
    return capacityLitres(
      shape: shape,
      heightCm: safeWaterHeight.toDouble(),
      lengthCm: lengthCm,
      widthCm: widthCm,
      diameterCm: diameterCm,
    );
  }

  static double nonNegative(num? number) => math.max(0.0, (number ?? 0).toDouble());

  static double perPersonShare(double litres, int people, {double reserveFraction = 0.15}) {
    if (people <= 0) return 0;
    return math.max(0.0, litres * (1 - reserveFraction.clamp(0, 1)) / people);
  }
}

num nval(dynamic value) => value is num ? value : num.tryParse('$value') ?? 0;
String dateKey([DateTime? date]) {
  final d = date ?? DateTime.now();
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
