import 'package:flutter/services.dart';

class AppBlocker {
  static const platform = MethodChannel('com.example.child_moni/app_blocker');

  static Future<void> startAppBlockerService() async {
    try {
      await platform.invokeMethod('startAppBlockerService');
    } on PlatformException catch (e) {
      print("Failed to start AppBlockerService: '${e.message}'.");
    }
  }
}