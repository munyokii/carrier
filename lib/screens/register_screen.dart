import 'package:flutter/material.dart';
import 'package:carrier/widgets/custom_textfield.dart';
import 'package:carrier/widgets/social_login_button.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carrier/screens/pages/customer_dashboard.dart'; 

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return; 
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showError("Passwords do not match");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null) {
        String uid = userCredential.user!.uid;
        
        await FirebaseFirestore.instance.collection("users").doc(uid).set({
          'fullName': _fullNameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'role': 'customer',
          'createdAt': Timestamp.now(),
        });

        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const CustomerDashboard()),
            (route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An error occurred. Please try again.';
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'This email address is already registered.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address you entered is not valid.';
          break;
        case 'weak-password':
          errorMessage = 'The password is too weak. Please use at least 6 characters.';
          break;
        default:
          errorMessage = e.message ?? 'An unknown error occurred.';
      }
      _showError(errorMessage);
    } finally {
      if (context.mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.grey[800]),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Get Started",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  Text(
                    "Create an account to send and track packages.",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  CustomTextField(
                    hintText: "Fullname",
                    icon: Icons.person_outline,
                    controller: _fullNameController,
                    validator: (value) => (value == null || value.isEmpty) ? 'Please enter your name' : null,
                  ),
                  const SizedBox(height: 20),

                  CustomTextField(
                    hintText: "Email",
                    icon: Icons.email_outlined,
                    controller: _emailController,
                    validator: (value) {
                      if (value == null || !RegExp(r'\S+@\S+\.\S+').hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // NEW: Phone Number Field
                  CustomTextField(
                    hintText: "Phone Number",
                    icon: Icons.phone_outlined,
                    controller: _phoneController,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your phone number';
                      }
                      if (value.trim().length < 10) {
                        return 'Please enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  CustomTextField(
                    hintText: "Password",
                    icon: Icons.lock_outline,
                    controller: _passwordController,
                    obscureText: _isPasswordObscured,
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordObscured ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _isPasswordObscured = !_isPasswordObscured),
                    ),
                    validator: (value) => (value == null || value.length < 6) ? 'Min 6 characters required' : null,
                  ),
                  const SizedBox(height: 20),

                  CustomTextField(
                    hintText: "Confirm Password",
                    icon: Icons.lock_outline,
                    controller: _confirmPasswordController,
                    obscureText: _isConfirmPasswordObscured,
                    suffixIcon: IconButton(
                      icon: Icon(_isConfirmPasswordObscured ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _isConfirmPasswordObscured = !_isConfirmPasswordObscured),
                    ),
                    validator: (value) => (value != _passwordController.text) ? 'Passwords do not match' : null,
                  ),
                  const SizedBox(height: 30),
                  
                  // Register Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Register", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text("Or continue with"),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 30),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SocialLoginButton(icon: Icons.g_mobiledata, label: "Google"),
                      SocialLoginButton(icon: Icons.apple, label: "Apple"),
                    ],
                  ),
                  const SizedBox(height: 40),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Got an account? "),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          "Login",
                          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}