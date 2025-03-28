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

  bool hasReadPrivacy = false;


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
  // void showTermsModal() {
  //   showDialog(
  //     context: context,
  //     builder: (_) => AlertDialog(
  //       title: Text("Terms of Service"),
  //       content: SingleChildScrollView(
  //         child: Text("Terms and Conditions content here..."),
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () {
  //             setState(() {
  //               hasReadTerms = true;
  //             });
  //             Navigator.pop(context);
  //           },
  //           child: Text("I Have Read"),
  //         ),
  //       ],
  //     ),
  //   );
  // }
  void showPrivacyModal() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Privacy Policy"),
        content: SingleChildScrollView(
          child: Text( "Privacy Policy\n\n" +
          "Effective Date: 03-29-25\n\n" +
          "MoniChild: Parental Monitoring Application (“we,” “us,” or “our”) is committed to protecting the privacy of our users (“you,” “your”). This Privacy Policy outlines how we collect, use, disclose, and protect your information when you use our mobile application, MoniChild.\n\n" +
          "Information We Collect\n\n" +
          "We collect various types of information to provide and improve our services, including:\n" +
          "- Personal Information: This includes details such as your name and age will be provided during account registration.\n" +
          "- Children’s Information: Information about your child, including their name, age, and location data (if location tracking is enabled).\n" +
          "- Usage Data: Information about how you use the app, such as screen time, app usage, and device details.\n" +
          "- Location Data: With your consent, we collect and track real-time location data of your child's device using the Google Maps API.\n\n" +
          "How We Use Your Information\n\n" +
          "We use the collected information to:\n" +
          "- Monitor and manage your child's digital activities.\n" +
          "- Provide location-based services (e.g., real-time location tracking).\n" +
          "- Improve the app’s performance and features.\n" +
          "- Send notifications and alerts related to your child’s activity.\n\n" +
          "How We Share Your Information\n\n" +
          "We do not share, sell, or rent your personal information to third parties except in the following cases:\n" +
          "- Service Providers: We may share information with third-party service providers who assist in operating the app (e.g., Firebase for authentication and messaging).\n" +
          "- Legal Requirements: If required by law, we may share your information with law enforcement or other authorities.\n\n" +
          "Security of Your Information\n\n" +
          "We take reasonable measures to protect your data from unauthorized access, use, or disclosure. However, no system is 100% secure, and we cannot guarantee the absolute security of your information.\n\n" +
          "Children’s Privacy\n\n" +
          "Our app is designed for parents to monitor children’s activities, and we take extra precautions to protect the privacy of minors. We require parental consent before collecting or tracking children’s data.\n\n" +
          "Your Rights\n\n" +
          "- Access: You have the right to access your personal information and data stored in the app.\n" +
          "- Deletion: You can request that we delete any personal data we have collected about you or your child.\n" +
          "- Opt-Out: You may opt out of location tracking or data collection at any time via the app settings.\n\n" +
          "Changes to This Policy\n\n" +
          "We may update this Privacy Policy from time to time. When we do, we will revise the 'Effective Date' at the top of this document. We encourage you to review this policy periodically.\n\n" +
          "Contact Us\n\n" +
          "If you have any questions or concerns about this Privacy Policy, please contact us at:\n" +
          "- Email: Monichild@gmail.com\n" +
              "- Phone: 0906-271-5596\n"),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                hasReadPrivacy = true;
              });
              Navigator.pop(context);
            },
            child: Text("I Have Read"),
          ),
        ],
      ),
    );
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
            "Privacy Policy\n\n" +
                "Effective Date: 03-29-25\n\n" +
                "MoniChild: Parental Monitoring Application (“we,” “us,” or “our”) is committed to protecting the privacy of our users (“you,” “your”). This Privacy Policy outlines how we collect, use, disclose, and protect your information when you use our mobile application, MoniChild.\n\n" +
                "Information We Collect\n\n" +
                "We collect various types of information to provide and improve our services, including:\n" +
                "- Personal Information: This includes details such as your name and age will be provided during account registration.\n" +
                "- Children’s Information: Information about your child, including their name, age, and location data (if location tracking is enabled).\n" +
                "- Usage Data: Information about how you use the app, such as screen time, app usage, and device details.\n" +
                "- Location Data: With your consent, we collect and track real-time location data of your child's device using the Google Maps API.\n\n" +
                "How We Use Your Information\n\n" +
                "We use the collected information to:\n" +
                "- Monitor and manage your child's digital activities.\n" +
                "- Provide location-based services (e.g., real-time location tracking).\n" +
                "- Improve the app’s performance and features.\n" +
                "- Send notifications and alerts related to your child’s activity.\n\n" +
                "How We Share Your Information\n\n" +
                "We do not share, sell, or rent your personal information to third parties except in the following cases:\n" +
                "- Service Providers: We may share information with third-party service providers who assist in operating the app (e.g., Firebase for authentication and messaging).\n" +
                "- Legal Requirements: If required by law, we may share your information with law enforcement or other authorities.\n\n" +
                "Security of Your Information\n\n" +
                "We take reasonable measures to protect your data from unauthorized access, use, or disclosure. However, no system is 100% secure, and we cannot guarantee the absolute security of your information.\n\n" +
                "Children’s Privacy\n\n" +
                "Our app is designed for parents to monitor children’s activities, and we take extra precautions to protect the privacy of minors. We require parental consent before collecting or tracking children’s data.\n\n" +
                "Your Rights\n\n" +
                "- Access: You have the right to access your personal information and data stored in the app.\n" +
                "- Deletion: You can request that we delete any personal data we have collected about you or your child.\n" +
                "- Opt-Out: You may opt out of location tracking or data collection at any time via the app settings.\n\n" +
                "Changes to This Policy\n\n" +
                "We may update this Privacy Policy from time to time. When we do, we will revise the 'Effective Date' at the top of this document. We encourage you to review this policy periodically.\n\n" +
                "Contact Us\n\n" +
                "If you have any questions or concerns about this Privacy Policy, please contact us at:\n" +
                "- Email: Monichild@gmail.com\n" +
                "- Phone: 0906-271-5596\n",
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
            if (!hasReadTerms) {
              showTermsModal();
            } else if (!hasReadPrivacy) {
              showPrivacyModal();
            } else {
              setState(() {
                isTermsChecked = value ?? false;
              });
            }
          },
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (!hasReadTerms) {
                showTermsModal();
              } else {
                showPrivacyModal();
              }
            },
            child: Text(
              "I agree to the Terms and Privacy Policy",
              style: TextStyle(decoration: TextDecoration.underline),
            ),
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
