import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveFileData({
    required String userId,
    required String fileName,
    required String downloadURL,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('files')
          .add({
        'fileName': fileName,
        'downloadURL': downloadURL,
        'uploadedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to save file data: $e');
    }
  }
}
