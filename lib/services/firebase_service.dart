import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

/// A service class that handles Firebase operations including Storage and Firestore
class FirebaseService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Flag to track if we're using anonymous auth or public storage
  bool _usePublicStorage = true;

  /// Ensure user is signed in (anonymously if needed)
  Future<User?> _ensureSignedIn() async {
    if (_usePublicStorage) {
      // When using public storage, we don't need authentication
      return _auth.currentUser;
    }
    
    User? currentUser = _auth.currentUser;
    
    // If not signed in, sign in anonymously
    if (currentUser == null) {
      try {
        final userCredential = await _auth.signInAnonymously();
        currentUser = userCredential.user;
        debugPrint('Signed in anonymously with UID: ${currentUser?.uid}');
      } catch (e) {
        debugPrint('Error signing in anonymously: $e');
        // Don't rethrow, we'll use public storage instead
        _usePublicStorage = true;
      }
    }
    
    return currentUser;
  }

  /// Upload an image to Firebase Storage and store metadata in Firestore
  /// Returns a map containing download URL and document reference
  Future<Map<String, dynamic>> uploadImageToFirebase({
    required File imageFile,
    required String category,
    String? description,
    BuildContext? context,
  }) async {
    try {
      // Create a unique filename using timestamp
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageFile.path)}';
      
      // Try to get user, but don't require it
      final currentUser = await _ensureSignedIn();
      final String userId = currentUser?.uid ?? 'public';
      
      // Define storage reference path - use public folder if no auth
      final String storagePath = _usePublicStorage 
          ? 'public/$category/$fileName'
          : 'users/$userId/$category/$fileName';
      
      final storageRef = _storage.ref().child(storagePath);
      
      // Show progress if context is provided
      UploadTask uploadTask = storageRef.putFile(imageFile);
      
      if (context != null) {
        // Monitor upload progress
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: LinearProgressIndicator(value: progress),
              duration: const Duration(milliseconds: 500),
            ),
          );
        });
      }
      
      // Wait for upload to complete
      final snapshot = await uploadTask;
      
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      // Determine which collection to use
      final String collectionPath = _usePublicStorage
          ? 'public_documents'
          : 'users/$userId/$category';
      
      // Store metadata in Firestore
      final docRef = _usePublicStorage
          ? await _firestore.collection(collectionPath).add({
              'fileName': fileName,
              'originalName': path.basename(imageFile.path),
              'downloadUrl': downloadUrl,
              'description': description ?? '',
              'category': category,
              'createdAt': FieldValue.serverTimestamp(),
              'fileSize': await imageFile.length(),
              'userId': userId,
            })
          : await _firestore.collection('users')
              .doc(userId)
              .collection(category)
              .add({
                'fileName': fileName,
                'originalName': path.basename(imageFile.path),
                'downloadUrl': downloadUrl,
                'description': description ?? '',
                'category': category,
                'createdAt': FieldValue.serverTimestamp(),
                'fileSize': await imageFile.length(),
              });
      
      // Format the result for the recent files list
      Map<String, dynamic> recentFileFormat = {
        'name': _generateDisplayName(category, path.basename(imageFile.path)),
        'timestamp': DateTime.now().toString(),
        'downloadUrl': downloadUrl,
        'type': category,
        'documentId': docRef.id,
        'filePath': storagePath,
        'originalPath': imageFile.path,
      };
      
      return recentFileFormat;
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
      debugPrint('Error in uploadImageToFirebase: $e');
      rethrow;
    }
  }

  /// Helper method to generate a descriptive display name for recent files
  String _generateDisplayName(String category, String originalName) {
    // Format the current date
    final now = DateTime.now();
    final dateStr = '${now.day}-${now.month}-${now.year}';
    
    // Create a readable category name
    String readableCategory = '';
    switch (category) {
      case 'smart_scan':
        readableCategory = 'Smart Scan';
        break;
      case 'scanned_documents':
        readableCategory = 'Scanned Doc';
        break;
      case 'image':
        readableCategory = 'Image';
        break;
      default:
        readableCategory = category.split('_').map((word) => 
          word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : ''
        ).join(' ');
    }
    
    // Combine category, original name (shortened if needed), and date
    String baseName = path.basenameWithoutExtension(originalName);
    if (baseName.length > 10) {
      baseName = baseName.substring(0, 10) + '...';
    }
    
    return '$readableCategory - $baseName ($dateStr)';
  }

  /// Upload a scanned document with extracted text to Firebase
  Future<Map<String, dynamic>> uploadScannedDocument({
    required File imageFile,
    required String extractedText,
    double? confidence,
    BuildContext? context,
  }) async {
    try {
      final result = await uploadImageToFirebase(
        imageFile: imageFile,
        category: 'scanned_documents',
        context: context,
      );
      
      // Get the document reference
      final String documentId = result['documentId'];
      
      // Try to get user, but don't require it
      final currentUser = await _ensureSignedIn();
      final String userId = currentUser?.uid ?? 'public';
      
      // Update the document with extracted text
      if (_usePublicStorage) {
        await _firestore
            .collection('public_documents')
            .doc(documentId)
            .update({
          'extractedText': extractedText,
          'confidence': confidence ?? 0.0,
          'processingComplete': true,
        });
      } else {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('scanned_documents')
            .doc(documentId)
            .update({
          'extractedText': extractedText,
          'confidence': confidence ?? 0.0,
          'processingComplete': true,
        });
      }
      
      // Add extracted text to the recent file format
      result['extractedText'] = extractedText.length > 100 
          ? extractedText.substring(0, 100) + '...' 
          : extractedText;
      
      return result;
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading scanned document: $e')),
        );
      }
      debugPrint('Error in uploadScannedDocument: $e');
      rethrow;
    }
  }

  /// Get all scanned documents for the current user
  Future<List<Map<String, dynamic>>> getScannedDocuments() async {
    try {
      // Try to get user, but don't require it
      final currentUser = await _ensureSignedIn();
      final String userId = currentUser?.uid ?? 'public';
      
      QuerySnapshot querySnapshot;
      
      if (_usePublicStorage) {
        querySnapshot = await _firestore
            .collection('public_documents')
            .where('category', isEqualTo: 'scanned_documents')
            .orderBy('createdAt', descending: true)
            .get();
      } else {
        querySnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('scanned_documents')
            .orderBy('createdAt', descending: true)
            .get();
      }
      
      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting scanned documents: $e');
      rethrow;
    }
  }

  /// Delete a document from Firestore and its corresponding file from Storage
  Future<void> deleteDocument({
    required String documentId,
    required String category,
    BuildContext? context,
  }) async {
    try {
      // Try to get user, but don't require it
      final currentUser = await _ensureSignedIn();
      final String userId = currentUser?.uid ?? 'public';
      
      DocumentSnapshot docSnapshot;
      
      if (_usePublicStorage) {
        docSnapshot = await _firestore
            .collection('public_documents')
            .doc(documentId)
            .get();
      } else {
        docSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection(category)
            .doc(documentId)
            .get();
      }
      
      if (!docSnapshot.exists) {
        throw Exception('Document not found');
      }
      
      final data = docSnapshot.data() as Map<String, dynamic>;
      
      // Delete from Storage if filePath exists
      if (data.containsKey('filePath')) {
        final storageRef = _storage.ref().child(data['filePath']);
        await storageRef.delete();
      } else if (data.containsKey('fileName')) {
        // Alternative way to get storage reference
        final String storagePath = _usePublicStorage
            ? 'public/$category/${data['fileName']}'
            : 'users/$userId/$category/${data['fileName']}';
        final storageRef = _storage.ref().child(storagePath);
        await storageRef.delete();
      }
      
      // Delete from Firestore
      if (_usePublicStorage) {
        await _firestore
            .collection('public_documents')
            .doc(documentId)
            .delete();
      } else {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection(category)
            .doc(documentId)
            .delete();
      }
      
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document deleted successfully')),
        );
      }
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting document: $e')),
        );
      }
      debugPrint('Error in deleteDocument: $e');
      rethrow;
    }
  }
}
