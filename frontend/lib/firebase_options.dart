import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB6Y7KNrWNXu9YOHLu8KsV9OiC9QIiD94c',
    appId: '1:121234687397:web:f55036e3aa085f2f2e144c',
    messagingSenderId: '121234687397',
    projectId: 'society-management-syste-15a8e',
    authDomain: 'society-management-syste-15a8e.firebaseapp.com',
    storageBucket: 'society-management-syste-15a8e.firebasestorage.app',
    measurementId: 'G-90PV4BB011',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCwfjCvLSjeVLfzhpo5cVL08BrKrSnlgsc',
    appId: '1:121234687397:android:82a6ffb9399ff3152e144c',
    messagingSenderId: '121234687397',
    projectId: 'society-management-syste-15a8e',
    storageBucket: 'society-management-syste-15a8e.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB6Y7KNrWNXu9YOHLu8KsV9OiC9QIiD94c',
    appId: '1:121234687397:ios:PLACEHOLDER', // Update with actual iOS App ID
    messagingSenderId: '121234687397',
    projectId: 'society-management-syste-15a8e',
    storageBucket: 'society-management-syste-15a8e.firebasestorage.app',
    iosBundleId: 'com.society.manager.frontend',
  );
}
