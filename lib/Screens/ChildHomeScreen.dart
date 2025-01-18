import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:child_moni/Authentication/login.dart';
import 'package:child_moni/Screens/AddChildScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ChildHomeScreen extends StatefulWidget {
  final String childDocId;

  const ChildHomeScreen({super.key, required this.childDocId});

  @override
  State<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends State<ChildHomeScreen> {
  late GoogleMapController _controller;
  String userEmail = "Loading...";
  List<AppInfo> installedApps = [];
  late DateTime startTime;
  late DateTime endTime;
  late Timer timer;
  String? currentAppPackage;
  int usageTimeInSeconds = 0;
  static var platform = MethodChannel('com.example.app/foreground');
  Map<String, int> previousUsageTime = {};
  int currentPage = 0; // To keep track of the current page
  int appsPerPage = 5; // Number of apps per page

  String formatDuration(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int remainingSeconds = seconds % 60;

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }


  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(14.5995, 120.9842),
    zoom: 12.0,
  );

  bool isMonitoring = false;

  @override
  void initState() {
    super.initState();
    fetchInstalledApps();
    fetchUserEmailFromParentCollection();
    requestPermissions();
    requestUsageAccessPermission();
  }
  void goToNextPage() {
    setState(() {
      if (currentPage < (installedApps.length / appsPerPage).floor()) {
        currentPage++;
      }
    });
  }

  void goToPreviousPage() {
    setState(() {
      if (currentPage > 0) {
        currentPage--;
      }
    });
  }
  Future<void> fetchUserEmailFromParentCollection() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userId = user.uid;
        final DocumentSnapshot parentDoc = await FirebaseFirestore.instance
            .collection('Parent')
            .doc(userId)
            .get();

        if (parentDoc.exists) {
          setState(() {
            userEmail = parentDoc['email'] ?? "No Email Found";
          });
        } else {
          setState(() {
            userEmail = "Parent Data Not Found";
          });
        }
      } else {
        setState(() {
          userEmail = "Not Logged In";
        });
      }
    } catch (e) {
      setState(() {
        userEmail = "Error: ${e.toString()}";
      });
    }
  }

  Future<void> requestUsageAccessPermission() async {
    if (Platform.isAndroid) {
      try {
        await platform.invokeMethod('requestUsageAccess');
      } catch (e) {
        print("Error requesting usage access: $e");
      }
    }
  }

  Future<void> requestPermissions() async {
    PermissionStatus locationPermission = await Permission.location.request();
    if (locationPermission.isGranted) {
      print("Location permission granted.");
    } else {
      print("Location permission denied.");
    }

    if (Platform.isAndroid && int.parse(Platform.version.split(' ')[0].split('.')[0]) >= 29) {
      PermissionStatus appUsagePermission = await Permission.activityRecognition.request();
      if (appUsagePermission.isGranted) {
        print("App usage permission granted.");
      } else {
        print("App usage permission denied.");
      }
    } else {
      print("App usage permission is not required for your Android version.");
    }
  }

  Future<void> fetchInstalledApps() async {
    try {
      if (await Permission.activityRecognition.isGranted || Platform.isIOS) {
        List<AppInfo> apps = await InstalledApps.getInstalledApps();
        print("Installed apps fetched: ${apps.length}");

        if (apps.isNotEmpty) {
          installedApps = apps.where((app) {
            List<String> systemAppPackages = [
              'com.android.settings',
              'com.android.contacts',
              'com.android.dialer',
              'com.android.messaging',
              'com.google.android.gm',
            ];
            return !systemAppPackages.contains(app.packageName);
          }).toList();

          // Fetch the current usage time from Firestore and update the local state
          final User? user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            final userId = user.uid;
            final appsCollection = FirebaseFirestore.instance
                .collection('Parent')
                .doc(userId)
                .collection('Child')
                .doc(widget.childDocId)
                .collection('InstalledApps');

            // Listen for real-time changes in usage time for each app
            for (var app in installedApps) {
              appsCollection
                  .where('packageName', isEqualTo: app.packageName)
                  .snapshots()
                  .listen((snapshot) {
                if (snapshot.docs.isNotEmpty) {
                  final appData = snapshot.docs.first;
                  setState(() {
                    // Update the usage time for this app
                    previousUsageTime[app.packageName] = appData['usageTime'] ?? 0;

                    // Sort the apps based on usage time after the update
                    installedApps.sort((a, b) {
                      int timeA = previousUsageTime[a.packageName] ?? 0;
                      int timeB = previousUsageTime[b.packageName] ?? 0;
                      return timeB.compareTo(timeA); // Sort in descending order
                    });
                  });
                }
              });
            }

            // Upload installed apps and start tracking app usage
            uploadInstalledAppsWithUsageTime();
            startTrackingAppUsage();
          }
        }
      } else {
        print("App permission not granted.");
      }
    } catch (e) {
      print("Error fetching installed apps: $e");
    }
  }









  void startTrackingAppUsage() {
    setState(() {
      isMonitoring = true;
      // Initialize usageTimeInSeconds to the stored value if it exists
      usageTimeInSeconds = previousUsageTime[currentAppPackage] ?? 0;
    });

    startTime = DateTime.now();
    DateTime lastUpdateTime = DateTime.now();

    timer = Timer.periodic(const Duration(seconds: 5), (Timer t) async {
      try {
        final String? foregroundApp = await platform.invokeMethod('getForegroundApp');

        if (foregroundApp != null && installedApps.any((app) => app.packageName == foregroundApp)) {
          final elapsedTime = DateTime.now().difference(startTime).inSeconds;
          setState(() {
            usageTimeInSeconds = elapsedTime;
          });

          if (DateTime.now().difference(lastUpdateTime).inSeconds >= 10) {
            updateAppUsageTime(foregroundApp, usageTimeInSeconds);
            lastUpdateTime = DateTime.now();
          }
        }
      } catch (e) {
        print("Error checking foreground app: $e");
      }
    });

  }




  Future<void> uploadInstalledAppsWithUsageTime() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userId = user.uid;
        final appsCollection = FirebaseFirestore.instance
            .collection('Parent')
            .doc(userId)
            .collection('Child')
            .doc(widget.childDocId)
            .collection('InstalledApps');

        for (var app in installedApps) {
          final existingAppDoc = await appsCollection
              .where('packageName', isEqualTo: app.packageName)
              .limit(1)
              .get();

          if (existingAppDoc.docs.isEmpty) {
            await appsCollection.add({
              'packageName': app.packageName,
              'name': app.name,
              'timestamp': Timestamp.now(),
              'usageTime': 0,
              'status': "Open"
            });
          }
        }
      }
    } catch (e) {
      print("Error uploading installed apps: $e");
    }
  }

  Future<void> updateAppUsageTime(String packageName, int elapsedTime) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userId = user.uid;
        final appsCollection = FirebaseFirestore.instance
            .collection('Parent')
            .doc(userId)
            .collection('Child')
            .doc(widget.childDocId) // Pass the child document ID
            .collection('InstalledApps');

        // Find the document for the app with the matching package name
        final appDoc = await appsCollection
            .where('packageName', isEqualTo: packageName)
            .limit(1)
            .get();

        if (appDoc.docs.isNotEmpty) {
          final docRef = appDoc.docs.first.reference;

          // Get the current usage time and last update timestamp from Firestore
          final currentDoc = await docRef.get();
          final currentUsageTime = currentDoc.data()?['usageTime'] ?? 0;
          final lastUpdateTimestamp = currentDoc.data()?['lastUpdateTimestamp']?.toDate();

          // If no timestamp exists, initialize it
          final currentTimestamp = DateTime.now();

          // If the last update timestamp exists, calculate the elapsed time since the last update
          if (lastUpdateTimestamp != null) {
            final timeDifference = currentTimestamp.difference(lastUpdateTimestamp).inSeconds;
            setState(() {
              usageTimeInSeconds = currentUsageTime + timeDifference; // Add the time difference
            });
          } else {
            setState(() {
              usageTimeInSeconds = currentUsageTime;
            });
          }

          // Update Firestore with the new usage time and timestamp
          await docRef.update({
            'usageTime': usageTimeInSeconds, // Update total usage time
            'lastUpdateTimestamp': currentTimestamp, // Update the last update timestamp
          });

          print("Updated usage time for app: $packageName, Time: $usageTimeInSeconds seconds");
        }
      }
    } catch (e) {
      print("Error updating app usage time: $e");
    }
  }







  @override
  void dispose() {
    super.dispose();
    if (isMonitoring) {
      timer.cancel();
    }
  }

  Future<void> handleLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginScreen()));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    int startIndex = currentPage * appsPerPage;
    int endIndex = (currentPage + 1) * appsPerPage;
    List<AppInfo> currentAppsPage = installedApps.sublist(startIndex, endIndex > installedApps.length ? installedApps.length : endIndex);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Home", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFFFFC0CB),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundImage: AssetImage("assets/images/onboarding.jpg"),
              backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFFFFC0CB),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundImage: AssetImage("assets/images/onboarding.jpg"),
                  ),
                  const SizedBox(height: 10),
                  const Text("Welcome, User", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(userEmail, style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text("Home"),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text("Profile"),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: handleLogout,
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const SizedBox(height: 20),
              const Text("Location", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                height: 200,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                child: GoogleMap(
                  initialCameraPosition: _initialCameraPosition,
                  onMapCreated: (GoogleMapController controller) {
                    _controller = controller;
                  },
                ),
              ),
              const SizedBox(height: 20),
              const Text("Installed Apps", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...currentAppsPage.map((app) {
                int appUsageTime = previousUsageTime[app.packageName] ?? 0;
                return ListTile(
                  leading: Icon(Icons.apps),
                  title: Text(app.name),
                  subtitle: Text("Usage Time: ${formatDuration(appUsageTime)}"),
                );
              }).toList(),
              // Pagination buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: goToPreviousPage,
                    child: const Text("Previous"),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: goToNextPage,
                    child: const Text("Next"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
