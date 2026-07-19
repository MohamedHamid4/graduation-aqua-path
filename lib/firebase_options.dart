// ignore_for_file: lines_longer_than_80_chars
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

/// Default Firebase configuration for AquaPath.
/// Generated from: google-services.json (project: aquapath-c2188)
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions not configured for $defaultTargetPlatform',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDjIjr-t6liXDdf8DqoUuek233sCpDqwGw',
    appId: '1:366533302066:android:3c66448c5fbab04fd8292b',
    messagingSenderId: '366533302066',
    projectId: 'aquapath-c2188',
    storageBucket: 'aquapath-c2188.firebasestorage.app',
  );

  // iOS: add GoogleService-Info.plist and fill in values when iOS is targeted.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'PLACEHOLDER_IOS_API_KEY',
    appId: 'PLACEHOLDER_IOS_APP_ID',
    messagingSenderId: '366533302066',
    projectId: 'aquapath-c2188',
    storageBucket: 'aquapath-c2188.firebasestorage.app',
    iosBundleId: 'com.aquapath.app',
  );
}
