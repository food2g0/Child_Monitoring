import 'package:child_moni/Authentication/login.dart';
import 'package:child_moni/Screens/AddChildScreen.dart';
import 'package:child_moni/Screens/ContactUsScreen.dart';
import 'package:child_moni/Screens/SelectedChildScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyFamilyScreen extends StatefulWidget {
  const MyFamilyScreen({super.key});

  @override
  State<MyFamilyScreen> createState() => _MyFamilyScreenState();
}

class _MyFamilyScreenState extends State<MyFamilyScreen> {
  late GoogleMapController _controller;
  String userEmail = "Loading...";
  List<Map<String, dynamic>> children = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Set<Marker> _markers = {}; // Store child location markers
  // Initial camera position
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(14.5995, 120.9842), // Replace with desired coordinates
    zoom: 12.0,
  );

  @override
  void initState() {
    super.initState();
    fetchUserEmailFromParentCollection();
    _fetchChildren();
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

  Future<void> _fetchChildren() async {
    try {
      final String userId = _auth.currentUser!.uid;

      // Fetch all documents in the "Child" sub-collection
      final QuerySnapshot snapshot = await _firestore
          .collection('Parent')
          .doc(userId)
          .collection('Child')
          .orderBy('createdAt', descending: true)
          .get();
      print('Fetched children: ${snapshot.docs.map((doc) => doc.data())}');

      // Map data and update the state
      setState(() {
        children = snapshot.docs.map((doc) {
          return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
        }).toList();
      });
      _updateMarkers();
    } catch (e) {
      debugPrint('Error fetching children: $e');
    }
  }

  Future<void> _updateMarkers() async {
    Set<Marker> newMarkers = {};
    BitmapDescriptor customMarker = await _getCustomMarker();

    for (var child in children) {
      if (child['location'] != null) {
        final location = child['location'];
        final LatLng position = LatLng(location['latitude'], location['longitude']);

        newMarkers.add(
          Marker(
            markerId: MarkerId(child['id']),
            position: position,
            icon: customMarker,  // Use custom marker here
            infoWindow: InfoWindow(title: child['name'] ?? "Unknown Child"),
          ),
        );
      }
    }

    setState(() {
      _markers = newMarkers;
    });
    // Move camera to first child's location
    if (children.isNotEmpty && _controller != null) {
      final firstChildLocation = children.first['location'];
      if (firstChildLocation != null) {
        _controller!.animateCamera(
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
                      // Title Section
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

                      // Container with background color DAECF2
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDAECF2), // Light blue background color
                            borderRadius: BorderRadius.circular(12), // Rounded corners
                          ),
                          child: children.isEmpty
                              ? const Center(
                            child: CircularProgressIndicator(), // Show a loader while data is loading
                          )
                              :  ListView.builder(
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
                                          builder: (context) =>
                                              SelectedChildScreen(childId: childId),
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

                // Location Section
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
                  child: GoogleMap(
                    initialCameraPosition: _initialCameraPosition,
                    onMapCreated: (GoogleMapController controller) {
                      setState(() {
                        _controller = controller;
                      });
                    },
                    markers: _markers,
                    mapType: MapType.normal,
                    myLocationEnabled: true,
                    zoomControlsEnabled: true,
                    zoomGesturesEnabled: true, // Allows zooming
                    scrollGesturesEnabled: true, // Allows moving
                  ),
                ),

                const SizedBox(height: 20),

                // Activities Section
                const Text(
                  "Reports",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                children.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    :
                Column(
                  children: children.map((child) {
                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: _fetchAppSessions(child['id']),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return ListTile(
                            title: Text(child['name'] ?? 'Unknown'),
                            subtitle: const Text("No app session data available"),
                          );
                        }
                        return ExpansionTile(
                          title: Text(child['name'] ?? 'Unknown'),
                          children: snapshot.data!.map((session) {
                            return ListTile(
                              title: Text(session['packageName'] ?? 'Unknown App'),
                              subtitle: Text("Duration: ${session['duration']} seconds"),
                              trailing: Text("${session['status'] ?? 'Unknown Status'}"),
                            );
                          }).toList(),
                        );
                      },
                    );
                  }).toList(),
                ),
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