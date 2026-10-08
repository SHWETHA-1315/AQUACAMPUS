import 'package:firebase_core/firebase_core.dart';

/// Public Firebase *Android client* configuration for the existing
/// AQUACAMPUS project. Generated from its registered Android app config.
///
/// These identifiers ship in every APK by design. They are NOT Admin SDK
/// credentials. Firestore Security Rules and Firebase Auth protect data.
/// Never put a private key or service-account JSON in this file.
abstract final class AquaCampusFirebaseConfig {
  static const projectId = 'aquacampus-ed284';
  static const androidPackage = 'com.example.aquacampus';
  static const FirebaseOptions options = FirebaseOptions(
    apiKey: 'AIzaSyAVYYQlwrBckfomcLBfa57mcjrv09DN5QI',
    appId: '1:912969196848:android:29d168ce2772a2b36c54f5',
    messagingSenderId: '912969196848',
    projectId: projectId,
    storageBucket: 'aquacampus-ed284.firebasestorage.app',
  );
}
