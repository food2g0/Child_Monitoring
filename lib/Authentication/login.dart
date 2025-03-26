import 'package:child_moni/Authentication/signup.dart';
import 'package:child_moni/Screens/ChooseScreen.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _showPassword = false;
  String _errorMessage = "";
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Validate email
  bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailRegex.hasMatch(email);
  }

  // Handle login
  void handleLogin(BuildContext context) async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    setState(() {
      _errorMessage = "";
    });

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = "Please fill in both email and password.";
      });
      return;
    }

    if (!isValidEmail(email)) {
      setState(() {
        _errorMessage = "Please enter a valid email address.";
      });
      return;
    }

    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ChooseScreen()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found') {
          _errorMessage = "No user found for that email.";
        } else if (e.code == 'wrong-password') {
          _errorMessage = "Incorrect password.";
        } else {
          _errorMessage = "An error occurred: ${e.message}";
        }
      });
    }
  }

  // Handle password reset
  void handleForgotPassword() async {
    String email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _errorMessage = "Please enter your email to reset your password.";
      });
      return;
    }

    if (!isValidEmail(email)) {
      setState(() {
        _errorMessage = "Please enter a valid email address.";
      });
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Password Reset"),
          content: Text("A password reset link has been sent to your email."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK"),
            ),
          ],
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = "Error: ${e.message}";
      });
    }
  }

  // Handle sign-up navigation
  void handleSignupPress() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => SignupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 50),
              Image.asset(
                'assets/images/logo.png',
                height: 100,
                width: 100,
              ),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Welcome To',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w500, color: Color(0xFF003741)),
                ),
              ),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Child Moni!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Color(0xFFFF9ED1)),
                ),
              ),

              SizedBox(height: 40),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Color(0xFFFFC0CB)),
                ),
                child: TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    prefixIcon: Icon(FontAwesomeIcons.envelope, color: Color(0xFF007BFF), size: 18),
                    hintText: 'Email',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(15),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ),

              SizedBox(height: 15),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Color(0xFFFFC0CB)),
                ),
                child: TextField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    prefixIcon: Icon(FontAwesomeIcons.lock, color: Color(0xFF007BFF)),
                    hintText: 'Password',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(15),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword ? FontAwesomeIcons.eyeSlash : FontAwesomeIcons.eye,
                        color: Color(0xFF007BFF),
                      ),
                      onPressed: () {
                        setState(() {
                          _showPassword = !_showPassword;
                        });
                      },
                    ),
                  ),
                ),
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: handleForgotPassword,
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(fontSize: 14, color: Color(0xFF007BFF)),
                  ),
                ),
              ),

              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ),

              SizedBox(height: 20),
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: () => handleLogin(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFADD8E6),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    'Login',
                    style: TextStyle(fontSize: 16, color: Color(0xFF2B2D42)),
                  ),
                ),
              ),

              SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    "Don't have an account?",
                    style: TextStyle(fontSize: 14, color: Color(0xFF2B2D42)),
                  ),
                  TextButton(
                    onPressed: handleSignupPress,
                    child: Text(
                      'Sign-Up',
                      style: TextStyle(fontSize: 14, color: Color(0xFF007BFF)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
