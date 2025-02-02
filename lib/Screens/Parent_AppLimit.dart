import 'package:child_moni/Screens/SelectedChildScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLimit extends StatefulWidget {
  final String childId;
  const AppLimit({super.key, required this.childId});

  @override
  State<AppLimit> createState() => _AppLimitState();
}

class _AppLimitState extends State<AppLimit> {
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
          .doc(widget.childId)
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

  Future<void> setAppTimeLimit(String appId, int timeLimitInMinutes) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid;

      // Convert the time limit from minutes to seconds
      final int timeLimitInSeconds = timeLimitInMinutes * 60;

      await FirebaseFirestore.instance
          .collection('Parent')
          .doc(userId)
          .collection('Child')
          .doc(widget.childId)
          .collection('InstalledApps')
          .doc(appId)
          .update({
        'timeLimit': timeLimitInSeconds, // Save the time limit in seconds
      });

      // Show a success message
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // You can customize what happens when the back button is pressed
        // For example, if you want to navigate back to the previous screen instead of home:
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (c)=> SelectedChildScreen(childId: widget.childId,)));
        return Future.value(false); // This prevents the default back behavior
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Color(0xFFFFC0CB),
          title: const Text('Manage Apps', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
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
                  final appId = app['id'];
                  final appIconUrl = app['iconUrl']; // Assume iconUrl is stored in Firestore

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: appIconUrl != null
                          ? Image.network(appIconUrl, width: 40, height: 40) // Display app icon from URL
                          : const Icon(Icons.apps, size: 40), // Fallback if no icon URL
                      title: Text(appName, style: const TextStyle(fontWeight: FontWeight.w500)),
                      trailing: IconButton(
                        icon: const Icon(Icons.timer, color: Color(0xFFFF4081)), // Timer icon with color
                        onPressed: () {
                          _showTimeLimitDialog(appId);
                        },
                      ),
                    ),
                  );
                },
              );
            }
          },
        ),
      ),
    );
  }

  // Function to show the time limit input dialog
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
            inputFormatters: [FilteringTextInputFormatter.digitsOnly], // Ensure only numbers
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
