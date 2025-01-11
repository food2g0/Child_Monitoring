import 'package:child_moni/Screens/ChildPin.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChildScreen extends StatefulWidget {
  const ChildScreen({super.key});

  @override
  State<ChildScreen> createState() => _ChildScreenState();
}

class _ChildScreenState extends State<ChildScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Fetch children from Firestore
  Future<List<Map<String, dynamic>>> _fetchChildren() async {
    try {
      // Get the current parent's user ID
      final String userId = _auth.currentUser!.uid;

      // Fetch all children from the "Child" sub-collection
      final QuerySnapshot snapshot = await _firestore
          .collection('Parent')
          .doc(userId)
          .collection('Child')
          .orderBy('createdAt', descending: true) // Optional: Order by creation time
          .get();

      // Map documents to a list of child data, including document ID
      return snapshot.docs
          .map((doc) {
        // Print the document ID here
        print('Child Document ID: ${doc.id}'); // Print the doc ID
        return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
      })
          .toList();
    } catch (e) {
      debugPrint('Error fetching children: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFC0CB),
        title: const Text('My Children'),
        centerTitle: true,
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
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Age: ${child['age'] ?? 'N/A'}'),
                  onTap: () {
                    // Print the document ID when the child is tapped
                    print('Tapped on Child with Document ID: ${child['id']}'); // Print doc ID

                    // Pass the document ID (child['id']) to the ChildDetailScreen
                    // Inside your ChildScreen widget
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChildPinScreen(childDocId: child['id']),
                      ),
                    );

                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ChildDetailScreen extends StatelessWidget {
  final Map<String, dynamic> child;
  final String docId;

  const ChildDetailScreen({super.key, required this.child, required this.docId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFC0CB),
        title: Text(child['name'] ?? 'Child Details'),
        centerTitle: true,
      ),
      body: Center(
        child: Text(
          'Details for ${child['name'] ?? 'Unknown'} (Age: ${child['age'] ?? 'N/A'})\nDocument ID: $docId',
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
