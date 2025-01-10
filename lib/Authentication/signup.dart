import 'package:child_moni/Authentication/login.dart';
import 'package:child_moni/Screens/ChooseScreen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController pinController = TextEditingController();

  bool isTermsChecked = false;
  bool showPassword = false;
  bool isLoading = false;
  bool hasReadTerms = false;
  String emailError = '';
  String phoneError = '';
  String passwordError = '';
  String confirmPasswordError = '';
  String pinError = '';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
  }

  Future<void> _initializeFirebase() async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint("Error initializing Firebase: $e");
    }
  }

  String? validateEmail(String email) {
    if (email.isEmpty) return "Email is required.";
    if (!RegExp(r"^[^\s@]+@[^\s@]+\.[^\s@]+$").hasMatch(email)) return "Invalid email address.";
    return null;
  }

  String? validatePhone(String phone) {
    if (phone.isEmpty) return "Phone number is required.";
    if (phone.length < 11) return "Phone number must have at least 11 digits.";
    return null;
  }

  String? validatePassword(String password) {
    if (password.isEmpty) return "Password is required.";
    if (password.length < 6) return "Password must be at least 6 characters.";
    return null;
  }

  String? validateConfirmPassword(String confirmPassword) {
    if (confirmPassword.isEmpty) return "Please confirm your password.";
    if (confirmPassword != passwordController.text) return "Passwords do not match.";
    return null;
  }

  String? validatePin(String pin) {
    if (pin.isEmpty || pin.length != 4) return "PIN must be 4 digits.";
    return null;
  }

  Future<void> handleSignup() async {
    setState(() {
      isLoading = true;
    });

    String email = emailController.text.trim();
    String phone = phoneController.text.trim();
    String password = passwordController.text;
    String confirmPassword = confirmPasswordController.text;
    String pin = pinController.text;

    setState(() {
      emailError = validateEmail(email) ?? '';
      phoneError = validatePhone(phone) ?? '';
      passwordError = validatePassword(password) ?? '';
      confirmPasswordError = validateConfirmPassword(confirmPassword) ?? '';
      pinError = validatePin(pin) ?? '';
    });

    if (emailError.isEmpty && phoneError.isEmpty && passwordError.isEmpty && confirmPasswordError.isEmpty && pinError.isEmpty) {
      try {
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        await _firestore.collection('Parent').doc(userCredential.user!.uid).set({
          'email': email,
          'phone': phone,
          'pin': pin,
          'createdAt': Timestamp.now(),
        });

       Navigator.pushReplacement(context, MaterialPageRoute(builder: (c)=>ChooseScreen()));
      } on FirebaseAuthException catch (e) {
        _showErrorDialog(e.message ?? "An unknown error occurred.");
      } catch (e) {
        _showErrorDialog("An error occurred: $e");
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK"),
          ),
        ],
      ),
    );
  }

  void showTermsModal() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Terms and Privacy Policy"),
        content: SingleChildScrollView(
          child: Text(
            "Terms and Conditions content here...",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                hasReadTerms = true;
              });
              Navigator.pop(context);
            },
            child: Text("I Have Read"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Create Account")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: [
            buildInputField("Email", emailController, emailError),
            SizedBox(height: 10),
            buildInputField("Phone Number", phoneController, phoneError, keyboardType: TextInputType.phone),
            SizedBox(height: 10),
            buildPasswordField("Password", passwordController, passwordError),
            SizedBox(height: 10),
            buildPasswordField("Confirm Password", confirmPasswordController, confirmPasswordError),
            SizedBox(height: 10),
            buildInputField("Enter 4-digit PIN", pinController, pinError, keyboardType: TextInputType.number, isPin: true),
            SizedBox(height: 20),
            buildTermsCheckbox(),
            SizedBox(height: 20),
            buildSignUpButton(),
            SizedBox(height: 20),
            buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget buildInputField(String label, TextEditingController controller, String error, {TextInputType keyboardType = TextInputType.text, bool isPin = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            errorText: error.isEmpty ? null : error,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Color(int.parse('0xFFFF9ED1')), // Default border color
                width: 2.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Color(int.parse('0xFFFF9ED1')), width: 2.0), // Focused border color
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.red), // Error border color
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.red, width: 2.0), // Focused error border color
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          ),
          keyboardType: keyboardType,
          inputFormatters: isPin ? [LengthLimitingTextInputFormatter(4)] : [],
        ),
      ],
    );
  }

  Widget buildPasswordField(String label, TextEditingController controller, String error) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          obscureText: !showPassword,
          decoration: InputDecoration(
            labelText: label,
            errorText: error.isEmpty ? null : error,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Color(int.parse('0xFFFF9ED1')), // Default border color
                width: 2.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: Color(int.parse('0xFFFF9ED1')), // Focused border color
                width: 2.0,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.red), // Error border color
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.red, width: 2.0), // Focused error border color
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget buildTermsCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: isTermsChecked,
          onChanged: (bool? value) {
            if (hasReadTerms) {
              setState(() {
                isTermsChecked = value ?? false;
              });
            } else {
              showTermsModal();
            }
          },
        ),
        Expanded(
          child: GestureDetector(
            onTap: showTermsModal,
            child: Text("I agree to the Terms and Privacy Policy", style: TextStyle(decoration: TextDecoration.underline)),
          ),
        ),
      ],
    );
  }

  Widget buildSignUpButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        padding: EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onPressed: isLoading || !isTermsChecked ? null : handleSignup,
      child: isLoading ? CircularProgressIndicator(color: Colors.white) : Text("Sign Up"),
    );
  }

  Widget buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Already have an account?"),
        TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen())),
          child: Text("Login"),
        ),
      ],
    );
  }
}
