import 'package:child_moni/Screens/Parent_AppLimit.dart';
import 'package:child_moni/Screens/blockScreen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SelectedChildScreen extends StatefulWidget {
  final String childId;

  const SelectedChildScreen({Key? key, required this.childId}) : super(key: key);

  @override
  _SelectedChildScreenState createState() => _SelectedChildScreenState();
}

class _SelectedChildScreenState extends State<SelectedChildScreen> {
  late Future<List<Map<String, dynamic>>> installedAppsFuture;
  late Future<String?> childNameFuture;

  @override
  void initState() {
    super.initState();
    installedAppsFuture = fetchInstalledApps(widget.childId);
    childNameFuture = fetchChildName(widget.childId);
  }

  Future<String?> fetchChildName(String childId) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid;

      final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore.instance
          .collection('Parent')
          .doc(userId)
          .collection('Child')
          .doc(childId)
          .get();

      return doc.data()?['name'] as String?;
    } catch (e) {
      debugPrint('Error fetching child name: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchInstalledApps(String childId) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid;

      final QuerySnapshot<Map<String, dynamic>> querySnapshot = await FirebaseFirestore.instance
          .collection('Parent')
          .doc(userId)
          .collection('Child')
          .doc(childId)
          .collection('InstalledApps')
          .get();

      final apps = querySnapshot.docs.map((doc) {
        final data = doc.data();
        final usageTimeInSeconds = data['usageTime'] ?? 0;

        // Format usageTime as hr:min:sec
        final formattedUsageTime = formatDuration(Duration(seconds: usageTimeInSeconds));

        return {
          ...data,
          'formattedUsageTime': formattedUsageTime, // Add formatted time
          'usageTime': usageTimeInSeconds,         // Keep original for sorting
        };
      }).toList();

      // Sort apps by usageTime in descending order
      apps.sort((a, b) => b['usageTime'].compareTo(a['usageTime']));

      return apps;
    } catch (e) {
      debugPrint('Error fetching installed apps: $e');
      return [];
    }
  }

  String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFC0CB),
        title: FutureBuilder<String?>(
          future: childNameFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text('Loading...');
            } else if (snapshot.hasError) {
              return const Text('Error');
            } else {
              final childName = snapshot.data ?? 'Child Details';
              return Text(childName);
            }
          },
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: installedAppsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Error fetching installed apps.'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No installed apps found.'));
          } else {
            final installedApps = snapshot.data!;

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundImage: AssetImage('assets/child_avatar.png'),
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<String?>(
                    future: childNameFuture,
                    builder: (context, snapshot) {
                      final childName = snapshot.data ?? 'Installed Apps';
                      return Text(
                        childName,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (c)=> BlockScreen(childId: widget.childId,)));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Block'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (c)=> AppLimit(childId: widget.childId,)));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('App Limits'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // Handle GPS functionality
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('GPS'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      itemCount: installedApps.length,
                      itemBuilder: (context, index) {
                        final app = installedApps[index];
                        return _buildActivityTile(
                          app['name'] ?? 'Unknown App',
                          app['formattedUsageTime'] ?? '00:00:00',
                          Icons.apps,
                          Colors.blueGrey,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildActivityTile(String appName, String usage, IconData icon, Color iconColor) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(appName),
        trailing: Text(usage, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
