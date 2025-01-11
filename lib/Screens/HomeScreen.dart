import 'package:child_moni/Authentication/login.dart';
import 'package:child_moni/Screens/AddChildScreen.dart';
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
  String userEmail = "Loading..."; // Placeholder email
  List<Map<String, dynamic>> children = []; // List to store children data

  // Initial camera position
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(14.5995, 120.9842), // Replace with desired coordinates
    zoom: 12.0,
  );

  @override
  void initState() {
    super.initState();
    fetchUserEmailFromParentCollection();
    fetchChildrenFromFirebase();
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

  // Fetch children data from Firebase
  Future<void> fetchChildrenFromFirebase() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userId = user.uid;
        final QuerySnapshot childrenSnapshot = await FirebaseFirestore.instance
            .collection('Parent')
            .doc(userId)
            .collection('Child')
            .get();

        setState(() {
          children = childrenSnapshot.docs
              .map((doc) => {
            'name': doc['name'],
            // 'image': doc['image'] ?? 'assets/images/onboarding.jpg',
          })
              .toList();
        });
        print("Children fetched successfully: $children");
      }
    } catch (e) {
      print("Error fetching children: $e");
      setState(() {
        children = [];
      });
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
    return Scaffold(
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
              // Your Children Section
              const Text(
                "Your Children",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFDAECF2),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 20.0, left: 20),
                  child: SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // Add Child Button
                        Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddChildScreen(),
                                  ),
                                );
                              },
                              child: CircleAvatar(
                                radius: 30,
                                backgroundColor: const Color(0xFFE0F7FA),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.blue,
                                  size: 30,
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              "Add Child",
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(width: 30),
                        // Dynamic Child Avatars
                        ...children.map((child) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 20),
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundImage: AssetImage("assets/images/onboarding.jpg"),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  child['name'],
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
              ),

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
        trailing: const Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }
}
