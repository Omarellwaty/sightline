import 'package:flutter/material.dart';
import '../data/data_model/user_data.dart';
import '../main.dart';
import 'registration_screen.dart';
import 'forget_password_screen.dart';
import '../providor/auth_service.dart'; // Don't forget to import AuthService
import 'package:firebase_auth/firebase_auth.dart'; // For FirebaseAuthException
import '../services/database_service.dart'; // For DatabaseService

class SignInScreen extends StatefulWidget {
  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailOrUsernameController = TextEditingController();
  final _passwordController = TextEditingController();

  void _submitSignIn() async {
    print('Submitting sign-in...');

    if (_formKey.currentState!.validate()) {
      final email = _emailOrUsernameController.text.trim();
      final password = _passwordController.text.trim();

      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Center(
              child: CircularProgressIndicator(),
            );
          },
        );
        
        final result = await AuthService().signInWithEmailAndPassword(email, password);
        
        // Hide loading indicator
        Navigator.of(context).pop();

        if (result['success']) {
          final user = result['user'] as User;
          
          // Load user data from Firestore
          final databaseService = DatabaseService();
          final userId = user.uid; // Use the actual user ID from Firebase Auth
          
          // Get user files
          final files = await databaseService.getUserFiles(userId);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Signed in as: ${user.email}')),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MainScreen(
              userData: UserData(
                email: user.email ?? '',
                password: '',
              ),
              initialRecentFiles: files,
            )),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'])),
          );
        }
      } catch (e) {
        // Hide loading indicator if still showing
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        
        print('Unexpected sign-in error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred.')),
        );
      }
    } else {
      print('Sign-in form validation failed');
    }
  }

  void _navigateToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RegistrationScreen()),
    );
  }

  void _navigateToForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ForgotPasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login here'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.2),
                        spreadRadius: 3,
                        blurRadius: 7,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(15),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(height: 25),
                Text(
                  'Welcome back you\'ve been missed!',
                  style: TextStyle(fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 30),
                Container(
                  padding: EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Color(0xFFADD8E6)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailOrUsernameController,
                        decoration: InputDecoration(
                            labelText: 'Email', border: InputBorder.none),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter email';
                          }
                          return null;
                        },
                      ),
                      Divider(color: Color(0xFFADD8E6)),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                            labelText: 'Password', border: InputBorder.none),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _navigateToForgotPassword,
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(fontSize: 16, color: Color(0xFF1E90FF)),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _submitSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF1E90FF),
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Sign In',
                      style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
                SizedBox(height: 15),
                TextButton(
                  onPressed: _navigateToRegister,
                  child: Text(
                    'Create new account',
                    style: TextStyle(fontSize: 16, color: Color(0xFF1E90FF)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
