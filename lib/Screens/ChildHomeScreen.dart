import 'dart:async';
import 'dart:io';
import 'package:child_moni/AppBlocker.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

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
  static const Otherplatform = MethodChannel('com.example.app/childId');
  Map<String, int> previousUsageTime = {};
  int currentPage = 0; // To keep track of the current page
  int appsPerPage = 5; // Number of apps per page
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Position? _currentPosition;
  BitmapDescriptor? _customMarker;

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
    listenToAppStatusUpdates();
    checkAndRequestOverlayPermission();
    startAppBlockerService();
    _setChildHomeScreenStatus(true);
    saveCurrentChildId(widget.childDocId);
    sendCurrentChildIdToKotlin(widget.childDocId);
    _getCurrentLocation();
    // _loadCustomMarker();

  }
  Future<BitmapDescriptor> _getCustomMarker(double zoom) async {
    double scale = zoom / 15.0; // Adjust the scale factor as needed
    int newSize = (30 * scale).clamp(10, 100).toInt(); // Clamp between 10px and 100px

    return await BitmapDescriptor.fromAssetImage(
      ImageConfiguration(size: Size(newSize.toDouble(), newSize.toDouble())),
      "assets/images/location_marker.png",
    );
  }

  void _onCameraMove(CameraPosition position) async {
    BitmapDescriptor marker = await _getCustomMarker(position.zoom);
    setState(() {
      _customMarker = marker;
    });
  }

  // void _loadCustomMarker() async {
  //   _customMarker = await _getCustomMarker();
  //   setState(() {});
  // }

  // void _onCameraMove(CameraPosition position) {
  //   _updateMarkerSize(position.zoom);
  // }




  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("Location services are disabled.");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print("Location permissions are denied.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print("Location permissions are permanently denied.");
      return;
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentPosition = position;
      _controller.animateCamera(CameraUpdate.newLatLng(
        LatLng(position.latitude, position.longitude),
      ));
    });
    _uploadLocationToFirestore(position);
  }

  Future<void> _uploadLocationToFirestore(Position position) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userId = user.uid;
      await _firestore
          .collection('Parent')
          .doc(userId)
          .collection('Child')
          .doc(widget.childDocId)
          .update({
        'location': {'latitude': position.latitude, 'longitude': position.longitude},
        'timestamp': Timestamp.now(),
      });
      print("Location updated in Firestore.");
    }
  }


  Future<void> sendCurrentChildIdToKotlin(String childDocId) async {
    try {
      await Otherplatform.invokeMethod('sendCurrentChildId', {'childDocId': childDocId});
    } on PlatformException catch (e) {
      print("Failed to send childId to Kotlin: ${e.message}");
    }
  }

  Future<void> startAppBlockerService() async {
    try {
      await platform.invokeMethod('startAppBlockerService');
      print("AppBlockerService started.");
    } catch (e) {
      print("Error starting AppBlockerService: $e");
    }
  }

  Future<void> saveCurrentChildId(String childDocId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentChildId', childDocId);
    print("Saved currentChildId: $childDocId");
  }



  void goToNextPage() {
    setState(() {
      if (currentPage < (installedApps.length / appsPerPage).floor()) {
        currentPage++;
      }
    });
  }
  Future<void> checkAndRequestOverlayPermission() async {
    if (Platform.isAndroid) {
      const platform = MethodChannel('com.example.app/overlay');

      try {
        final bool hasPermission = await platform.invokeMethod('checkOverlayPermission');
        if (!hasPermission) {
          await platform.invokeMethod('requestOverlayPermission');
          Fluttertoast.showToast(
            msg: "Overlay permission requested. Please enable it in settings.",
            toastLength: Toast.LENGTH_LONG,
          );
        } else {
          Fluttertoast.showToast(msg: "Overlay permission already granted.");
        }
      } catch (e) {
        print("Error requesting overlay permission: $e");
      }
    } else {
      Fluttertoast.showToast(msg: "Overlay permission not required for this platform.");
    }
  }



  void goToPreviousPage() {
    setState(() {
      if (currentPage > 0) {
        currentPage--;
      }
    });
  }
  void listenToAppStatusUpdates() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userId = user.uid;
      final appsCollection = FirebaseFirestore.instance
          .collection('Parent')
          .doc(userId)
          .collection('Child')
          .doc(widget.childDocId)
          .collection('InstalledApps');

      appsCollection.snapshots().listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.modified) {
            final appData = change.doc.data();
            if (appData != null && appData['isBlocked'] == true) {
              final String? foregroundApp = currentAppPackage;
              if (foregroundApp == appData['packageName']) {
                blockApp(foregroundApp!);
              }
            }
          }
        }
      });
    }
  }

  void blockApp(String packageName) {
    platform.invokeMethod('closeApp', {'packageName': packageName});
    print("Blocked app closed: $packageName");
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
      final isGranted = await platform.invokeMethod('requestUsageAccess');
      if (!isGranted) {
        print("Usage access permission denied.");
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


  // Method to communicate with Android through MethodChannel
  Future<void> _setChildHomeScreenStatus(bool isInChildHomeScreen) async {
    try {
      await platform.invokeMethod('setChildHomeScreenStatus', {'isChildHomeScreen': isInChildHomeScreen});
    } on PlatformException catch (e) {
      print("Failed to set ChildHomeScreen status: '${e.message}'.");
    }
  }




  @override
  void dispose() {
    _setChildHomeScreenStatus(false);
    super.dispose();
    if (isMonitoring) {
      timer.cancel();
    }
    stopAppBlockerService(); // Stop service when screen is closed
  }
  Future<void> stopAppBlockerService() async {
    try {
      await platform.invokeMethod('stopAppBlockerService');
      print("AppBlockerService stopped.");
    } catch (e) {
      print("Error stopping AppBlockerService: $e");
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
    AppBlocker.startAppBlockerService();
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

              const Text("Location", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                height: 200,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                child: GoogleMap(
                  onCameraMove: _onCameraMove,
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition != null
                        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                        : LatLng(14.5995, 120.9842),
                    zoom: 12.0,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    _controller = controller;
                  },
                  markers: _currentPosition != null
                      ? {
                    Marker(
                      markerId: MarkerId("currentLocation"),
                      position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      icon: _customMarker ?? BitmapDescriptor.defaultMarker,
                      infoWindow: InfoWindow(title: "Your Location"),
                    )
                  }
                      : {},
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
