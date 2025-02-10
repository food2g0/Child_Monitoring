import 'package:child_moni/Screens/HomeScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  Future<void> _submitReport() async {
    if (_formKey.currentState!.validate()) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("User not logged in")),
          );
          return;
        }

        await FirebaseFirestore.instance.collection('Report').add({
          'senderId': user.uid,
          'name': _nameController.text,
          'email': _emailController.text,
          'message': _messageController.text,
          'timestamp': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Report submitted successfully!")),
        );

        _nameController.clear();
        _emailController.clear();
        _messageController.clear();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>MyFamilyScreen()));
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Contact Us"),
          backgroundColor: const Color(0xFFFFC0CB),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: "Name"),
                  validator: (value) => value!.isEmpty ? "Enter your name" : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: "Email"),
                  validator: (value) => value!.isEmpty ? "Enter your email" : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _messageController,
                  decoration: const InputDecoration(labelText: "Message"),
                  maxLines: 5,
                  validator: (value) => value!.isEmpty ? "Enter your message" : null,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue, // Button color
                    foregroundColor: Colors.white, // Text color
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12), // Padding
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12), // Rounded corners
                    ),
                    elevation: 2, // Shadow effect
                  ),
                  child: const Text(
                    "Submit",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                )

              ],
            ),
          ),
        ),
      ),
    );
  }
}
