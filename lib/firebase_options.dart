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

  // Web Configuration
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC0HsSHd3rAc6oH3yB8moa_vrHHud4oNtU',
    appId: '1:609566359109:web:a57c16eaa9ee4dffefad2c',
    messagingSenderId: '609566359109',
    projectId: 'smartpay-9558e',
    authDomain: 'smartpay-9558e.firebaseapp.com',
    storageBucket: 'smartpay-9558e.firebasestorage.app',
  );

  // Android Configuration
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC0HsSHd3rAc6oH3yB8moa_vrHHud4oNtU',
    appId: '1:609566359109:android:a57c16eaa9ee4dffefad2c',
    messagingSenderId: '609566359109',
    projectId: 'smartpay-9558e',
    storageBucket: 'smartpay-9558e.firebasestorage.app',
  );

  // iOS Configuration
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC0HsSHd3rAc6oH3yB8moa_vrHHud4oNtU',
    appId: '1:609566359109:ios:a57c16eaa9ee4dffefad2c',
    messagingSenderId: '609566359109',
    projectId: 'smartpay-9558e',
    iosBundleId: 'com.example.smartpay',
    storageBucket: 'smartpay-9558e.firebasestorage.app',
  );
}
