// File generated for Firebase Configuration in ChatMe
// Project: chatme-bfcb2 (164678238686)
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
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA_chatme_web_key',
    appId: '1:164678238686:web:6e108e48d3e2bb9c',
    messagingSenderId: '164678238686',
    projectId: 'chatme-bfcb2',
    authDomain: 'chatme-bfcb2.firebaseapp.com',
    storageBucket: 'chatme-bfcb2.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA_chatme_android_key',
    appId: '1:164678238686:android:b206ff8a946b539c',
    messagingSenderId: '164678238686',
    projectId: 'chatme-bfcb2',
    storageBucket: 'chatme-bfcb2.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA_chatme_ios_key',
    appId: '1:164678238686:ios:c489bf204e12da34',
    messagingSenderId: '164678238686',
    projectId: 'chatme-bfcb2',
    storageBucket: 'chatme-bfcb2.firebasestorage.app',
    iosBundleId: 'com.chatme.chatme',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyA_chatme_ios_key',
    appId: '1:164678238686:ios:c489bf204e12da34',
    messagingSenderId: '164678238686',
    projectId: 'chatme-bfcb2',
    storageBucket: 'chatme-bfcb2.firebasestorage.app',
    iosBundleId: 'com.chatme.chatme',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyA_chatme_web_key',
    appId: '1:164678238686:web:6e108e48d3e2bb9c',
    messagingSenderId: '164678238686',
    projectId: 'chatme-bfcb2',
    authDomain: 'chatme-bfcb2.firebaseapp.com',
    storageBucket: 'chatme-bfcb2.firebasestorage.app',
  );
}

