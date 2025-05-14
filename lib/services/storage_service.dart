import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Uploads text content as a file and returns the download URL
  Future<String?> uploadTextContent(String textContent, String fileName, String userId) async {
    try {
      // Validate inputs
      if (textContent.isEmpty) {
        print('Text content is empty');
        return null;
      }
      
      if (fileName.isEmpty) {
        fileName = 'text_${DateTime.now().millisecondsSinceEpoch}.txt';
      }
      
      // Ensure the filename has a .txt extension
      if (!fileName.toLowerCase().endsWith('.txt')) {
        fileName = '$fileName.txt';
      }
      
      // Generate path in storage
      String filePath = 'users/$userId/text_files/$fileName';
      print('Target path in Firebase Storage: $filePath');
      
      // Create a reference to the location
      final ref = _storage.ref().child(filePath);
      
      // Convert text to bytes
      final bytes = textContent.codeUnits;
      
      // Create metadata
      final metadata = SettableMetadata(
        contentType: 'text/plain',
        customMetadata: {
          'uploadedAt': DateTime.now().toString(),
          'size': bytes.length.toString(),
        },
      );
      
      // Upload the file with a timeout
      print('Starting text content upload to Firebase Storage');
      final uploadTask = ref.putData(Uint8List.fromList(bytes), metadata);
      
      // Set up a timeout with a flag to track completion
      final completer = Completer<TaskSnapshot>();
      bool isCompleted = false;
      
      final timer = Timer(const Duration(seconds: 60), () {
        if (!isCompleted) {
          isCompleted = true;
          completer.completeError('Upload timed out after 60 seconds');
        }
      });
      
      // Listen for upload completion
      uploadTask.then((snapshot) {
        if (!isCompleted) {
          isCompleted = true;
          completer.complete(snapshot);
        }
      }).catchError((error) {
        if (!isCompleted) {
          isCompleted = true;
          completer.completeError(error);
        }
      });
      
      // Wait for completion or timeout
      final snapshot = await completer.future;
      timer.cancel();
      
      // Get download URL
      final downloadURL = await ref.getDownloadURL();
      print('Upload complete. Download URL: $downloadURL');
      return downloadURL;
    } catch (e) {
      print('Error uploading text content: $e');
      return null;
    }
  }

  // Uploads a file and returns the download URL
  Future<String?> uploadFile(File file, String userId) async {
    try {
      // Verify file exists and has content
      if (!await file.exists()) {
        print('File does not exist: ${file.path}');
        return null;
      }
      
      int fileSize = await file.length();
      if (fileSize <= 0) {
        print('File is empty: ${file.path}');
        return null;
      }
      
      // Verify file is readable before attempting upload
      try {
        final bytes = await file.readAsBytes();
        print('Successfully read ${bytes.length} bytes from file');
        
        // Check if file is a valid PDF (basic check)
        if (file.path.toLowerCase().endsWith('.pdf')) {
          if (bytes.length < 4 || String.fromCharCodes(bytes.sublist(0, 4)) != '%PDF') {
            print('Warning: File does not start with %PDF marker');
            // Continue anyway, just log the warning
          }
        }
      } catch (e) {
        print('Error reading file before upload: $e');
        return null;
      }
      
      print('Uploading file: ${file.path}');
      print('File size: $fileSize bytes');
      
      // Generate unique filename with timestamp
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_${basename(file.path)}';
      String filePath = 'users/$userId/$fileName';
      
      print('Target path in Firebase Storage: $filePath');

      // Create a reference to the location
      final ref = _storage.ref().child(filePath);

      // Upload file with progress monitoring and error handling
      print('Creating upload task...');
      UploadTask uploadTask = ref.putFile(
        file,
        SettableMetadata(
          contentType: 'application/pdf',
          customMetadata: {
            'uploaded': DateTime.now().toString(),
            'originalName': basename(file.path),
          },
        ),
      );
      print('Upload task created successfully');
      
      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
      }, onError: (e) {
        print('Upload progress error: $e');
      });
      
      print('Waiting for upload to complete...');
      // Wait for upload to complete with timeout
      TaskSnapshot snapshot = await uploadTask.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          print('Upload timed out after 5 minutes');
          throw TimeoutException('Upload timed out after 5 minutes');
        },
      );
      print('Upload completed. Bytes transferred: ${snapshot.bytesTransferred}');

      // Get and return the download URL
      print('Getting download URL...');
      String downloadUrl = await snapshot.ref.getDownloadURL();
      print('Download URL obtained: $downloadUrl');
      return downloadUrl;
    } catch (e, stackTrace) {
      print('Error uploading file: $e');
      print('Stack trace: $stackTrace');
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
