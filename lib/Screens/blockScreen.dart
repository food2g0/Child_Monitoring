import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as ga;


class BlockScreen extends StatefulWidget {
  final String childId;
  const BlockScreen({super.key, required this.childId});

  @override
  State<BlockScreen> createState() => _BlockScreenState();
}

class _BlockScreenState extends State<BlockScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> installedApps = [];
  List<Map<String, dynamic>> filteredApps = [];
  TextEditingController searchController = TextEditingController();
  late Future<List<Map<String, dynamic>>> installedAppsFuture;

  @override
  void initState() {
    super.initState();
    installedAppsFuture = fetchInstalledApps();
    searchController.addListener(() => filterApps());
  }
  void filterApps() {
    String query = searchController.text.toLowerCase();
    setState(() {
      filteredApps = installedApps
          .where((app) => (app['name'] ?? '').toLowerCase().contains(query))
          .toList();
    });
  }

  Future<List<Map<String, dynamic>>> fetchInstalledApps() async {
    try {
      final User? user = _auth.currentUser;
      final userId = user?.uid;

      final querySnapshot = await _firestore
          .collection('Parent')
          .doc(userId)
          .collection('Child')
          .doc(widget.childId)
          .collection('InstalledApps')
          .get();

      final apps = querySnapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();

      apps.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));

      setState(() {
        installedApps = apps;
        filteredApps = apps;
      });

      return apps;
    } catch (e) {
      debugPrint('Error fetching installed apps: $e');
      return [];
    }
  }

  Future<void> toggleAppStatus(String appId, bool isBlocked, String appName) async {
    bool? confirmAction = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isBlocked ? 'Unblock App' : 'Block App'),
        content: Text(
            isBlocked ? 'Are you sure you want to unblock $appName?' : 'Are you sure you want to block $appName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmAction == true) {
      try {
        final User? user = _auth.currentUser;
        final userId = user?.uid;

        await _firestore
            .collection('Parent')
            .doc(userId)
            .collection('Child')
            .doc(widget.childId)
            .collection('InstalledApps')
            .doc(appId)
            .set({'isBlocked': isBlocked}, SetOptions(merge: true)); // This prevents overwriting unnecessary fields


        if (isBlocked) {
          await sendNotificationToChild(appName);
        }

        setState(() {
          installedAppsFuture = fetchInstalledApps();
        });
      } catch (e) {
        debugPrint('Error updating app status: $e');
      }
    }
  }
  /// Get OAuth 2.0 Access Token for Firebase Cloud Messaging
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

  /// Send FCM Notification using OAuth 2.0
  Future<void> sendNotificationToChild(String appName) async {
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
            "title": "App Blocked",
            "body": "$appName has been blocked by your parent.",
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

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFC0CB),
        title: const Text('Manage Apps'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "Search apps...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: installedAppsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return const Center(child: Text('Error fetching apps.'));
                } else if (filteredApps.isEmpty) {
                  return const Center(child: Text('No apps found.'));
                } else {
                  return ListView.builder(
                    itemCount: filteredApps.length,
                    itemBuilder: (context, index) {
                      final app = filteredApps[index];
                      final appName = app['name'] ?? 'Unknown App';
                      final isBlocked = app['isBlocked'] ?? false;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        child: ListTile(
                          leading: Icon(Icons.apps, color: isBlocked ? Colors.red : Colors.green),
                          title: Text(appName),
                          trailing: ElevatedButton(
                            onPressed: () {
                              toggleAppStatus(app['id'], !isBlocked, appName);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isBlocked ? Colors.green : const Color(0xFFe01e37),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              isBlocked ? 'Unblock' : 'Block',
                              style: const TextStyle(color: Color(0xFFf5f3f4)),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
