import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      radius: 100, // 300 meters radius
      fillColor: Colors.blue.withOpacity(0.3),
      strokeColor: Colors.blue,
      strokeWidth: 2,
    );

    setState(() {
      _safeZones.add(newSafeZone);
    });

    // Upload to Firestore
    await _firestore
        .collection('Parent')
        .doc(user!.uid)
        .collection('SafeZone')
        .add({
      'center': {
        'latitude': position.latitude,
        'longitude': position.longitude,
      },
      'radius': 100,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set Safe Zones')),
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
