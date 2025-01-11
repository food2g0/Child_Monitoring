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
import 'package:package_info_plus/package_info_plus.dart'; // Import package_info_plus

class ChildHomeScreen extends StatefulWidget {
  final String childDocId; // Pass the child document ID

  const ChildHomeScreen({super.key, required this.childDocId});

  @override
  State<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends State<ChildHomeScreen> {
  late GoogleMapController _controller;
  String userEmail = "Loading..."; // Placeholder email
  List<Map<String, dynamic>> children = []; // List to store children data
  List<AppInfo> installedApps = []; // List to store AppInfo objects
  late DateTime startTime;
  late DateTime endTime;
  late Timer timer;
  String? currentAppPackage; // Track the currently monitored app's package name
  int usageTimeInSeconds = 0; // Track the usage time in seconds
  static var platform = MethodChannel('com.example.app/foreground');

  // Initial camera position
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(14.5995, 120.9842), // Replace with desired coordinates
    zoom: 12.0,
  );

  bool isMonitoring = false; // Track whether monitoring is active

  @override
  void initState() {
    super.initState();
    fetchInstalledApps(); // Fetch installed apps and start monitoring automatically
    fetchUserEmailFromParentCollection();
    requestPermissions();
    requestUsageAccessPermission();// Request permissions when the screen is initialized
  }
  Future<String?> getForegroundApp() async {
    try {
      final String? result = await platform.invokeMethod('getForegroundApp');
      return result;
    } on PlatformException catch (e) {
      print('Error checking foreground app: $e');
      return null;
    }
  }

  // Fetch the email of the current user from the parent collection in Firestore
  Future<void> fetchUserEmailFromParentCollection() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userId = user.uid; // Get the user ID
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
      const platform = MethodChannel('com.example.app/foreground');
      try {
        await platform.invokeMethod('requestUsageAccess');
      } catch (e) {
        print("Error requesting usage access: $e");
      }
    }
  }

  // Request location and app usage permissions
  Future<void> requestPermissions() async {
    // Request location permission
    PermissionStatus locationPermission = await Permission.location.request();
    if (locationPermission.isGranted) {
      print("Location permission granted.");
    } else {
      print("Location permission denied.");
    }


    // Request app usage permission for Android 10+
    if (Platform.isAndroid && int.parse(Platform.version.split(' ')[0].split('.')[0]) >= 29) {
      // For Android 10 and higher, request activity recognition permission
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
      // Check if permission is granted before fetching apps
      if (await Permission.activityRecognition.isGranted || Platform.isIOS) {
        // Fetch installed apps as AppInfo objects
        List<AppInfo> apps = await InstalledApps.getInstalledApps();
        print("Installed apps fetched: ${apps.length}");

        if (apps.isNotEmpty) {
          installedApps = apps.where((app) {
            // List of known system app package names to exclude
            List<String> systemAppPackages = [
              'com.android.settings', // Settings app
              'com.android.contacts', // Contacts app
              'com.android.dialer', // Dialer app
              'com.android.messaging', // Messages app
              'com.google.android.gm',
              // Add other known system apps here
            ];

            // Filter out system apps based on package name
            return !systemAppPackages.contains(app.packageName);
          }).toList();

          // Log the filtered apps
          print("Filtered installed apps: ${installedApps.length}");

          // Start uploading apps and their initial usage time to Firestore
          uploadInstalledAppsWithUsageTime();

          // Start monitoring all apps immediately
          for (var app in installedApps) {
            startTrackingAppUsage(app.packageName); // Start monitoring each app
          }
        }
      } else {
        print("App permission not granted.");
      }
    } catch (e) {
      print("Error fetching installed apps: $e");
    }
  }



// Start tracking the app usage time for a specific app
  void startTrackingAppUsage(String packageName) {
    setState(() {
      isMonitoring = true;
      usageTimeInSeconds = 0; // Reset usage time
      currentAppPackage = packageName; // Store the current app's package name
    });

    // Initialize the start time when the app is opened
    startTime = DateTime.now();

    // Start a timer to check the foreground app and track usage time
    timer = Timer.periodic(const Duration(seconds: 1), (Timer t) async {
      try {
        var platform = MethodChannel('com.example.app/foreground');
        final String? foregroundApp = await platform.invokeMethod('getForegroundApp');

        if (foregroundApp == packageName) {
          setState(() {
            usageTimeInSeconds++;
          });
          updateAppUsageTime(packageName, usageTimeInSeconds); // Update the database
        }
      } catch (e) {
        print("Error checking foreground app: $e");
      }
    });

  }


// Upload installed apps and usage time to Firestore
  Future<void> uploadInstalledAppsWithUsageTime() async {
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

        for (var app in installedApps) {
          // Check if the app already exists in Firestore
          final existingAppDoc = await appsCollection
              .where('packageName', isEqualTo: app.packageName)
              .limit(1)
              .get();

          if (existingAppDoc.docs.isEmpty) {
            // Upload app information and initial usage time if not found
            await appsCollection.add({
              'packageName': app.packageName,
              'name': app.name,
              'timestamp': Timestamp.now(),
              'usageTime': 0, // Initial usage time (0 seconds)
            });
          }
        }
      }
    } catch (e) {
      print("Error uploading installed apps: $e");
    }
  }

// Update Firestore with the usage time for a specific app
  Future<void> updateAppUsageTime(String packageName, int usageTime) async {
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
          await docRef.update({
            'usageTime': FieldValue.increment(usageTime), // Increment usage time
          });

          print("Updated usage time for app: $packageName, Time: $usageTime seconds");
        }
      }
    } catch (e) {
      print("Error updating app usage time: $e");
    }
  }

  @override
  void dispose() {
    super.dispose();
    // Cancel the timer when the app is disposed
    if (isMonitoring) {
      timer.cancel();
    }
  }

  // Logout function
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Home",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFFFC0CB),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CircleAvatar(
              backgroundImage:
              AssetImage("assets/images/onboarding.jpg"), // Replace with your image
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
                    backgroundImage: AssetImage("assets/images/onboarding.jpg"), // Replace with user image
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Welcome, User",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    userEmail,
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                  ),
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
              onTap: handleLogout, // Call the logout function
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

              // Start/Stop Monitoring Button

              const SizedBox(height: 20),

              // Location Section
              const Text(
                "Location",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: GoogleMap(
                  initialCameraPosition: _initialCameraPosition,
                  onMapCreated: (GoogleMapController controller) {
                    _controller = controller;
                  },
                  mapType: MapType.normal,
                  myLocationEnabled: true,
                  zoomControlsEnabled: true,
                ),
              ),
              const SizedBox(height: 20),

              // Activities Section
              const Text(
                "Activities",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  activityItem("Facebook", Icons.facebook, Colors.blue),
                  activityItem("Youtube", Icons.youtube_searched_for, Colors.red),
                  activityItem("Tiktok", Icons.music_note, Colors.black),
                  activityItem("Instagram", Icons.camera_alt, Colors.purple),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget activityItem(String title, IconData icon, Color iconColor) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.2),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title),
      ),
    );
  }
}


