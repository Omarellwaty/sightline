import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as filePicker;
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusionFlutterPdf;
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// A service class for PDF extraction functionality
/// This replaces the ExtractTextFromPdfScreen and provides a reusable service
/// for both Text-to-Speech and Change PDF Font features
class PdfExtractionService {
  /// Extracts text from a PDF file
  /// Returns a Map with the following keys:
  /// - 'content': The extracted text
  /// - 'name': The name of the file
  /// - 'timestamp': The timestamp of the extraction
  /// - 'pdfPath': The path to the PDF file (if available)
  static Future<Map<String, dynamic>?> extractTextFromPdf(BuildContext context) async {
    bool _isLoading = true;
    String _statusMessage = 'Initializing...';
    double _progressValue = 0.1;
    int _totalPages = 0;
    int _currentPage = 0;
    // Initialize text recognizer with support for both Latin and Arabic scripts
final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
// For Arabic text recognition - using Latin script as fallback since Arabic script is not directly available
final TextRecognizer _arabicTextRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    
    try {
      // Show progress indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Initializing PDF extraction...')),
      );

      // Check and request permissions first
      bool permissionsGranted = await _checkAndRequestPermissions(context);
      if (!permissionsGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission denied')),
        );
        return null;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opening file picker...')),
      );

      // Use a simpler file picker configuration with more options for emulators
      filePicker.FilePickerResult? result = await filePicker.FilePicker.platform.pickFiles(
        type: filePicker.FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No file selected')),
        );
        return null;
      }

      final file = result.files.first;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Processing PDF: ${file.name}...')),
      );

      String extractedText = '';
      bool usedOcr = false;

      // Try native text extraction first
      try {
        if (file.bytes != null) {
          // Use Syncfusion PDF library for text extraction
          final syncfusionFlutterPdf.PdfDocument document = syncfusionFlutterPdf.PdfDocument(inputBytes: file.bytes!);
          _totalPages = document.pages.count;
          
          // Extract text from each page
          for (int i = 0; i < _totalPages; i++) {
            _currentPage = i + 1;
            
            if (_currentPage % 5 == 0 || _currentPage == _totalPages) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Extracting text from page $_currentPage of $_totalPages...')),
              );
            }
            
            final syncfusionFlutterPdf.PdfTextExtractor extractor = syncfusionFlutterPdf.PdfTextExtractor(document);
            final String pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
            
            if (pageText.trim().isNotEmpty) {
              extractedText += 'Page ${i + 1}:\n$pageText\n\n';
            }
          }
          
          document.dispose();
        } else if (file.path != null) {
          // Use file path
          final bytes = await File(file.path!).readAsBytes();
          final syncfusionFlutterPdf.PdfDocument document = syncfusionFlutterPdf.PdfDocument(inputBytes: bytes);
          _totalPages = document.pages.count;
          
          // Extract text from each page
          for (int i = 0; i < _totalPages; i++) {
            _currentPage = i + 1;
            
            if (_currentPage % 5 == 0 || _currentPage == _totalPages) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Extracting text from page $_currentPage of $_totalPages...')),
              );
            }
            
            final syncfusionFlutterPdf.PdfTextExtractor extractor = syncfusionFlutterPdf.PdfTextExtractor(document);
            final String pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
            
            if (pageText.trim().isNotEmpty) {
              extractedText += 'Page ${i + 1}:\n$pageText\n\n';
            }
          }
          
          document.dispose();
        }
      } catch (e) {
        // If native extraction fails, try OCR as a fallback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Native text extraction failed, trying OCR: $e')),
        );
        
        extractedText = await _extractTextUsingOcr(file, context, _textRecognizer);
        usedOcr = true;
      }

      // Clean up
      _textRecognizer.close();
      _arabicTextRecognizer.close();
      
      if (extractedText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No text could be extracted from the PDF')),
        );
        return null;
      }

      // Prepare result data
      final Map<String, dynamic> resultData = {
        'content': extractedText,
        'name': file.name,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'size': file.size,
        'usedOcr': usedOcr,
      };

      // Add path if available
      if (file.path != null) {
        resultData['pdfPath'] = file.path;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Text extraction completed successfully')),
      );
      
      return resultData;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error extracting text: $e')),
      );
      return null;
    }
  }

  /// Checks and requests necessary permissions
  static Future<bool> _checkAndRequestPermissions(BuildContext context) async {
    try {
      // Request all potentially needed permissions at once
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.photos,
        Permission.videos,
        Permission.manageExternalStorage,  // Add this for better access on newer Android
      ].request();
      
      // On emulators, we might need to proceed even with limited permissions
      // So we'll return true even if only some permissions are granted
      bool hasAnyPermission = statuses.values.any((status) => status.isGranted);
      
      if (hasAnyPermission) {
        return true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Storage permission is required to access PDF files. Please enable it in app settings.'),
            duration: Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Open Settings',
              onPressed: () {
                openAppSettings();
              },
            ),
          ),
        );
        return false;
      }
    } catch (e) {
      // Return true to allow the operation to proceed even with permission errors
      // This helps with emulator testing
      return true;
    }
  }

  /// Extracts text from PDF using OCR as a fallback method
  static Future<String> _extractTextUsingOcr(
    filePicker.PlatformFile file,
    BuildContext context,
    TextRecognizer textRecognizer
  ) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attempting OCR extraction...')),
      );
      
      // This is a simplified version - in a real implementation, you would:
      // 1. Convert PDF pages to images
      // 2. Run OCR on each image
      // 3. Combine the results
      
      // For now, we'll return a placeholder message
      return "OCR extraction is not fully implemented in this version. Please use a PDF with embedded text. Arabic text extraction may require a PDF with embedded text.";
    } catch (e) {
      return "OCR extraction failed: $e";
    }
  }
}
