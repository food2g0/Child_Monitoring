import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> handleBackgroundMessage(RemoteMessage message) async {
  print('Title: ${message.notification?.title}');
  print('Body: ${message.notification?.body}');
  print('Payload: ${message.data}');
}

class FirebaseApi {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> initNotification() async {
    await _firebaseMessaging.requestPermission();
    final fcmToken = await _firebaseMessaging.getToken();

    if (fcmToken != null) {
      print('FCM Token: $fcmToken');


      String? currentChildId = await getCurrentChildId();

      if (currentChildId != null) {
        User? user = _auth.currentUser;
        if (user != null) {
          await saveTokenToDatabase(user.uid, currentChildId, fcmToken);
        } else {
          print('No authenticated user found.');
        }
      } else {
        print('No child ID found in SharedPreferences.');
      }
    }

    FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);
  }

  /// Retrieve current child ID from SharedPreferences
  Future<String?> getCurrentChildId() async {
    final SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    return sharedPreferences.getString("childDocId");
  }

  /// Save FCM Token to Firestore under the correct child ID
  Future<void> saveTokenToDatabase(String userId, String childId, String token) async {
    try {
      await _firestore
          .collection('Parent')
          .doc(userId)
          .collection('Child')
          .doc(childId)
          .set({'fcmToken': token}, SetOptions(merge: true)); // Prevents overwriting other fields

      print('FCM Token saved to Firestore');
    } catch (e) {
      print('Error saving FCM token: $e');
    }
  }
}
