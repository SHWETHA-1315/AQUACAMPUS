import 'package:aquacampus/campus_store.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> tank(String id, String facility, {String measured = ''}) =>
    {
      'id': id,
      'facilityId': facility,
      'shape': 'rect',
      'heightCm': 100.0,
      'lengthCm': 100.0,
      'widthCm': 100.0,
      'diameterCm': 0.0,
      'waterHeightCm': measured.isEmpty ? 0.0 : 50.0,
      'lastMeasuredAt': measured,
    };

void main() {
  test('no tanks is unknown, not a fabricated zero measurement', () {
    final store = CampusStore();
    expect(store.hasCompleteReadingsFor('hostel'), isFalse);
    expect(store.missingReadingsFor('hostel'), 0);
    expect(store.facilityWaterSummary('hostel'), 'No tanks registered');
    store.dispose();
  });

  test('a partial measurement never qualifies as complete', () {
    final store = CampusStore();
    store.tanks = [
      tank('one', 'hostel', measured: '2026-10-09T07:00:00Z'),
      tank('two', 'hostel'),
      tank('three', 'canteen', measured: '2026-10-09T07:00:00Z'),
    ];
    expect(store.hasCompleteReadingsFor('hostel'), isFalse);
    expect(store.missingReadingsFor('hostel'), 1);
    expect(store.availableFor('hostel'), closeTo(500, 0.01));
    expect(store.facilityWaterSummary('hostel'), contains('partial: 1/2 tanks'));
    expect(store.hasCompleteReadingsFor('canteen'), isTrue);
    store.dispose();
  });

  test('complete tank readings unlock accurate water planning', () {
    final store = CampusStore();
    store.tanks = [
      tank('one', 'hostel', measured: '2026-10-09T07:00:00Z'),
      tank('two', 'hostel', measured: '2026-10-09T07:10:00Z'),
    ];
    expect(store.hasCompleteReadingsFor('hostel'), isTrue);
    expect(store.missingReadingsFor('hostel'), 0);
    expect(store.availableFor('hostel'), closeTo(1000, 0.01));
    expect(store.facilityWaterSummary('hostel'), contains('all 2 tanks measured'));
    store.dispose();
  });
}
