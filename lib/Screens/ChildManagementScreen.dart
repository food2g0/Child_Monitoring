import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'AddChildScreen.dart';
import 'HomeScreen.dart';
import 'SelectedChildScreen.dart';

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

  // Recursively delete a document and its sub-collections
  Future<void> _deleteDocumentWithSubCollections(DocumentReference docRef) async {
    final subCollections = await docRef.collection('subCollectionName').get();
    for (final subCollectionDoc in subCollections.docs) {
      await _deleteDocumentWithSubCollections(subCollectionDoc.reference);
    }
    await docRef.delete();
  }

  // Delete child from Firestore
  Future<void> _deleteChild(String childId) async {
    try {
      final String userId = _auth.currentUser!.uid;
      final DocumentReference childDocRef = _firestore
          .collection('Parent')
          .doc(userId)
          .collection('Child')
          .doc(childId);
      await _deleteDocumentWithSubCollections(childDocRef);
      setState(() {});
    } catch (e) {
      debugPrint('Error deleting child: $e');
    }
  }

  // Show delete confirmation dialog
  void _showDeleteConfirmationDialog(BuildContext context, String childId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete Child'),
          content: Text('Are you sure you want to delete this child?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteChild(childId);
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // Show edit modal
  void _showEditModal(BuildContext context, Map<String, dynamic> child) {
    final TextEditingController nameController = TextEditingController(text: child['name']);
    final TextEditingController ageController = TextEditingController(text: child['age'].toString());
    final TextEditingController pinController = TextEditingController(text: child['pin'].toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Child'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Name'),
              ),
              SizedBox(height: 10,),
              TextField(
                controller: ageController,
                decoration: InputDecoration(labelText: 'Age'),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 10,),
              TextField(
                controller: pinController,
                decoration: InputDecoration(labelText: 'PIN'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final String userId = _auth.currentUser!.uid;
                await _firestore
                    .collection('Parent')
                    .doc(userId)
                    .collection('Child')
                    .doc(child['id'])
                    .update({
                  'name': nameController.text,
                  'age': int.parse(ageController.text),
                  'pin': int.parse(pinController.text),
                });
                Navigator.of(context).pop();
                setState(() {});
              },
              child: Text('Save'),
            ),
          ],
        );
      },
    );
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
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (c)=> MyFamilyScreen()));
        return false;
      },
      child: Scaffold(
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showEditModal(context, child),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _showDeleteConfirmationDialog(context, child['id']),
                        ),
                      ],
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
      ),
    );
  }
}