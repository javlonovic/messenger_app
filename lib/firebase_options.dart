import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return android;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDl5NQUBrSTzXnmdAB8pJRJg4UF0YiZQyU',
    appId: '1:67886509446:android:6f026e7cc8e838e439d007',
    messagingSenderId: '67886509446',
    projectId: 'messenger-app-16fda',
    authDomain: 'messenger-app-16fda.firebaseapp.com',
    storageBucket: 'messenger-app-16fda.firebasestorage.app',
  );
}
