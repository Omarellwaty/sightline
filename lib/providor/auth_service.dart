import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Constructor to set persistence
  AuthService() {
    // Set persistence to LOCAL (persists across app restarts)
    _auth.setPersistence(Persistence.LOCAL);
  }

  // Get current user
  User? get currentUser => _auth.currentUser;
  
  // Check if user is signed in
  bool get isSignedIn => currentUser != null;
  
  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Hash password for storage (not for authentication)
  String _hashPassword(String password) {
    var bytes = utf8.encode(password); // Convert to bytes
    var digest = sha256.convert(bytes); // Apply SHA-256 hashing
    return digest.toString(); // Return the hash as a string
  }

  // 🔥 Sign Up (Register)
  Future<Map<String, dynamic>> signUpWithEmailAndPassword(String email, String password) async {
    try {
      // Trim whitespace from email and password
      email = email.trim();
      
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Store user information in Firestore
      if (result.user != null) {
        String passwordHash = _hashPassword(password);
        await _firestore.collection('users').doc(result.user!.uid).set({
          'email': email,
          'passwordHash': passwordHash,
          'createdAt': FieldValue.serverTimestamp(),
          'isAdmin': false, // Default to non-admin
        });
        
        print('User data stored in Firestore with hashed password');
      }
      
      return {
        'success': true,
        'user': result.user,
        'message': 'Registration successful!'
      };
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'The email address is already in use.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password accounts are not enabled.';
          break;
        case 'weak-password':
          errorMessage = 'The password is too weak.';
          break;
        default:
          errorMessage = e.message ?? 'An unknown error occurred during registration.';
      }
      
      print('Sign Up Error: $errorMessage (${e.code})');
      return {
        'success': false,
        'user': null,
        'message': errorMessage,
        'code': e.code
      };
    } catch (e) {
      print('Unknown error during sign up: $e');
      return {
        'success': false,
        'user': null,
        'message': 'An unexpected error occurred during registration.',
      };
    }
  }

  // 🚀 Sign In (Login)
  Future<Map<String, dynamic>> signInWithEmailAndPassword(String email, String password) async {
    try {
      // Trim whitespace from email and password
      email = email.trim();
      
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      return {
        'success': true,
        'user': result.user,
        'message': 'Sign in successful!'
      };
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Wrong password provided.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        case 'user-disabled':
          errorMessage = 'This user account has been disabled.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many unsuccessful login attempts. Please try again later.';
          break;
        default:
          errorMessage = e.message ?? 'An unknown error occurred during sign in.';
      }
      
      print('Sign In Error: $errorMessage (${e.code})');
      return {
        'success': false,
        'user': null,
        'message': errorMessage,
        'code': e.code
      };
    } catch (e) {
      print('Unknown error during sign in: $e');
      return {
        'success': false,
        'user': null,
        'message': 'An unexpected error occurred during sign in.',
      };
    }
  }

  // 🚪 Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }
  
  // Send password reset email
  Future<Map<String, dynamic>> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return {
        'success': true,
        'message': 'Password reset email sent!'
      };
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is not valid.';
          break;
        default:
          errorMessage = e.message ?? 'An unknown error occurred.';
      }
      
      print('Password Reset Error: $errorMessage (${e.code})');
      return {
        'success': false,
        'message': errorMessage,
        'code': e.code
      };
    } catch (e) {
      print('Unknown error during password reset: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred.',
      };
    }
  }
}
