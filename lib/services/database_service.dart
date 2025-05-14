import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> saveFileData({
    required String userId,
    required String fileName,
    required String downloadURL,
    String? fileType,
    bool isFavorite = false,
  }) async {
    try {
      print('Saving file data to Firestore:');
      print('User ID: $userId');
      print('File Name: $fileName');
      print('Download URL: $downloadURL');
      print('File Type: ${fileType ?? 'pdf'}');
      print('Is Favorite: $isFavorite');
      
      // Create a document reference
      DocumentReference docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('files')
          .doc(); // Auto-generate ID
      
      print('Document ID: ${docRef.id}');
      
      // Prepare data
      Map<String, dynamic> fileData = {
        'fileName': fileName,
        'downloadURL': downloadURL,
        'uploadedAt': FieldValue.serverTimestamp(),
        'type': fileType ?? 'pdf',
        'isFavorite': isFavorite,
      };
      
      // Save data
      await docRef.set(fileData);
      print('File data saved successfully to Firestore');
      return true;
    } catch (e, stackTrace) {
      print('Failed to save file data: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }
  
  // Save file metadata (for recent files)  
  Future<bool> saveFileMetadata(String userId, Map<String, dynamic> fileData) async {
    try {
      // Create a document reference with the file name as the ID to avoid duplicates
      String fileName = fileData['name'] ?? fileData['fileName'] ?? 'unknown_file';
      String docId = fileName.replaceAll('.', '_').replaceAll('/', '_').replaceAll(' ', '_');
      
      // Add the document ID to the file data so it can be referenced later
      fileData['id'] = docId;
      
      DocumentReference docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('recent_files')
          .doc(docId);
      
      // Add timestamp if not present
      if (!fileData.containsKey('timestamp')) {
        fileData['timestamp'] = FieldValue.serverTimestamp();
      }
      
      // Save data
      await docRef.set(fileData, SetOptions(merge: true));
      print('File metadata saved successfully to Firestore with ID: $docId');
      return true;
    } catch (e) {
      print('Failed to save file metadata: $e');
      return false;
    }
  }
  
  // Delete file metadata
  Future<bool> deleteFileMetadata(String userId, Map<String, dynamic> fileData) async {
    try {
      String fileName = fileData['name'] ?? fileData['fileName'] ?? 'unknown_file';
      String docId = fileName.replaceAll('.', '_').replaceAll('/', '_').replaceAll(' ', '_');
      
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('recent_files')
          .doc(docId)
          .delete();
      
      print('File metadata deleted successfully from Firestore');
      return true;
    } catch (e) {
      print('Failed to delete file metadata: $e');
      return false;
    }
  }
  
  // Get all files for a user
  Future<List<Map<String, dynamic>>> getUserFiles(String userId) async {
    try {
      print('Fetching files for user: $userId');
      
      // First try to get recent files
      QuerySnapshot recentSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('recent_files')
          .orderBy('timestamp', descending: true)
          .get();
      
      if (recentSnapshot.docs.isNotEmpty) {
        print('Found ${recentSnapshot.docs.length} recent files');
        
        List<Map<String, dynamic>> recentFiles = recentSnapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          
          // Ensure the ID is included in the data
          if (!data.containsKey('id')) {
            data['id'] = doc.id;
          }
          
          print('Recent file: ${data['name'] ?? data['fileName']} with ID: ${data['id']}');
          return data;
        }).toList();
        
        return recentFiles;
      }
      
      // If no recent files, fall back to regular files
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('files')
          .orderBy('uploadedAt', descending: true)
          .get();
      
      print('Found ${snapshot.docs.length} files');
      
      List<Map<String, dynamic>> files = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        // Ensure the ID is included in the data
        if (!data.containsKey('id')) {
          data['id'] = doc.id;
        }
        
        print('File: ${data['fileName']} with ID: ${data['id']}');
        return data;
      }).toList();
      
      return files;
    } catch (e) {
      print('Error fetching user files: $e');
      return [];
    }
  }
  
  // Get only favorite files for a user
  Future<List<Map<String, dynamic>>> getFavoriteFiles(String userId) async {
    try {
      print('Fetching favorite files for user: $userId');
      List<Map<String, dynamic>> allFavorites = [];
      
      // First check the recent_files collection
      print('Checking recent_files collection for favorites');
      QuerySnapshot recentSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('recent_files')
          .where('isFavorite', isEqualTo: true)
          .get();
      
      if (recentSnapshot.docs.isNotEmpty) {
        print('Found ${recentSnapshot.docs.length} favorite files in recent_files');
        
        List<Map<String, dynamic>> recentFavorites = recentSnapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          
          // Ensure the ID is included in the data
          if (!data.containsKey('id')) {
            data['id'] = doc.id;
          }
          
          print('Recent favorite file: ${data['name'] ?? data['fileName']} with ID: ${data['id']}');
          return data;
        }).toList();
        
        allFavorites.addAll(recentFavorites);
      }
      
      // Then check the files collection
      print('Checking files collection for favorites');
      QuerySnapshot filesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('files')
          .where('isFavorite', isEqualTo: true)
          .orderBy('uploadedAt', descending: true)
          .get();
      
      if (filesSnapshot.docs.isNotEmpty) {
        print('Found ${filesSnapshot.docs.length} favorite files in files collection');
        
        List<Map<String, dynamic>> fileFavorites = filesSnapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          
          // Ensure the ID is included in the data
          if (!data.containsKey('id')) {
            data['id'] = doc.id;
          }
          
          print('File favorite: ${data['fileName']} with ID: ${data['id']}');
          return data;
        }).toList();
        
        allFavorites.addAll(fileFavorites);
      }
      
      print('Total favorite files found: ${allFavorites.length}');
      return allFavorites;
    } catch (e) {
      print('Error getting favorite files: $e');
      return [];
    }
  }
  
  // Update favorite status for a file
  Future<bool> updateFileFavoriteStatus(String userId, String fileId, bool isFavorite) async {
    try {
      print('Updating favorite status:');
      print('User ID: $userId');
      print('File ID: $fileId');
      print('Is Favorite: $isFavorite');
      print('Updating favorite status for file $fileId to $isFavorite');
      
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('files')
          .doc(fileId)
          .update({'isFavorite': isFavorite});
      
      print('Favorite status updated successfully');
      return true;
    } catch (e) {
      print('Error updating favorite status: $e');
      return false;
    }
  }
  
  // Update file metadata
  Future<bool> updateFileMetadata(String userId, Map<String, dynamic> fileData) async {
    try {
      // Get the document ID from the file data or generate it from the file name
      String docId;
      if (fileData.containsKey('id')) {
        docId = fileData['id'];
      } else {
        String fileName = fileData['name'] ?? fileData['fileName'] ?? 'unknown_file';
        docId = fileName.replaceAll('.', '_').replaceAll('/', '_').replaceAll(' ', '_');
      }
      
      print('Updating file metadata:');
      print('User ID: $userId');
      print('File ID: $docId');
      
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('recent_files')
          .doc(docId)
          .update(fileData);
      
      print('File metadata updated successfully');
      return true;
    } catch (e) {
      print('Error updating file metadata: $e');
      return false;
    }
  }
  
  // Save user profile data
  Future<bool> saveUserProfile({
    required String userId,
    required Map<String, dynamic> userData,
  }) async {
    try {
      print('Saving user profile data for user: $userId');
      
      await _firestore
          .collection('users')
          .doc(userId)
          .set(userData, SetOptions(merge: true));
      
      print('User profile data saved successfully');
      return true;
    } catch (e) {
      print('Error saving user profile data: $e');
      return false;
    }
  }
  
  // Get user profile data
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      print('Fetching user profile for user: $userId');
      
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        print('User profile found');
        return data;
      } else {
        print('User profile not found');
        return null;
      }
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }
  
  // Submit user feedback to Firebase
  Future<bool> submitFeedback({
    required String userId,
    required String feedbackType,
    required int rating,
    required String comments,
  }) async {
    try {
      print('Submitting feedback for user: $userId');
      print('Feedback type: $feedbackType');
      print('Rating: $rating');
      print('Comments: $comments');
      
      // Create a document reference with auto-generated ID
      DocumentReference docRef = _firestore
          .collection('feedback')
          .doc();
      
      // Prepare feedback data
      Map<String, dynamic> feedbackData = {
        'userId': userId,
        'feedbackType': feedbackType,
        'rating': rating,
        'comments': comments,
        'submittedAt': FieldValue.serverTimestamp(),
        'status': 'pending', // pending, reviewed, addressed
      };
      
      // Save feedback to Firestore
      await docRef.set(feedbackData);
      print('Feedback submitted successfully with ID: ${docRef.id}');
      return true;
    } catch (e) {
      print('Error submitting feedback: $e');
      return false;
    }
  }
  
  // Get all feedback submitted by a user
  Future<List<Map<String, dynamic>>> getUserFeedback(String userId) async {
    try {
      print('Fetching feedback for user: $userId');
      
      QuerySnapshot snapshot = await _firestore
          .collection('feedback')
          .where('userId', isEqualTo: userId)
          .orderBy('submittedAt', descending: true)
          .get();
      
      print('Found ${snapshot.docs.length} feedback entries');
      
      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Add document ID to the data
        return data;
      }).toList();
    } catch (e) {
      print('Error fetching user feedback: $e');
      return [];
    }
  }
}
