import 'package:child_moni/Screens/HomeScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'ChooseScreen.dart';

class Pinscreen extends StatefulWidget {
  const Pinscreen({super.key});

  @override
  State<Pinscreen> createState() => _PinscreenState();
}

class _PinscreenState extends State<Pinscreen> {
  String enteredPin = '';
  bool isPinVisible = false;

  Widget numButton(int number) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: TextButton(
        onPressed: () {
          setState(() {
            if (enteredPin.length < 4) {
              enteredPin += number.toString();
            }
          });
        },
        child: Text(
          number.toString(),
          style: const TextStyle(
            fontSize: 24,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Future<void> handleSubmit() async {
    if (enteredPin.length == 4) {
      try {
        // Get the current user's ID
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No user is logged in.')),
          );
          return;
        }

        final userId = currentUser.uid;

        print('current user: $userId');

        // Fetch the parent's document based on the userId
        final parentDoc = await FirebaseFirestore.instance
            .collection('Parent')
            .doc(userId)
            .get();

        if (parentDoc.exists) {
          final storedPin = parentDoc.data()?['pin'];
          print('Stored PIN: $storedPin'); // Debugging
          print('Entered PIN: $enteredPin'); // Debugging

          if (storedPin.toString().trim() == enteredPin.trim()) {
            // PIN is valid
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pin validated. Proceeding...')),
            );

            // Navigate to the next screen
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyFamilyScreen()),
            );
          } else {
            // PIN is invalid
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invalid PIN. Please try again.')),
            );
          }
        } else {
          // No document found for the user
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User data not found.')),
          );
        }
      } catch (e) {
        // Handle errors
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a 4-digit PIN.')),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFC0CB),
        title: const Text('Enter Your Pin'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ChooseScreen()),
            );
          },
        ),
      ),
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        physics: const BouncingScrollPhysics(),
        children: [

          const SizedBox(height: 50),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              return Container(
                margin: const EdgeInsets.all(6.0),
                width: isPinVisible ? 50 : 16,
                height: isPinVisible ? 50 : 16,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6.0),
                  color: index < enteredPin.length
                      ? isPinVisible
                      ? Colors.green
                      : Colors.blue
                      : Colors.blue.withOpacity(0.1),
                ),
                child: isPinVisible && index < enteredPin.length
                    ? Center(
                  child: Text(
                    enteredPin[index],
                    style: const TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.systemBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
                    : null,
              );
            }),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                isPinVisible = !isPinVisible;
              });
            },
            icon: Icon(
              isPinVisible ? Icons.visibility_off : Icons.visibility,
            ),
          ),
          SizedBox(height: isPinVisible ? 50.0 : 8.0),
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  3,
                      (index) => numButton(1 + 3 * i + index),
                ).toList(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(onPressed: null, child: SizedBox()),
                numButton(0),
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (enteredPin.isNotEmpty) {
                        enteredPin = enteredPin.substring(0, enteredPin.length - 1);
                      }
                    });
                  },
                  child: const Icon(
                    Icons.backspace,
                    color: Colors.black,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ElevatedButton(
              onPressed: handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Submit',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


