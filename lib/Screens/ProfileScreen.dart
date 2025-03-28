import 'package:child_moni/Screens/HomeScreen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../Authentication/login.dart';
import '../SetSafeZone.dart';
import 'AddChildScreen.dart';
import 'ContactUsScreen.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String name = "Loading...";
  String email = "Loading...";
  String phone = "Loading...";

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }
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
  void _fetchUserData() async {
    try {
      final User? currentUser = _auth.currentUser;

      if (currentUser == null) {
        print("No authenticated user found.");
        return;
      }

      DocumentSnapshot userDoc =
      await _firestore.collection('Parent').doc(currentUser.uid).get();

      if (!userDoc.exists) {
        print("User document does not exist.");
        return;
      }

      print("User data: ${userDoc.data()}");

      if (mounted) {
        setState(() {
          name = userDoc['name'] ?? "No name";
          email = userDoc['email'] ?? "No email";
          phone = userDoc['phone'] ?? "No phone";
        });
      }
    } catch (e) {
      print("Error fetching user data: $e");
    }
  }


  void _editField(String field, String currentValue) async {
    TextEditingController controller = TextEditingController(text: currentValue);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit $field"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: "Enter new $field",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final User? currentUser = _auth.currentUser;
              if (currentUser != null) {
                try {
                  // Update the field in Firestore
                  await _firestore
                      .collection('Parent')
                      .doc(currentUser.uid)
                      .update({field.toLowerCase(): controller.text});

                  // Update the local state
                  setState(() {
                    if (field == "Name") name = controller.text;
                    if (field == "Email") email = controller.text;
                    if (field == "Phone") phone = controller.text;
                  });

                  Navigator.pop(context);
                } catch (e) {
                  print("Error updating $field: $e");
                }
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: const Color(0xFFFFC0CB),

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
                    backgroundImage: AssetImage("assets/images/parent.webp"), // Replace with user image
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

                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text("Home"),
              onTap: () {
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (context) => MyFamilyScreen()));
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
              leading: const Icon(Icons.child_care),
              title: const Text("Child Management"),
              onTap: () {
                Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (context) => AddChildScreen()));
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey[200],
              backgroundImage: AssetImage("assets/images/parent.webp"),
            ),

            const SizedBox(height: 16),
            Text(
              name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.pink[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildInfoRow("Name", name),
                  _buildInfoRow("Email", email),
                  _buildInfoRow("Phone", phone),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                _auth.signOut();
                Navigator.pop(context); // Navigate back after logout
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlueAccent,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text("Logout"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "$label:",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              _editField(label, value);
            },
          ),
        ],
      ),
    );
  }
}
