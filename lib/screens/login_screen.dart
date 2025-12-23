import 'package:flutter/material.dart';
import 'package:carrier/screens/register_screen.dart';
import 'package:carrier/widgets/custom_textfield.dart';
import 'package:carrier/widgets/social_login_button.dart';
import 'package:carrier/widgets/constants.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import your actual dashboard files here
import 'package:carrier/screens/pages/customer_dashboard.dart';
// import 'package:carrier/screens/pages/admin_dashboard.dart';
// import 'package:carrier/screens/pages/driver_dashboard.dart';

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
  
  // Track the selected role - Default is Customer
  UserRole _selectedRole = UserRole.customer;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Authenticate with Firebase
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (context.mounted) {
        // 2. Determine destination based on the Toggle selection
        Widget destinationPage;
        
        switch (_selectedRole) {
          case UserRole.customer:
            destinationPage = const CustomerDashboard(); // Replace with CustomerDashboard()
            break;
          case UserRole.stationAdmin:
            destinationPage = const Placeholder(); // Replace with AdminDashboard()
            break;
          case UserRole.driver:
            destinationPage = const Placeholder(); // Replace with DriverDashboard()
            break;
        }

        // 3. Navigate and clear navigation stack
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => destinationPage),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError(_getFriendlyErrorMessage(e.code));
    } catch (e) {
      _showError("An unexpected error occurred.");
    } finally {
      if (context.mounted) setState(() => _isLoading = false);
    }
  }

  String _getFriendlyErrorMessage(String code) {
    switch (code) {
      case 'user-not-found': return 'No user found for that email.';
      case 'wrong-password': return 'Wrong password provided.';
      case 'invalid-credential': return 'Invalid login details.';
      case 'too-many-requests': return 'Too many attempts. Please try later.';
      default: return 'Login failed. Please try again.';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
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

                  // ROLE TOGGLE SECTION
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
                        setState(() {
                          _selectedRole = newSelection.first;
                        });
                      },
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: primaryColor,
                        selectedForegroundColor: Colors.white,
                        side: BorderSide(color: primaryColor.withOpacity(0.5)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  CustomTextField(
                    hintText: "Email",
                    icon: Icons.email_outlined,
                    controller: _emailController,
                    validator: (value) => (value == null || value.isEmpty) ? 'Enter email' : null,
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
                    validator: (value) => (value == null || value.isEmpty) ? 'Enter password' : null,
                  ),

                  const SizedBox(height: 30),

                  // LOGIN BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        elevation: 0,
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text("Login", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 40),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("Or")),
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
                      const Text("Don't have an account? "),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen())),
                        child: Text("Register", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
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