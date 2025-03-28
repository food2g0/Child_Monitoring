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

  void _onMapTapped(LatLng position) async {
    if (user == null) return;

    // Create a new safe zone with a fixed radius of 300 meters
    Circle newSafeZone = Circle(
      circleId: CircleId(position.toString()),
      center: position,
      radius: 300, // 300 meters radius
      fillColor: Colors.blue.withOpacity(0.3),
      strokeColor: Colors.blue,
      strokeWidth: 2,
    );

    setState(() {
      _safeZones.add(newSafeZone);
    });

    // Upload to Firestore with a unique document ID
    await _firestore
        .collection('Parent')
        .doc(user!.uid)
        .collection('SafeZone')
        .add({ // Use .add() to allow multiple safe zones
      'center': {
        'latitude': position.latitude,
        'longitude': position.longitude,
      },
      'radius': 100,
    });
  }

  Future<void> _fetchSafeZones() async {
    try {
      if (user == null) return;

      final QuerySnapshot safeZonesSnapshot = await _firestore
          .collection('Parent')
          .doc(user!.uid)
          .collection('SafeZone')
          .get();

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
    } catch (e) {
      debugPrint('Error fetching safe zones: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchSafeZones();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Safe Zones'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => MyFamilyScreen()),
                  (route) => false,
            ); // Navigate back to the Home Screen
          },
        ),
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(14.5995, 120.9842), // Default to Manila
          zoom: 14,
        ),
        onMapCreated: (controller) {
          _mapController = controller;
        },
        onTap: _onMapTapped,
        circles: _safeZones,
      ),
    );
  }
}
