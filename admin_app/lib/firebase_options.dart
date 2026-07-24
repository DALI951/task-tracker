import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return android;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return ios;
    }
    return web;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCm-npO3B4toDBgYQltMRbPOMJxeeypVbw',
    appId: '1:202182349540:android:ac882cbe77afa54f5752f1',
    messagingSenderId: '202182349540',
    projectId: 'task-tracker-6d7e1',
    storageBucket: 'task-tracker-6d7e1.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCm-npO3B4toDBgYQltMRbPOMJxeeypVbw',
    appId: '1:202182349540:ios:XXXXXXXXXX',
    messagingSenderId: '202182349540',
    projectId: 'task-tracker-6d7e1',
    storageBucket: 'task-tracker-6d7e1.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCq3-FOmjHuQH86QfA5Vf7c8hyneS0nbC0',
    appId: '1:202182349540:web:615e867d1f96fb835752f1',
    messagingSenderId: '202182349540',
    projectId: 'task-tracker-6d7e1',
    authDomain: 'task-tracker-6d7e1.firebaseapp.com',
    storageBucket: 'task-tracker-6d7e1.firebasestorage.app',
  );
}
