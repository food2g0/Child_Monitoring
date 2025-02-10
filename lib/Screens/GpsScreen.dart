import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Gpsscreen extends StatefulWidget {
  final String childId;

  const Gpsscreen({Key? key, required this.childId}) : super(key: key);

  @override
  State<Gpsscreen> createState() => _GpsscreenState();
}

class _GpsscreenState extends State<Gpsscreen> {
  LatLng? _childLocation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchChildLocation();
  }

  Future<void> _fetchChildLocation() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid;

      if (userId == null) return;

      final DocumentSnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore.instance
          .collection('Parent')
          .doc(userId)
          .collection('Child')
          .doc(widget.childId)
          .get();

      final data = snapshot.data();
      if (data != null && data['location'] != null) {
        final location = data['location']; // Fetch nested location field
        setState(() {
          _childLocation = LatLng(location['latitude'], location['longitude']);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching child location: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Child Location'),
          backgroundColor: const Color(0xFFFFC0CB)
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _childLocation == null
          ? const Center(child: Text('Location data not available'))
          : GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _childLocation!,
          zoom: 15,
        ),
        markers: {
          Marker(
            markerId: const MarkerId('childLocation'),
            position: _childLocation!,
            infoWindow: const InfoWindow(title: 'Child\'s Location'),
          ),
        },
      ),
    );
  }
}
