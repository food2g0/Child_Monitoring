import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BlockScreen extends StatefulWidget {
  final String childId;
  const BlockScreen({super.key, required this.childId});

  @override
  State<BlockScreen> createState() => _BlockScreenState();
}

class _BlockScreenState extends State<BlockScreen> {
  late Future<List<Map<String, dynamic>>> installedAppsFuture;

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
          .doc(widget.childId) // Replace 'childId' with the actual child ID if needed
          .collection('InstalledApps')
          .get();

      return querySnapshot.docs.map((doc) {
        return {
          'id': doc.id, // App document ID for updates
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching installed apps: $e');
      return [];
    }
  }

  Future<void> toggleAppStatus(String appId, bool isBlocked) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid;

      await FirebaseFirestore.instance
          .collection('Parent')
          .doc(userId)
          .collection('Child')
          .doc(widget.childId) // Replace 'childId' with the actual child ID if needed
          .collection('InstalledApps')
          .doc(appId)
          .update({'isBlocked': isBlocked});

      // Refresh the app list after update
      setState(() {
        installedAppsFuture = fetchInstalledApps();
      });
    } catch (e) {
      debugPrint('Error updating app status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFFFC0CB),
        title: const Text('Manage Apps'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: installedAppsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Error fetching apps.'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No apps found.'));
          } else {
            final installedApps = snapshot.data!;

            return ListView.builder(
              itemCount: installedApps.length,
              itemBuilder: (context, index) {
                final app = installedApps[index];
                final appName = app['name'] ?? 'Unknown App';
                final isBlocked = app['isBlocked'] ?? false;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: ListTile(
                    leading: Icon(Icons.apps, color: isBlocked ? Colors.red : Colors.green),
                    title: Text(appName),
                    trailing: ElevatedButton(
                      onPressed: () {
                        toggleAppStatus(app['id'], !isBlocked);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isBlocked ? Colors.green : Color(0xFFe01e37),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(isBlocked ? 'Unblock' : 'Block', style: TextStyle(color: Color(0xFFf5f3f4)),),
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
