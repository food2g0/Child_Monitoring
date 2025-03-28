import 'package:audioplayers/audioplayers.dart';
import 'package:child_moni/Authentication/login.dart';
import 'package:child_moni/Screens/AddChildScreen.dart';
import 'package:child_moni/Screens/ContactUsScreen.dart';
import 'package:child_moni/Screens/ProfileScreen.dart';
import 'package:child_moni/Screens/SelectedChildScreen.dart';
import 'package:child_moni/SetSafeZone.dart';
import 'package:child_moni/api/firebasenotif_api.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class MyFamilyScreen extends StatefulWidget {
  const MyFamilyScreen({super.key});

  @override
  State<MyFamilyScreen> createState() => _MyFamilyScreenState();
}

class _MyFamilyScreenState extends State<MyFamilyScreen> {
  late GoogleMapController _controller;
  String userEmail = "Loading...";
  LatLng safeZoneCenter = LatLng(14.55027, 121.03269); // Replace with desired coordinates
  double safeZoneRadius = 100;
  bool _isLoading = true;
  Set<Circle> _circles = {};
  bool _hasFetchedChildren = false;
  List<Map<String, dynamic>> children = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Set<Marker> _markers = {};
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(14.55027, 121.03269),
    zoom: 12.0,
  );
  Set<Circle> _safeZones = {};
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    fetchUserEmailFromParentCollection();
    _fetchChildren();
    _fetchSafeZones();


  }

  void _fetchSafeZones() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final QuerySnapshot safeZonesSnapshot = await FirebaseFirestore.instance
          .collection('Parent')
          .doc(user.uid)
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
        _safeZones = fetchedSafeZones;  // Make sure _safeZones is declared
      });
    } catch (e) {
      debugPrint('Error fetching safe zones: $e');
    }
  }

  void _setSafeZone() {
    setState(() {
      _circles.add(
        Circle(
          circleId: CircleId("safe_zone"),
          center: safeZoneCenter,
          radius: safeZoneRadius,
          fillColor: Colors.blue.withOpacity(0.2),
          strokeColor: Colors.blue,
          strokeWidth: 2,
        ),
      );
    });
  }


  double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Radius of the Earth in meters
    double dLat = (point2.latitude - point1.latitude) * (pi / 180);
    double dLng = (point2.longitude - point1.longitude) * (pi / 180);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(point1.latitude * (pi / 180)) * cos(point2.latitude * (pi / 180)) *
            sin(dLng / 2) * sin(dLng / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  // Function to check if the child is within the safe zone
  bool isWithinSafeZone(LatLng childLocation) {
    double distance = calculateDistance(safeZoneCenter, childLocation);
    return distance <= safeZoneRadius;
  }






  Future<void> fetchUserEmailFromParentCollection() async {
    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        final DocumentSnapshot parentDoc =
        await _firestore.collection('Parent').doc(user.uid).get();
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


  //Pag get ng mga child sa Your Children section --------------------------------------------------------------
  Future<void> _fetchChildren() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final String userId = _auth.currentUser!.uid;
      final QuerySnapshot snapshot = await _firestore
          .collection('Parent')
          .doc(userId)
          .collection('Child')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        children = snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
            .toList();
      });

      _updateMarkers(); // Call the marker update after fetching children
    } catch (e) {
      debugPrint('Error fetching children: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  //GoogleMap Marker --------------------------------------------------------------

// Update the _updateMarkers method to check the safe zone
  Future<void> _updateMarkers() async {
    Set<Marker> newMarkers = {};
    BitmapDescriptor customMarker = await _getCustomMarker();

    for (var child in children) {
      if (child['location'] != null) {
        final location = child['location'];
        final LatLng position = LatLng(location['latitude'], location['longitude']);

        print('Adding marker for child: ${child['name']} at $position');

        newMarkers.add(
          Marker(
            markerId: MarkerId(child['id']),
            position: position,
            icon: customMarker,
            infoWindow: InfoWindow(title: child['name'] ?? "Unknown Child"),
          ),
        );


      }
    }

    setState(() {
      _markers = newMarkers;
    });

    if (children.isNotEmpty) {
      final firstChildLocation = children.first['location'];
      if (firstChildLocation != null) {
        _controller.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(firstChildLocation['latitude'], firstChildLocation['longitude']),
          ),
        );
      }
    }
  }
  Future<BitmapDescriptor> _getCustomMarker() async {
    return await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)), // Set appropriate size
      "assets/images/location_marker.png", // Replace with your actual image path
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAppSessions(String childId) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('Parent')
          .doc(_auth.currentUser!.uid)
          .collection('Child')
          .doc(childId)
          .collection('AppSessions')
          .get();
      debugPrint('Fetched ${snapshot.docs.length} app sessions for child: $childId');

      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

    } catch (e) {
      debugPrint('Error fetching app sessions: $e');
      return [];
    }
  }







  // Logout function
  Future<void> handleLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=> LoginScreen()));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return new WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "My Family",
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

        // Drawer for navigation --------------------------------------------------------------
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
                  Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (context) => ProfilePage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.safety_check),
                title: const Text("Safe Zone"),
                onTap: () {
                  Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (context) => SetSafeZone()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.child_care),
                title: const Text("Child Management"),
                onTap: () {
                  Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (context) => AddChildScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.contact_page),
                title: const Text("Contact Us"),
                onTap: () {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>ContactUsScreen()));
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


                const SizedBox(height: 10),

                SizedBox(
                  height: 170, // Adjust the height for the container
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      //Your  Children section --------------------------------------------------------------
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          "Your Children",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),

                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDAECF2), // Light blue background color
                            borderRadius: BorderRadius.circular(12), // Rounded corners
                          ),
                          child: _isLoading
                              ? const Center(
                            child: CircularProgressIndicator(), // Show loader while data is loading
                          )
                              : children.isEmpty
                              ? const Center(
                            child: Text(
                              "No children added yet.",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black54,
                              ),
                            ),
                          )
                              : ListView.builder(
                            scrollDirection: Axis.horizontal, // Horizontal scrolling
                            itemCount: children.length + 1, // Extra item for the "Add Child" button
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                // "Add Child" Button at the beginning
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AddChildScreen(), // Navigate to AddChildScreen
                                        ),
                                      );
                                    },
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        CircleAvatar(
                                          radius: 30,
                                          backgroundColor: Colors.blueAccent,
                                          child: const Icon(Icons.add, color: Colors.white), // Plus icon
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          "Add Child",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              } else {
                                // Child Item
                                final child = children[index - 1]; // Adjust index for children list
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: InkWell(
                                    onTap: () {
                                      final childId = child['id'];

                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SelectedChildScreen(childId: childId),
                                        ),
                                      );
                                    },
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        CircleAvatar(
                                          radius: 30,
                                          backgroundImage: AssetImage("assets/images/onboarding.jpg"), // Replace with your image
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          child['name'] ?? 'Unknown',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ),

                    ],
                  ),
                ),



                const SizedBox(height: 20),

                // Location Section----------------------------------------------------------------------------
                const Text(
                  "Child Locations",
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
                  child:GoogleMap(
                    initialCameraPosition: _initialCameraPosition,
                    onMapCreated: (GoogleMapController controller) {
                      setState(() {
                        _controller = controller;
                      });
                    },
                    markers: _markers,
                    circles: _circles,
                    mapType: MapType.normal,
                    myLocationEnabled: true,
                    zoomControlsEnabled: true,
                    zoomGesturesEnabled: true,
                    scrollGesturesEnabled: true,
                    onTap: (LatLng position) {
                      setState(() {
                        safeZoneCenter = position;
                        _circles.clear();
                        _setSafeZone();
                      });
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Activities Section


                //Report Section----------------------------------------------------------------------------
                const Text(
                  "Reports",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                children.isEmpty
                    ? const Center(child: Text("No children available."))
                    : Column(
                  children: children.map((child) {
                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: _fetchAppSessions(child['id']),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        if (snapshot.hasError) {
                          debugPrint("Error fetching app sessions: ${snapshot.error}");
                          return ListTile(
                            title: Text(child['name'] ?? 'Unknown'),
                            subtitle: const Text("Error loading app session data."),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          debugPrint("No app sessions available for ${child['name']}");
                          return ListTile(
                            title: Text(child['name'] ?? 'Unknown'),
                            subtitle: const Text("No app session data available."),
                          );
                        }

                        debugPrint("Displaying app sessions for ${child['name']}");
                        return ExpansionTile(
                          title: Text(child['name'] ?? 'Unknown'),
                          children: snapshot.data!.map((session) {
                            return ListTile(
                              title: Text(session['appName'] ?? 'Unknown App'),
                              subtitle: session['status'] == 'opened'
                                  ? null
                                  : Text("Duration: ${session['duration']} seconds"),
                              trailing: Text("${session['status'] ?? 'Unknown Status'}"),
                            );
                          }).toList(),
                        );
                      },
                    );
                  }).toList(),
                )


              ],
            ),
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
        trailing: const Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }
}