import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

/// A service class that handles Firebase operations for PDF files
class PdfFirebaseService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Flag to use public storage
  bool _usePublicStorage = true;

  /// Upload a PDF file to Firebase Storage and store metadata in Firestore
  /// Returns a map containing download URL and document reference
  Future<Map<String, dynamic>> uploadPdfToFirebase({
    required File pdfFile,
    required String category,
    String? description,
    Map<String, dynamic>? additionalMetadata,
    BuildContext? context,
  }) async {
    try {
      // Create a unique filename using timestamp
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(pdfFile.path)}';
      
      // Define storage reference path - use public folder
      final String storagePath = 'public/$category/$fileName';
      final storageRef = _storage.ref().child(storagePath);
      
      // Show progress if context is provided
      UploadTask uploadTask = storageRef.putFile(pdfFile);
      
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
      
      // Store metadata in Firestore
      final docRef = await _firestore.collection('public_documents').add({
        'fileName': fileName,
        'originalName': path.basename(pdfFile.path),
        'downloadUrl': downloadUrl,
        'description': description ?? '',
        'category': category,
        'createdAt': FieldValue.serverTimestamp(),
        'fileSize': await pdfFile.length(),
        ...?additionalMetadata,
      });
      
      // Format the result for the recent files list
      Map<String, dynamic> recentFileFormat = {
        'name': _generateDisplayName(category, path.basename(pdfFile.path), additionalMetadata),
        'timestamp': DateTime.now().toString(),
        'downloadUrl': downloadUrl,
        'type': category,
        'documentId': docRef.id,
        'filePath': storagePath,
        'originalPath': pdfFile.path,
      };
      
      return recentFileFormat;
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading PDF: $e')),
        );
      }
      debugPrint('Error in uploadPdfToFirebase: $e');
      rethrow;
    }
  }
  
  /// Helper method to generate a descriptive display name for recent files
  String _generateDisplayName(String category, String originalName, Map<String, dynamic>? metadata) {
    // Format the current date
    final now = DateTime.now();
    final dateStr = '${now.day}-${now.month}-${now.year}';
    
    // Create a readable category name
    String readableCategory = '';
    switch (category) {
      case 'modified_pdfs':
        readableCategory = 'Font Modified';
        // Add font info if available
        if (metadata != null && metadata['selectedFont'] != null) {
          readableCategory += ' (${metadata['selectedFont']})';
        }
        break;
      case 'extracted_text_pdfs':
        readableCategory = 'Text Extracted';
        break;
      case 'pdf':
        readableCategory = 'PDF';
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

  /// Upload a PDF with modified font to Firebase
  Future<Map<String, dynamic>> uploadModifiedPdf({
    required File pdfFile,
    required String originalFileName,
    required String selectedFont,
    double? fontSize,
    double? wordSpacing,
    double? letterSpacing,
    double? lineSpacing,
    BuildContext? context,
  }) async {
    try {
      // Upload the PDF file
      final result = await uploadPdfToFirebase(
        pdfFile: pdfFile,
        category: 'modified_pdfs',
        description: 'PDF with modified font: $selectedFont',
        additionalMetadata: {
          'originalFileName': originalFileName,
          'selectedFont': selectedFont,
          'fontSize': fontSize,
          'wordSpacing': wordSpacing,
          'letterSpacing': letterSpacing,
          'lineSpacing': lineSpacing,
          'processingType': 'font_modification',
        },
        context: context,
      );
      
      // Add font information to the recent file format
      result['font'] = selectedFont;
      result['fontSize'] = fontSize;
      
      return result;
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading modified PDF: $e')),
        );
      }
      debugPrint('Error in uploadModifiedPdf: $e');
      rethrow;
    }
  }

  /// Upload a PDF with extracted text to Firebase
  Future<Map<String, dynamic>> uploadExtractedTextPdf({
    required File pdfFile,
    required String extractedText,
    String? originalFileName,
    bool isOcr = false,
    BuildContext? context,
  }) async {
    try {
      // Upload the PDF file
      final result = await uploadPdfToFirebase(
        pdfFile: pdfFile,
        category: 'extracted_text_pdfs',
        description: 'PDF with extracted text',
        additionalMetadata: {
          'originalFileName': originalFileName ?? path.basename(pdfFile.path),
          'extractedText': extractedText,
          'isOcr': isOcr,
          'processingType': 'text_extraction',
        },
        context: context,
      );
      
      // Add extracted text to the recent file format (truncated for display)
      result['extractedText'] = extractedText.length > 100 
          ? extractedText.substring(0, 100) + '...' 
          : extractedText;
      
      return result;
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading PDF with extracted text: $e')),
        );
      }
      debugPrint('Error in uploadExtractedTextPdf: $e');
      rethrow;
    }
  }

  /// Get all PDFs for a specific category
  Future<List<Map<String, dynamic>>> getPdfs(String category) async {
    try {
      final querySnapshot = await _firestore
          .collection('public_documents')
          .where('category', isEqualTo: category)
          .orderBy('createdAt', descending: true)
          .get();
      
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('Error getting PDFs: $e');
      rethrow;
    }
  }

  /// Delete a PDF document from Firestore and its corresponding file from Storage
  Future<void> deletePdf({
    required String documentId,
    BuildContext? context,
  }) async {
    try {
      // Get the document to retrieve the file path
      final docSnapshot = await _firestore
          .collection('public_documents')
          .doc(documentId)
          .get();
      
      if (!docSnapshot.exists) {
        throw Exception('Document not found');
      }
      
      final data = docSnapshot.data()!;
      
      // Delete from Storage if filePath exists
      if (data.containsKey('filePath')) {
        final storageRef = _storage.ref().child(data['filePath']);
        await storageRef.delete();
      } else if (data.containsKey('fileName') && data.containsKey('category')) {
        // Alternative way to get storage reference
        final String storagePath = 'public/${data['category']}/${data['fileName']}';
        final storageRef = _storage.ref().child(storagePath);
        await storageRef.delete();
      }
      
      // Delete from Firestore
      await _firestore
          .collection('public_documents')
          .doc(documentId)
          .delete();
      
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF deleted successfully')),
        );
      }
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting PDF: $e')),
        );
      }
      debugPrint('Error in deletePdf: $e');
      rethrow;
    }
  }
}
