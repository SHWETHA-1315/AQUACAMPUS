import 'package:flutter_test/flutter_test.dart';
import 'package:aquacampus/firebase_android_config.dart';

void main() {
  test('registered Android app belongs to the selected campus backend', () {
    expect(AquaCampusFirebaseConfig.projectId, 'aquacampus-ed284');
    expect(AquaCampusFirebaseConfig.androidPackage, 'com.example.aquacampus');
    expect(AquaCampusFirebaseConfig.options.projectId, 'aquacampus-ed284');
    expect(AquaCampusFirebaseConfig.options.appId,
        '1:912969196848:android:29d168ce2772a2b36c54f5');
    expect(AquaCampusFirebaseConfig.options.messagingSenderId, '912969196848');
    expect(AquaCampusFirebaseConfig.options.apiKey, isNotEmpty);
  });
}
