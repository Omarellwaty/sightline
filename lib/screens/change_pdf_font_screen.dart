import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/file_service.dart';
import '../services/pdf_firebase_service.dart';
import 'text_editor_screen.dart';

class ChangePdfFontScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onFileUploaded;

  const ChangePdfFontScreen({super.key, required this.onFileUploaded});

  @override
  State<ChangePdfFontScreen> createState() => _ChangePdfFontScreenState();
}

class _ChangePdfFontScreenState extends State<ChangePdfFontScreen> {
  bool _isLoading = false;
  double _progressValue = 0.0;
  String _statusMessage = '';
  String? _inputFileName;
  String _extractedText = '';

  Future<bool> _checkAndRequestPermissions(BuildContext context) async {
    try {
      // Request all potentially needed permissions at once
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.photos,
        Permission.videos,
        Permission.manageExternalStorage,
      ].request();

      bool hasAnyPermission = statuses.values.any((status) => status.isGranted);

      if (hasAnyPermission) {
        return true;
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage permission is required to access PDF files. Please enable it in app settings.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  void _initializeLoading() {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Initializing...';
      _progressValue = 0.0;
    });
  }

  void _handlePermissionDenied() {
    setState(() {
      _isLoading = false;
      _statusMessage = 'Permission denied';
      _progressValue = 0.0;
    });
  }

  void _handleError(dynamic error) {
    setState(() {
      _isLoading = false;
      _statusMessage = 'Error: $error';
      _progressValue = 0.0;
    });

    // Show a more user-friendly error message
    String errorMessage = 'An error occurred while processing the PDF';

    if (error.toString().contains('permission')) {
      errorMessage = 'Permission denied. Please grant storage access in settings.';
    } else if (error.toString().contains('file')) {
      errorMessage = 'There was a problem with the selected file. Please try another PDF.';
    } else if (error.toString().contains('bytes')) {
      errorMessage = 'Could not read the PDF file content. The file may be corrupted.';
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Details',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Technical details: $error')),
              );
            },
          ),
        ),
      );
    }
  }

  Future<void> _uploadPdfAndExtractText() async {
    try {
      _initializeLoading();

      // Show a message to indicate we're starting
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Starting PDF upload and text extraction...')),
        );
      }

      // Check and request permissions first
      setState(() {
        _statusMessage = 'Checking permissions...';
        _progressValue = 0.2;
      });

      bool permissionsGranted = await _checkAndRequestPermissions(context);
      if (!permissionsGranted) {
        _handlePermissionDenied();
        return;
      }

      // Update status before picking file
      setState(() {
        _statusMessage = 'Opening file picker...';
        _progressValue = 0.3;
      });

      // Pick PDF file
      final filePickerResult = await FileService.pickPdfFile();
      if (filePickerResult == null) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'No file selected';
          _progressValue = 0.0;
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No PDF file was selected')),
          );
        }
        return;
      }

      // Get file details
      final fileBytes = filePickerResult.files.first.bytes!;
      _inputFileName = filePickerResult.files.first.name;

      // Update status for processing
      setState(() {
        _statusMessage = 'Processing PDF...';
        _progressValue = 0.5;
      });

      // Get the temporary directory path
      final tempDir = await getTemporaryDirectory();
      final tempPath = tempDir.path;

      // Create input file path
      final inputFilePath = '$tempPath/input_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final inputFile = File(inputFilePath);
      await inputFile.writeAsBytes(fileBytes);

      setState(() {
        _statusMessage = 'Extracting text...';
        _progressValue = 0.7;
      });

      // Extract text from the PDF first
      final pdfDocument = PdfDocument(inputBytes: fileBytes);
      final pdfTextExtractor = PdfTextExtractor(pdfDocument);
      _extractedText = pdfTextExtractor.extractText();
      pdfDocument.dispose();

      // Upload the original PDF to Firebase
      try {
        setState(() {
          _statusMessage = 'Uploading to Firebase...';
          _progressValue = 0.9;
        });

        final pdfFirebaseService = PdfFirebaseService();
        final result = await pdfFirebaseService.uploadModifiedPdf(
          pdfFile: inputFile,
          originalFileName: _inputFileName ?? 'Unknown',
          selectedFont: 'Arial', // Default font
          fontSize: 14.0, // Default font size
          wordSpacing: 0.0,
          letterSpacing: 0.0,
          lineSpacing: 1.0,
          context: context,
        );

        // Call the onFileUploaded callback with the result
        widget.onFileUploaded({
          'name': result['fileName'],
          'timestamp': DateTime.now().toString(),
          'downloadUrl': result['downloadUrl'],
          'type': 'original_pdf',
          'font': 'Original',
        });
      } catch (firebaseError) {
        debugPrint('Error uploading to Firebase: $firebaseError');
        // Continue with the process even if Firebase upload fails
      }

      setState(() {
        _isLoading = false;
        _statusMessage = 'Text extracted successfully!';
        _progressValue = 1.0;
      });

      // Navigate to the Text Editor screen with the extracted text
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TextEditorScreen(
              extractedText: _extractedText,
              inputFileName: _inputFileName,
              initialFontSize: 14.0, // Default font size
              initialWordSpacing: 0.0,
              initialLetterSpacing: 0.0,
              initialLineSpacing: 1.0,
              onSave: (String editedText) {
                // Save the edited text
                _extractedText = editedText;

                // Show saving message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Text saved successfully')),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      _handleError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Extract Text from PDF'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Upload section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Upload PDF',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description text
                    const Text(
                      'Upload a PDF file to extract text and edit it in the text editor.',
                      style: TextStyle(fontSize: 16),
                    ),

                    const SizedBox(height: 24),

                    // Upload button
                    Center(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload PDF'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                        onPressed: _isLoading ? null : _uploadPdfAndExtractText,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Loading indicator
            if (_isLoading)
              Column(
                children: [
                  LinearProgressIndicator(
                    value: _progressValue,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}