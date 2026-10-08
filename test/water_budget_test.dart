import 'package:flutter_test/flutter_test.dart';
import 'package:aquacampus/water_budget.dart';

void main() {
  test('500 L, ten residents, 15 percent reserve, sufficient supply', () {
    final b = WaterBudget.estimate(storedLitres: 500, residents: 10,
        essentialLitresPerResident: 30, requestedExtraLitres: 50);
    expect(b.reserve, 75);
    expect(b.availableForPlan, 425);
    expect(b.essentialShortfall, 0);
    expect(b.optionalShortfall, 0);
  });
  test('essential supply takes priority over flexible activities', () {
    final b = WaterBudget.estimate(storedLitres: 400, residents: 10,
        essentialLitresPerResident: 30, requestedExtraLitres: 100);
    expect(b.availableForPlan, 340);
    expect(b.essentialShortfall, 0);
    expect(b.optionalShortfall, 60);
  });
  test('shortage of essential water is highlighted', () {
    final b = WaterBudget.estimate(storedLitres: 200, residents: 10,
        essentialLitresPerResident: 30, requestedExtraLitres: 20);
    expect(b.essentialShortfall, 130);
    expect(b.optionalShortfall, 20);
    expect(b.essentialAtRisk, true);
  });
  test('invalid, zero and negative values remain safe', () {
    final b = WaterBudget.estimate(storedLitres: double.nan, residents: 0,
        essentialLitresPerResident: 30, requestedExtraLitres: -4);
    expect(b.totalDemand, 0);
    expect(b.availableForPlan, 0);
    expect(b.coveredFraction, 1);
  });
  test('full reserve leaves no water for planned allocation', () {
    final b = WaterBudget.estimate(storedLitres: 100, residents: 1,
        essentialLitresPerResident: 30, requestedExtraLitres: 10,
        reserveFraction: 1);
    expect(b.totalShortfall, 40);
  });
}
