import 'package:carrier/screens/pages/admin_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:carrier/screens/register_screen.dart';
import 'package:carrier/widgets/custom_textfield.dart';
import 'package:carrier/widgets/social_login_button.dart';
import 'package:carrier/widgets/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carrier/screens/pages/customer_dashboard.dart';
import 'package:carrier/screens/pages/driver_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordObscured = true;

  UserRole _selectedRole = UserRole.customer;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (_selectedRole == UserRole.stationAdmin) {
      if (!email.endsWith('@swiftline.ke')) {
        _showError("Only authorized @swiftline.ke emails can login as Admin.");
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final String uid = userCredential.user!.uid;

      if (!mounted) return;

      Widget destinationPage;

      if (_selectedRole == UserRole.driver) {
        DocumentSnapshot driverDoc = await FirebaseFirestore.instance
            .collection('drivers')
            .doc(uid)
            .get();

        if (!mounted) return;

        if (!driverDoc.exists) {
          await FirebaseAuth.instance.signOut();
          _showError("No driver profile found for this account.");
          return;
        }

        String status = driverDoc.get('status') ?? 'pending_verification';

        if (status == 'pending_verification') {
          await FirebaseAuth.instance.signOut();
          _showError("Account Pending: Your documents are being reviewed.");
          return;
        } else if (status == 'rejected') {
          await FirebaseAuth.instance.signOut();
          _showError("Access Denied: Your application was rejected.");
          return;
        }

        destinationPage = const DriverDashboard();
      } else if (_selectedRole == UserRole.stationAdmin) {
        destinationPage = const AdminDashboard();
      } else {
        destinationPage = const CustomerDashboard();
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => destinationPage),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(_getFriendlyErrorMessage(e.code));
    } catch (e) {
      if (mounted) _showError("An unexpected error occurred.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final TextEditingController resetController = TextEditingController();
    resetController.text = _emailController.text;

    bool _isDialogLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Reset Password"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Enter your email address to receive a reset link."),
                const SizedBox(height: 15),
                TextField(
                  controller: resetController,
                  enabled: !_isDialogLoading,
                  decoration: InputDecoration(
                    hintText: "Email",
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: _isDialogLoading ? null : () => Navigator.pop(context),
                child: const Text("Cancel", style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                onPressed: _isDialogLoading
                    ? null
                    : () async {
                        final email = resetController.text.trim();
                        if (email.isEmpty) {
                          _showError("Please enter your email.");
                          return;
                        }

                        setDialogState(() => _isDialogLoading = true);

                        try {

                          await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                          
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Reset link sent! Check your email inbox.")),
                            );
                          }
                        } catch (e) {
                          if (mounted) _showError("Error: ${e.toString()}");
                          setDialogState(() => _isDialogLoading = false);
                        }
                      },
                child: _isDialogLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
                      )
                    : const Text("Send Link"),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getFriendlyErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-credential':
        return 'Invalid login details.';
      case 'too-many-requests':
        return 'Too many attempts. Please try later.';
      default:
        return 'Login failed. Please try again.';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[800],
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  Text(
                    "Welcome Back",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const Text(
                    "Select your account type to continue.",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),

                  const SizedBox(height: 30),

                  Center(
                    child: SegmentedButton<UserRole>(
                      segments: const [
                        ButtonSegment(
                          value: UserRole.customer,
                          label: Text('Customer'),
                          icon: Icon(Icons.person_outline),
                        ),
                        ButtonSegment(
                          value: UserRole.stationAdmin,
                          label: Text('Admin'),
                          icon: Icon(Icons.admin_panel_settings_outlined),
                        ),
                        ButtonSegment(
                          value: UserRole.driver,
                          label: Text('Driver'),
                          icon: Icon(Icons.local_shipping_outlined),
                        ),
                      ],
                      selected: {_selectedRole},
                      onSelectionChanged: (Set<UserRole> newSelection) {
                        setState(() => _selectedRole = newSelection.first);
                      },
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: primaryColor,
                        selectedForegroundColor: Colors.white,
                        side: BorderSide(color: primaryColor.withValues()),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  CustomTextField(
                    hintText: "Email",
                    icon: Icons.email_outlined,
                    controller: _emailController,
                    validator: (value) =>
                        (value == null || value.isEmpty) ? 'Enter email' : null,
                  ),
                  const SizedBox(height: 20),
                  CustomTextField(
                    hintText: "Password",
                    icon: Icons.lock_outline,
                    controller: _passwordController,
                    obscureText: _isPasswordObscured,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordObscured
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setState(
                        () => _isPasswordObscured = !_isPasswordObscured,
                      ),
                    ),
                    validator: (value) => (value == null || value.isEmpty)
                        ? 'Enter password'
                        : null,
                  ),

                  const SizedBox(
                    height: 10,
                  ), // Reduced space after password field

                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _showForgotPasswordDialog,
                      child: Text(
                        "Forgot Password?",
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Login",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 40),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text("Or"),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 30),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SocialLoginButton(
                        icon: Icons.g_mobiledata,
                        label: "Google",
                      ),
                      SocialLoginButton(icon: Icons.apple, label: "Apple"),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? "),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterScreen(),
                          ),
                        ),
                        child: Text(
                          "Register",
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
