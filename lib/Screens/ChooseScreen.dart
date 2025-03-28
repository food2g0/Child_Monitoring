import 'package:child_moni/Screens/ChildScreen.dart';
import 'package:child_moni/Screens/PinScreen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChooseScreen extends StatefulWidget {
  const ChooseScreen({Key? key}) : super(key: key);

  @override
  _ChooseScreenState createState() => _ChooseScreenState();
}

class _ChooseScreenState extends State<ChooseScreen> {
  String? selectedRole;

  @override
  void initState() {
    super.initState();
    _loadSelectedRole();
  }

  Future<void> _loadSelectedRole() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedRole = prefs.getString('user_role');
    });
  }

  Future<void> _saveSelectedRole(String role) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
  }

  void _confirmRoleSelection(String role) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Selection"),
        content: Text("Are you sure you want to continue as a $role?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _proceedWithRole(role);
            },
            child: const Text("Continue"),
          ),
        ],
      ),
    );
  }

  void _proceedWithRole(String role) {
    _saveSelectedRole(role);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => role == 'parent' ? Pinscreen() : ChildScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 200,
              height: 100,
            ),
            const SizedBox(height: 20),
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
            const Text(
              'Choose User',
              style: TextStyle(
                fontSize: 18,
                fontFamily: 'Poppins-Bold',
                color: Color(0xFFADD8E6),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                GestureDetector(
                  onTap: () {
                    if (selectedRole == null) {
                      _confirmRoleSelection('parent'); // Allow role selection
                    } else if (selectedRole == 'parent') {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => Pinscreen()),
                      );
                    }
                  },
                  child: Opacity(
                    opacity: selectedRole == 'child' ? 0.5 : 1.0,
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
                ),



                GestureDetector(
                  onTap: () {
                    if (selectedRole == null) {
                      _confirmRoleSelection('child'); // Allow role selection
                    } else if (selectedRole == 'child') {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => ChildScreen()),
                      );
                    }
                  },
                  child: Opacity(
                    opacity: selectedRole == 'parent' ? 0.5 : 1.0,
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
