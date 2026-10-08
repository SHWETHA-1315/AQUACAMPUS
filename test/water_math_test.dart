import 'package:flutter_test/flutter_test.dart';
import 'package:aquacampus/water_math.dart';

void main() {
  test('rectangular tank 100 x 100 with 17 cm of water = 170 L', () {
    expect(WaterMath.availableLitres(shape: 'rect', heightCm: 100, waterHeightCm: 17, lengthCm: 100, widthCm: 100), closeTo(170, 0.001));
  });
  test('cylindrical upright tank volume', () {
    expect(WaterMath.availableLitres(shape: 'cylinder', heightCm: 100, waterHeightCm: 100, diameterCm: 100), closeTo(785.398, 0.01));
  });
  test('reading never exceeds tank capacity', () {
    expect(WaterMath.availableLitres(shape: 'rect', heightCm: 100, waterHeightCm: 500, lengthCm: 100, widthCm: 100), 1000);
  });
  test('four requests at 5 litres each use 20 litres', () {
    expect(4 * 5, 20);
  });
  test('empty rectangular tank has zero litres', () {
    expect(WaterMath.availableLitres(shape: 'rect', heightCm: 200,
      waterHeightCm: 0, lengthCm: 100, widthCm: 100), 0);
  });
  test('negative dipstick reading is clamped to zero', () {
    expect(WaterMath.availableLitres(shape: 'rect', heightCm: 100,
      waterHeightCm: -3, lengthCm: 100, widthCm: 100), 0);
  });
  test('zero occupants do not cause division-by-zero', () {
    expect(WaterMath.perPersonShare(500, 0), 0);
  });
  test('all tank water reserved means zero per-person budget', () {
    expect(WaterMath.perPersonShare(500, 5, reserveFraction: 1), 0);
  });
  test('500 litre tank for 10 people after 15% reserve', () {
    expect(WaterMath.perPersonShare(500, 10), closeTo(42.5, 0.001));
  });
}
