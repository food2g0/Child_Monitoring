import 'dart:convert';

import 'package:child_moni/Screens/SelectedChildScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as ga;
import 'package:firebase_auth/firebase_auth.dart';
class AppLimit extends StatefulWidget {
  final String childId;
  const AppLimit({super.key, required this.childId});

  @override
  State<AppLimit> createState() => _AppLimitState();
}

class _AppLimitState extends State<AppLimit> {
  late Future<List<Map<String, dynamic>>> installedAppsFuture;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    installedAppsFuture = fetchInstalledApps();
  }

  Future<List<Map<String, dynamic>>> fetchInstalledApps() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid;

      final QuerySnapshot<Map<String, dynamic>> querySnapshot = await FirebaseFirestore.instance
          .collection('Parent')
          .doc(userId)
          .collection('Child')
          .doc(widget.childId)
          .collection('InstalledApps')
          .get();

      List<Map<String, dynamic>> apps = querySnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();

      apps.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
      return apps;
    } catch (e) {
      debugPrint('Error fetching installed apps: $e');
      return [];
    }
  }



  //for Time limit
  Future<void> setAppTimeLimit(String appId, int timeLimitInMinutes) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid;
      final int timeLimitInSeconds = timeLimitInMinutes * 60;

      await FirebaseFirestore.instance
          .collection('Parent')
          .doc(userId)
          .collection('Child')
          .doc(widget.childId)
          .collection('InstalledApps')
          .doc(appId)
          .update({
        'timeLimit': timeLimitInSeconds,
        'isBlocked': false, // Set isBlocked to false when setting a time limit
      });
      await sendNotificationToChild();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Time limit updated!')),
      );
    } catch (e) {
      debugPrint('Error updating time limit: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error updating time limit.')),
      );
    }
  }

  //Para makuha yung notification Token
  Future<String> getAccessToken() async {
    try {
      final serviceAccountJson = await rootBundle.loadString('assets/childmonitoring.json');
      final credentials = ga.ServiceAccountCredentials.fromJson(serviceAccountJson);

      final client = await ga.clientViaServiceAccount(
        credentials,
        ['https://www.googleapis.com/auth/cloud-platform'],
      );

      return client.credentials.accessToken.data;
    } catch (e) {
      debugPrint("Error getting access token: $e");
      return "";
    }
  }




  //function sa pagsend ng notification
  Future<void> sendNotificationToChild() async {
    try {
      // Get child's FCM token
      final userId = _auth.currentUser?.uid;
      final childDoc = await _firestore.collection('Parent').doc(userId).collection('Child').doc(widget.childId).get();

      final String? fcmToken = childDoc.data()?['fcmToken'];
      if (fcmToken == null) {
        debugPrint('FCM token not found for child');
        return;
      }

      final String accessToken = await getAccessToken();
      if (accessToken.isEmpty) {
        debugPrint('Failed to get access token');
        return;
      }

      final Uri url = Uri.parse(
          'https://fcm.googleapis.com/v1/projects/7438395273/messages:send');

      final Map<String, dynamic> notificationPayload = {
        "message": {
          "token": fcmToken,
          "notification": {
            "title": "App Limit",
            "body": "Your parent set time limit to your app.",
          },
          "android": {
            "priority": "high",
          },
        }
      };

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $accessToken",
        },
        body: jsonEncode(notificationPayload),
      );

      if (response.statusCode == 200) {
        debugPrint('Notification sent successfully');
      } else {
        debugPrint('Failed to send notification: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }
  String _formatTime(int seconds) {
    if (seconds <= 0) return "No time limit";
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return "$minutes min ${secs}s";
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (c)=> SelectedChildScreen(childId: widget.childId,)));
        return Future.value(false);
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Color(0xFFFFC0CB),
          title: const Text('Manage Apps', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Search Apps',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
                onChanged: (value) {
                  setState(() {
                    searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('Parent')
                    .doc(_auth.currentUser?.uid)
                    .collection('Child')
                    .doc(widget.childId)
                    .collection('InstalledApps')
                    .snapshots(), // Listening for real-time updates
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return const Center(child: Text('Error fetching apps.'));
                  } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No apps found.'));
                  } else {
                    final installedApps = snapshot.data!.docs
                        .map((doc) => {
                      'id': doc.id,
                      ...doc.data(),
                    })
                        .where((app) => (app['name'] ?? '').toLowerCase().contains(searchQuery))
                        .toList();

                    return ListView.builder(
                      itemCount: installedApps.length,
                      itemBuilder: (context, index) {
                        final app = installedApps[index];
                        final appName = app['name'] ?? 'Unknown App';
                        final appId = app['id'];
                        final appIconUrl = app['iconUrl'];

                        // Listen to Firestore updates for each app
                        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: _firestore
                              .collection('Parent')
                              .doc(_auth.currentUser?.uid)
                              .collection('Child')
                              .doc(widget.childId)
                              .collection('InstalledApps')
                              .doc(appId)
                              .snapshots(), // LISTEN FOR CHANGES HERE
                          builder: (context, snapshot) {
                            if (!snapshot.hasData || snapshot.data == null) {
                              return const SizedBox(); // Prevents errors if no data is found
                            }

                            final appData = snapshot.data!.data();
                            final int timeLimitInSeconds = appData?['timeLimit'] ?? 0;

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                              elevation: 4,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(12),
                                leading: appIconUrl != null
                                    ? Image.network(appIconUrl, width: 40, height: 40)
                                    : const Icon(Icons.apps, size: 40),
                                title: Text(appName, style: const TextStyle(fontWeight: FontWeight.w500)),
                                subtitle: Text('Remaining Time: ${_formatTime(timeLimitInSeconds)}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.timer, color: Color(0xFFFF4081)),
                                  onPressed: () {
                                    _showTimeLimitDialog(appId);
                                  },
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );

                  }
                },
              ),
            ),

          ],
        ),
      ),
    );
  }

  void _showTimeLimitDialog(String appId) {
    final TextEditingController timeLimitController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Set Time Limit'),
          content: TextField(
            controller: timeLimitController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Time limit (in minutes)',
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final int timeLimit = int.tryParse(timeLimitController.text) ?? 0;
                if (timeLimit > 0) {
                  setAppTimeLimit(appId, timeLimit);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid time limit.')),
                  );
                }
              },
              child: const Text('Set Limit'),
            ),
          ],
        );
      },
    );
  }
}
