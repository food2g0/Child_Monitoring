import 'package:child_moni/Screens/ChildScreen.dart';
import 'package:child_moni/Screens/PinScreen.dart';
import 'package:flutter/material.dart';

class ChooseScreen extends StatelessWidget {
  const ChooseScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    void handleParentPress() {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) =>  Pinscreen()),
      );

    }

    void handleChildPress() {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>ChildScreen()));

    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Image.asset(
              'assets/images/logo.png',
              width: 200,
              height: 100,
            ),

            const SizedBox(height: 20),

            // Subtitle
            const Text(
              'Your peace of mind starts here!..',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 32,
                color: Color(0xFF333333),
              ),
            ),

            const SizedBox(height: 100),

            // Title
            const Text(
              'Choose User',
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'Poppins-Bold',
                color: Color(0xFFADD8E6),
              ),
            ),

            const SizedBox(height: 30),

            // Choices
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Parent Button with Image
                GestureDetector(
                  onTap: handleParentPress,
                  child: Column(
                    children: [
                      ClipOval(
                        child: Image.asset(
                          'assets/images/parent.webp',
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Parent',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Poppins-Medium',
                          color: Color(0xFF333333),
                        ),
                      ),
                    ],
                  ),
                ),

                // Child Button with Image
                GestureDetector(
                  onTap: handleChildPress,
                  child: Column(
                    children: [
                      ClipOval(
                        child: Image.asset(
                          'assets/images/child.png',
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Child',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Poppins-Medium',
                          color: Color(0xFF333333),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
