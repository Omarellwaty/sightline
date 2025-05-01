import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as filePicker;
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusionFlutterPdf;
import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'extracted_text_screen.dart';
import '../services/pdf_firebase_service.dart';

class ExtractTextFromPdfScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onFileUploaded;

  ExtractTextFromPdfScreen({required this.onFileUploaded});

  @override
  _ExtractTextFromPdfScreenState createState() => _ExtractTextFromPdfScreenState();
}

class _ExtractTextFromPdfScreenState extends State<ExtractTextFromPdfScreen> {
  bool _isLoading = false;
  String _statusMessage = '';
  double _progressValue = 0.0;
  int _totalPages = 0;
  int _currentPage = 0;
  late final TextRecognizer _textRecognizer;

  @override
  void initState() {
    super.initState();
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  }
  
  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<bool> _checkAndRequestPermissions(BuildContext context) async {
    try {
      print('Starting permission check...');
      
      // Request all potentially needed permissions at once
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.photos,
        Permission.videos,
        Permission.manageExternalStorage,  // Add this for better access on newer Android
      ].request();
      
      print('Permission request results:');
      statuses.forEach((permission, status) {
        print('$permission: $status');
      });
      
      // On emulators, we might need to proceed even with limited permissions
      // So we'll return true even if only some permissions are granted
      bool hasAnyPermission = statuses.values.any((status) => status.isGranted);
      
      if (hasAnyPermission) {
        print('Some essential permissions granted, proceeding');
        return true;
      } else {
        print('All essential permissions denied');
        
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
      print('Error checking/requesting permissions: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error with permissions: $e')),
      );
      // Return true to allow the operation to proceed even with permission errors
      // This helps with emulator testing
      return true;
    }
  }

  Future<String> _extractTextFromPdf(BuildContext context) async {
    try {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Initializing...';
        _progressValue = 0.1;
      });

      // Check and request permissions first
      bool permissionsGranted = await _checkAndRequestPermissions(context);
      if (!permissionsGranted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Permission denied';
          _progressValue = 0.0;
        });
        print('Cannot proceed: Permissions not granted');
        return '';
      }

      setState(() {
        _statusMessage = 'Opening file picker...';
        _progressValue = 0.2;
      });

      print('Opening file picker...');
      // Use a simpler file picker configuration with more options for emulators
      filePicker.FilePickerResult? result = await filePicker.FilePicker.platform.pickFiles(
        type: filePicker.FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _isLoading = false;
          _statusMessage = '';
          _progressValue = 0.0;
        });
        print('No file selected');
        return '';
      }

      final file = result.files.first;
      print('File selected: ${file.name}, Path: ${file.path}, Has bytes: ${file.bytes != null}');

      setState(() {
        _statusMessage = 'Processing PDF...';
        _progressValue = 0.3;
      });

      String extractedText = '';
      bool usedOcr = false;

      // Try native text extraction first
      try {
        if (file.bytes != null) {
          // Use Syncfusion PDF library for text extraction
          final syncfusionFlutterPdf.PdfDocument document = syncfusionFlutterPdf.PdfDocument(inputBytes: file.bytes!);
          _totalPages = document.pages.count;
          
          print('PDF has $_totalPages pages');
          
          // Extract text from each page
          for (int i = 0; i < _totalPages; i++) {
            setState(() {
              _currentPage = i + 1;
              _statusMessage = 'Extracting text from page $_currentPage of $_totalPages...';
              _progressValue = 0.3 + (0.4 * _currentPage / _totalPages);
            });
            
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
          
          print('PDF has $_totalPages pages');
          
          // Extract text from each page
          for (int i = 0; i < _totalPages; i++) {
            setState(() {
              _currentPage = i + 1;
              _statusMessage = 'Extracting text from page $_currentPage of $_totalPages...';
              _progressValue = 0.3 + (0.4 * _currentPage / _totalPages);
            });
            
            final syncfusionFlutterPdf.PdfTextExtractor extractor = syncfusionFlutterPdf.PdfTextExtractor(document);
            final String pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
            
            if (pageText.trim().isNotEmpty) {
              extractedText += 'Page ${i + 1}:\n$pageText\n\n';
            }
          }
          
          document.dispose();
        }
      } catch (e) {
        print('Error in native text extraction: $e');
        extractedText = '';
      }

      // If native extraction failed or returned empty text, try OCR
      if (extractedText.trim().isEmpty) {
        setState(() {
          _statusMessage = 'Native text extraction failed. Trying OCR...';
          _progressValue = 0.5;
        });
        
        print('Native text extraction failed or returned empty text. Trying OCR...');
        
        try {
          if (_totalPages > 1) {
            extractedText = await _extractTextWithOcrMultiPage(file);
          } else {
            extractedText = await _extractTextWithOcr(file);
          }
          usedOcr = true;
        } catch (ocrError) {
          print('OCR extraction error: $ocrError');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error extracting text with OCR: $ocrError')),
          );
        }
      }

      // Upload the PDF and extracted text to Firebase
      try {
        setState(() {
          _statusMessage = 'Uploading to Firebase...';
          _progressValue = 0.9;
        });
        
        // Create a temporary file if we only have bytes
        File pdfFile;
        if (file.path != null) {
          pdfFile = File(file.path!);
        } else {
          final tempDir = await getTemporaryDirectory();
          pdfFile = File('${tempDir.path}/${file.name}');
          await pdfFile.writeAsBytes(file.bytes!);
        }
        
        final pdfFirebaseService = PdfFirebaseService();
        final result = await pdfFirebaseService.uploadExtractedTextPdf(
          pdfFile: pdfFile,
          extractedText: extractedText,
          originalFileName: file.name,
          isOcr: usedOcr,
          context: context,
        );
        
        debugPrint('PDF uploaded to Firebase: ${result['downloadUrl']}');
        
        // Call the onFileUploaded callback with the result
        widget.onFileUploaded({
          'name': file.name,
          'timestamp': DateTime.now().toString(),
          'downloadUrl': result['downloadUrl'],
          'type': 'extracted_text_pdf',
          'extractedText': extractedText.substring(0, min(100, extractedText.length)) + '...',
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF uploaded to Firebase successfully')),
        );
      } catch (firebaseError) {
        debugPrint('Error uploading to Firebase: $firebaseError');
        // Continue with the process even if Firebase upload fails
      }

      setState(() {
        _isLoading = false;
        _statusMessage = '';
        _progressValue = 1.0;
      });

      return extractedText;
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error: $e';
        _progressValue = 0.0;
      });
      
      print('Error extracting text: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      
      return '';
    }
  }

  Future<String> _extractTextWithOcr(filePicker.PlatformFile file) async {
    try {
      if (file.path == null) {
        print('File path is null');
        return '';
      }

      print('Rendering PDF page as image...');
      final document = await PdfDocument.openFile(file.path!);
      if (document.pagesCount == 0) {
        print('PDF has no pages');
        await document.close();
        return '';
      }

      final page = await document.getPage(1);
      final pageImage = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: PdfPageImageFormat.png,
      );
      await page.close();

      if (pageImage == null || pageImage.bytes == null || pageImage.bytes!.isEmpty) {
        print('Failed to render PDF page as image');
        await document.close();
        return '';
      }

      final tempDir = await getTemporaryDirectory();
      final tempImagePath = '${tempDir.path}/temp_page.png';
      final tempFile = File(tempImagePath);
      await tempFile.writeAsBytes(pageImage.bytes!);
      print('PDF page rendered and saved to: $tempImagePath');

      print('Performing OCR with Google ML Kit...');
      try {
        // Use Google ML Kit for text recognition
        final inputImage = InputImage.fromFile(tempFile);
        final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
        
        String extractedText = recognizedText.text;
        print('OCR extracted ${extractedText.length} characters');
        
        await document.close();
        return extractedText;
      } catch (e) {
        print('Error during OCR: $e');
        await document.close();
        return '';
      }
    } catch (e) {
      print('Error during OCR: $e');
      return '';
    }
  }

  Future<String> _extractTextWithOcrMultiPage(filePicker.PlatformFile file) async {
    try {
      if (file.path == null) {
        print('File path is null');
        return '';
      }

      print('Processing multi-page PDF with OCR...');
      final document = await PdfDocument.openFile(file.path!);
      if (document.pagesCount == 0) {
        print('PDF has no pages');
        await document.close();
        return '';
      }

      _totalPages = document.pagesCount;
      setState(() {
        _statusMessage = 'Processing $_totalPages pages with OCR...';
      });

      String combinedText = '';
      
      // Process up to 10 pages to avoid excessive processing time
      int pagesToProcess = min(_totalPages, 10);
      
      for (int i = 1; i <= pagesToProcess; i++) {
        _currentPage = i;
        setState(() {
          _statusMessage = 'Processing page $_currentPage of $pagesToProcess with OCR...';
          _progressValue = 0.7 + (0.2 * (i / pagesToProcess));
        });

        try {
          final page = await document.getPage(i);
          final pageImage = await page.render(
            width: page.width * 2,
            height: page.height * 2,
            format: PdfPageImageFormat.png,
          );
          await page.close();

          if (pageImage == null || pageImage.bytes == null || pageImage.bytes!.isEmpty) {
            print('Failed to render page $i as image');
            continue;
          }

          final tempDir = await getTemporaryDirectory();
          final tempImagePath = '${tempDir.path}/temp_page_$i.png';
          final tempFile = File(tempImagePath);
          await tempFile.writeAsBytes(pageImage.bytes!);
          print('Page $i rendered and saved to: $tempImagePath');

          // Use Google ML Kit for text recognition
          final inputImage = InputImage.fromFile(tempFile);
          final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
          
          String pageText = recognizedText.text;
          print('OCR extracted ${pageText.length} characters from page $i');
          
          if (pageText.isNotEmpty) {
            combinedText += '--- Page $i ---\n$pageText\n\n';
          }
          
          // Delete the temporary file
          await tempFile.delete();
        } catch (e) {
          print('Error processing page $i: $e');
        }
      }

      await document.close();
      return combinedText;
    } catch (e) {
      print('Error during multi-page OCR: $e');
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Extract Text from PDF'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Permission status card
            Card(
              margin: const EdgeInsets.all(16.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: FutureBuilder<Map<Permission, PermissionStatus>>(
                  future: [
                    Permission.storage,
                    Permission.photos,
                    Permission.videos,
                    Permission.manageExternalStorage,
                  ].request(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    Map<Permission, PermissionStatus> statuses = snapshot.data!;
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Permission Status',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        _buildPermissionStatus('Storage', statuses[Permission.storage]?.isGranted ?? false),
                        _buildPermissionStatus('Photos', statuses[Permission.photos]?.isGranted ?? false),
                        _buildPermissionStatus('Videos', statuses[Permission.videos]?.isGranted ?? false),
                        _buildPermissionStatus('Manage Storage', statuses[Permission.manageExternalStorage]?.isGranted ?? false),
                        SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            openAppSettings();
                          },
                          child: Text('Open Settings'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            SizedBox(height: 16),
            
            // Main content
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Extract Text from PDF Files',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20),
                      Text(
                        'This tool extracts text from PDF files using both native text extraction and OCR technology for scanned documents.',
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 40),
                      if (_isLoading) ...[
                        LinearProgressIndicator(value: _progressValue),
                        SizedBox(height: 10),
                        Text(
                          _statusMessage,
                          style: TextStyle(fontSize: 16, color: Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                        if (_totalPages > 0) ...[
                          SizedBox(height: 5),
                          Text(
                            'Page $_currentPage of $_totalPages',
                            style: TextStyle(fontSize: 14, color: Colors.black54),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        SizedBox(height: 20),
                      ] else ...[
                        ElevatedButton(
                          onPressed: () async {
                            String extractedText = await _extractTextFromPdf(context);
                            print('Final navigation check: extractedText.isNotEmpty = ${extractedText.isNotEmpty}');
                            if (extractedText.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ExtractedTextScreen(extractedText: extractedText),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:Colors.blueAccent,
                            foregroundColor:Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            'Extract Text',
                            style: TextStyle(fontSize: 20),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPermissionStatus(String name, bool isGranted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            isGranted ? Icons.check_circle : Icons.cancel,
            color: isGranted ? Colors.green : Colors.red,
            size: 20,
          ),
          SizedBox(width: 8),
          Text('$name: ${isGranted ? 'Granted' : 'Denied'}'),
        ],
      ),
    );
  }
}