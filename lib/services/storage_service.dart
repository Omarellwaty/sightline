import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Uploads a file and returns the download URL
  Future<String?> uploadFile(File file, String userId) async {
    try {
      // Generate unique filename with timestamp
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_${basename(file.path)}';
      String filePath = 'users/$userId/$fileName';

      // Create a reference to the location
      final ref = _storage.ref().child(filePath);

      // Upload file
      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot snapshot = await uploadTask;

      // Get and return the download URL
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }

  // Optional: Delete a file from storage
  Future<void> deleteFile(String filePath) async {
    try {
      await _storage.ref().child(filePath).delete();
    } catch (e) {
      print('Delete error: $e');
    }
  }
}
