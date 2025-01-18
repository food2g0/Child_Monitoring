import 'package:child_moni/Screens/SelectedChildScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'AddChildScreen.dart';

class ChildrenScreen extends StatefulWidget {
  @override
  State<ChildrenScreen> createState() => _ChildrenScreenState();
}

class _ChildrenScreenState extends State<ChildrenScreen> {
  int _selectedIndex = 1;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Fetch children from Firestore
  Future<List<Map<String, dynamic>>> _fetchChildren() async {
    try {
      final String userId = _auth.currentUser!.uid;

      // Fetch all documents in the "Child" sub-collection
      final QuerySnapshot snapshot = await _firestore
          .collection('Parent')
          .doc(userId)
          .collection('Child')
          .orderBy('createdAt', descending: true)
          .get();

      // Include the document ID as 'id'
      return snapshot.docs.map((doc) {
        return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
      }).toList();
    } catch (e) {
      debugPrint('Error fetching children: $e');
      return [];
    }
  }

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AddChildScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFFFC0CB),
        title: const Text('Children'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchChildren(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final List<Map<String, dynamic>> children = snapshot.data ?? [];

          if (children.isEmpty) {
            return const Center(
              child: Text(
                'No children added yet.',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: children.length,
            itemBuilder: (context, index) {
              final child = children[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.lightBlue,
                    child: Icon(Icons.child_care, color: Colors.white),
                  ),
                  title: Text(
                    child['name'] ?? 'Unknown',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'Age: ${child['age'] ?? 'N/A'}',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    // Pass the document ID (child ID) to SelectedChildScreen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SelectedChildScreen(childId: child['id']),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.person_add_alt),
            label: 'Add Child',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Children',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}
