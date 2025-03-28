import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:child_moni/Screens/HomeScreen.dart'; // Import your home screen

class SetSafeZone extends StatefulWidget {
  const SetSafeZone({super.key});

  @override
  State<SetSafeZone> createState() => _SetSafeZoneState();
}

class _SetSafeZoneState extends State<SetSafeZone> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? user = FirebaseAuth.instance.currentUser;
  GoogleMapController? _mapController;
  Set<Circle> _safeZones = {};
  Set<Marker> _childLocations = {}; // Stores child location markers

  @override
  void initState() {
    super.initState();
    _fetchSafeZones();
    _fetchChildLocations();
  }

  // 🔹 Function to add a safe zone on map tap
  void _onMapTapped(LatLng position) async {
    if (user == null) return;

    Circle newSafeZone = Circle(
      circleId: CircleId(position.toString()),
      center: position,
      radius: 100, // 300 meters radius
      fillColor: Colors.blue.withOpacity(0.3),
      strokeColor: Colors.blue,
      strokeWidth: 2,
    );

    setState(() {
      _safeZones.add(newSafeZone);
    });

    // Upload safe zone to Firestore
    await _firestore
        .collection('Parent')
        .doc(user!.uid)
        .collection('SafeZone')
        .add({
      'center': {
        'latitude': position.latitude,
        'longitude': position.longitude,
      },
      'radius': 100, // Ensure this matches the displayed safe zone
    });
  }

  // 🔹 Fetch safe zones from Firestore
  void _fetchSafeZones() {
    if (user == null) return;

    _firestore
        .collection('Parent')
        .doc(user!.uid)
        .collection('SafeZone')
        .snapshots()
        .listen((safeZonesSnapshot) {
      Set<Circle> fetchedSafeZones = {};
      for (var doc in safeZonesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        fetchedSafeZones.add(Circle(
          circleId: CircleId(doc.id),
          center: LatLng(data['center']['latitude'], data['center']['longitude']),
          radius: data['radius'].toDouble(),
          fillColor: Colors.blue.withOpacity(0.3),
          strokeColor: Colors.blue,
          strokeWidth: 2,
        ));
      }

      setState(() {
        _safeZones = fetchedSafeZones;
      });
    });
  }


  // 🔹 Fetch child locations and check if they are inside safe zones
  // 🔹 Function to check if a child's location is within ANY safe zone
  bool isWithinSafeZone(LatLng childLocation) {
    for (Circle safeZone in _safeZones) {
      double distance = calculateDistance(
        childLocation.latitude, childLocation.longitude,
        safeZone.center.latitude, safeZone.center.longitude,
      );

      if (distance <= safeZone.radius) {
        return true; // If child is inside any safe zone, return true
      }
    }
    return false; // If no safe zones contain the child, return false
  }

// 🔹 Fetch child locations and check if they are outside all safe zones
  void _fetchChildLocations() {
    if (user == null) return;

    _firestore
        .collection('Parent')
        .doc(user!.uid)
        .collection('Child')
        .snapshots()
        .listen((childrenSnapshot) {
      Set<Marker> fetchedChildMarkers = {};
      bool childOutsideAllSafeZones = false; // Track if any child is outside all safe zones

      for (var childDoc in childrenSnapshot.docs) {
        final data = childDoc.data() as Map<String, dynamic>;
        if (data.containsKey('location')) {
          LatLng childLocation;

          if (data['location'] is List && data['location'].isNotEmpty) {
            final lastLocation = data['location'].last;
            childLocation = LatLng(lastLocation['latitude'], lastLocation['longitude']);
          } else if (data['location'] is Map) {
            final location = data['location'];
            childLocation = LatLng(location['latitude'], location['longitude']);
          } else {
            continue;
          }
          String childName = data.containsKey('name') ? data['name'] : 'Unknown Child';
          fetchedChildMarkers.add(Marker(
            markerId: MarkerId(childDoc.id),
            position: childLocation,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(title: childName), // Show child's name
          ));

          // 🚨 Check if the child is outside all safe zones
          if (!isWithinSafeZone(childLocation)) {
            childOutsideAllSafeZones = true;
          }
        }
      }

      setState(() {
        _childLocations = fetchedChildMarkers;
      });

      // 🚨 Trigger alert only if at least one child is outside ALL safe zones
      if (childOutsideAllSafeZones) {
        _showAlert(context, "ALERT", "Your child is outside all safe zones!");
      }
    });
  }



  // 🔹 Calculate distance between two coordinates (Haversine formula)
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371000; // Radius of Earth in meters
    double dLat = (lat2 - lat1) * pi / 180;
    double dLon = (lon2 - lon1) * pi / 180;

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
            sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c; // Distance in meters
  }

  // 🔹 Show an alert dialog
  void _showAlert(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text("OK"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
  void _clearSafeZones() async {
    if (user == null) return;

    // Delete all safe zones from Firestore
    QuerySnapshot snapshot = await _firestore
        .collection('Parent')
        .doc(user!.uid)
        .collection('SafeZone')
        .get();

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }

    // Clear safe zones in UI
    setState(() {
      _safeZones.clear();
    });

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All safe zones cleared!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Safe Zones'),
        backgroundColor: const Color(0xFFFFC0CB),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => MyFamilyScreen()),
            );
          },
        ),
      ),

      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(13.0459, 121.4645), // Default to Manila
          zoom: 14,
        ),
        onMapCreated: (controller) {
          _mapController = controller;
        },

        onTap: _onMapTapped,
        circles: _safeZones,
        markers: _childLocations,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _clearSafeZones,
        backgroundColor: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
    );
  }
}
