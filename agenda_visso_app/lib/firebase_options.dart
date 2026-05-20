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
        throw UnsupportedError('iOS not supported yet');
      case TargetPlatform.macOS:
        throw UnsupportedError('macOS not supported');
      case TargetPlatform.windows:
        throw UnsupportedError('Windows not supported');
      case TargetPlatform.linux:
        throw UnsupportedError('Linux not supported');
      default:
        throw UnsupportedError('Unsupported platform');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA_U0z3huKLFhoLqT3-F0qeIdJSDr5d2rk',
    appId: '1:838741808501:web:2310b664c03b68e96faf3c',
    messagingSenderId: '838741808501',
    projectId: 'agendavisso',
    authDomain: 'agendavisso.firebaseapp.com',
    storageBucket: 'agendavisso.firebasestorage.app',
    measurementId: 'G-H6B3WV3F01',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA1lG05hljHYclXoglWaex9cGR_KVOEZAs',
    appId: '1:838741808501:android:e7b2012fae0230dc6faf3c',
    messagingSenderId: '838741808501',
    projectId: 'agendavisso',
    storageBucket: 'agendavisso.firebasestorage.app',
  );
}
