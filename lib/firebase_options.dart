import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.android:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'FirebaseOptions are not configured for this platform yet.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDvt8W9g9umomUhbMSh478oMnXM_lxk33E',
    appId: '1:416830645566:web:76bdf3242d68f7de9cf86f',
    messagingSenderId: '416830645566',
    projectId: 'voicebill-334b2',
    authDomain: 'voicebill-334b2.firebaseapp.com',
    storageBucket: 'voicebill-334b2.firebasestorage.app',
    measurementId: 'G-RDFEKJ4XXM',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAAfnwIcHoaKRPGLoGuMukuRV2fXQxugPA',
    appId: '1:416830645566:ios:1cbc2d95864d8e2c9cf86f',
    messagingSenderId: '416830645566',
    projectId: 'voicebill-334b2',
    storageBucket: 'voicebill-334b2.firebasestorage.app',
    iosBundleId: 'com.khanhduy.voicebill',
  );
}
