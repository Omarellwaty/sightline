import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/database_service.dart';
import '../smart_scan/smart_scan_home_screen.dart';

/// Class that handles file operations for the HomeScreen
class FileOperations {
  final BuildContext context;
  final Function(Map<String, dynamic>) onFileUploaded;
  final DatabaseService databaseService = DatabaseService();

  FileOperations({
    required this.context,
    required this.onFileUploaded,
  });

  /// Toggle favorite status for a file
  Future<void> toggleFavorite(Map<String, dynamic> file, int index, List<Map<String, dynamic>> recentFiles) async {
    try {
      // Get the current favorite status
      final bool currentStatus = file['isFavorite'] == true;
      final bool newStatus = !currentStatus;
      
      // Generate an ID if one doesn't exist
      String fileId;
      if (file['id'] != null) {
        fileId = file['id'].toString();
      } else {
        // Create an ID based on the file name
        String fileName = file['name'] ?? file['fileName'] ?? 'unknown_file';
        fileId = fileName.replaceAll('.', '_').replaceAll('/', '_').replaceAll(' ', '_');
        
        // Add the ID to the file in the recent files list
        recentFiles[index]['id'] = fileId;
      }
      
      // Show feedback to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newStatus ? 'Added to favorites' : 'Removed from favorites')),
      );
      
      // Update file data with the new favorite status
      Map<String, dynamic> updatedFile = Map<String, dynamic>.from(file);
      updatedFile['id'] = fileId; // Ensure ID is included
      updatedFile['isFavorite'] = newStatus;
      
      // Save the updated file metadata to Firestore
      await databaseService.saveFileMetadata('user123', updatedFile); // Using saveFileMetadata instead of updateFileMetadata
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating favorite status: $e')),
      );
    }
  }

  /// Share a file with other apps
  Future<void> shareFile(Map<String, dynamic> file) async {
    try {
      final String? filePath = file['path'];
      if (filePath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File path not found')),
        );
        return;
      }
      
      final File fileToShare = File(filePath);
      if (!await fileToShare.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File not found on device')),
        );
        return;
      }
      
      // Get file name from path
      final String fileName = path.basename(filePath);
      
      // Share the file
      await Share.shareFiles(
        [filePath],
        text: 'Sharing $fileName',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing file: $e')),
      );
    }
  }

  /// Pick a PDF file from device storage
  Future<void> pickPDF() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      
      if (result != null && result.files.single.path != null) {
        final String filePath = result.files.single.path!;
        final String fileName = path.basename(filePath);
        
        // Create file metadata
        final Map<String, dynamic> fileData = {
          'name': fileName,
          'path': filePath,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'type': 'pdf',
          'isFavorite': false,
        };
        
        // Add to recent files
        onFileUploaded(fileData);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF uploaded: $fileName')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking PDF: $e')),
      );
    }
  }

  /// Pick an image for smart scan
  Future<void> pickImageForSmartScan(ImageSource source) async {
    try {
      // Navigate directly to SmartScanHomeScreen and pass the source
      // This will automatically trigger the image picker with the selected source
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SmartScanHomeScreen(
            onFileUploaded: onFileUploaded,
            initialImageSource: source, // Pass the source to auto-start scanning
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }
}
