import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/pdf_font_service.dart';
import '../services/file_service.dart';
import '../services/pdf_firebase_service.dart';

class ChangePdfFontScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onFileUploaded;

  const ChangePdfFontScreen({Key? key, required this.onFileUploaded}) : super(key: key);

  @override
  _ChangePdfFontScreenState createState() => _ChangePdfFontScreenState();
}

class _ChangePdfFontScreenState extends State<ChangePdfFontScreen> {
  bool _isLoading = false;
  double _progressValue = 0.0;
  String _statusMessage = '';
  String? _outputFilePath;
  String? _inputFileName;
  String _extractedText = '';
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  
  // Font selection options
  String _selectedFont = 'Arial';
  double _fontSize = 14.0;
  double _wordSpacing = 0.0;
  double _letterSpacing = 0.0;
  double _lineSpacing = 1.0;
  
  // Available font options
  final List<String> _availableFonts = const [
    'Arial',
    'OpenDyslexic',
    'Comic Sans',
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _speak(String text) async {
    if (text.isNotEmpty) {
      setState(() {
        _isSpeaking = true;
      });
      await _flutterTts.speak(text);
      setState(() {
        _isSpeaking = false;
      });
    }
  }

  Future<void> _stop() async {
    await _flutterTts.stop();
    setState(() {
      _isSpeaking = false;
    });
  }

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required to access PDF files. Please enable it in app settings.'),
            duration: Duration(seconds: 5),
          ),
        );
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<void> _changePdfFont() async {
    try {
      _initializeLoading();
      
      // Show a message to indicate we're starting
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Starting PDF font conversion process...')),
      );

      // Check and request permissions first
      setState(() {
        _statusMessage = 'Checking permissions...';
        _progressValue = 0.1;
      });
      
      bool permissionsGranted = await _checkAndRequestPermissions(context);
      if (!permissionsGranted) {
        _handlePermissionDenied();
        return;
      }
      
      // Update status before picking file
      setState(() {
        _statusMessage = 'Opening file picker...';
        _progressValue = 0.2;
      });

      // Pick PDF file
      final filePickerResult = await FileService.pickPdfFile();
      if (filePickerResult == null) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'No file selected';
          _progressValue = 0.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No PDF file was selected')),
        );
        return;
      }

      // Get file name
      _inputFileName = filePickerResult.files.first.name;
      setState(() {
        _statusMessage = 'Processing file: $_inputFileName';
        _progressValue = 0.3;
      });

      // Get file bytes
      List<int>? fileBytes = await FileService.getFileBytes(filePickerResult, context);
      if (fileBytes == null) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Failed to read file';
          _progressValue = 0.0;
        });
        return;
      }
      
      // Process the PDF
      await _processPdf(fileBytes);
    } catch (e) {
      _handleError(e);
    }
  }

  void _initializeLoading() {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Initializing...';
      _progressValue = 0.0;
      _outputFilePath = null;
    });
  }

  void _handlePermissionDenied() {
    setState(() {
      _isLoading = false;
      _statusMessage = 'Permission denied';
      _progressValue = 0.0;
    });
  }

  Future<void> _processPdf(List<int> fileBytes) async {
    try {
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
      
      // Create output file path
      final outputFilePath = '$tempPath/output_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      setState(() {
        _statusMessage = 'Changing font to $_selectedFont...';
        _progressValue = 0.7;
      });
      
      // Use the PdfFontService to change the font
      final pdfFontService = PdfFontService();
      final success = await pdfFontService.changePdfFont(
        inputFilePath: inputFilePath,
        outputFilePath: outputFilePath,
        fontName: _selectedFont,
        fontSize: _fontSize,
        wordSpacing: _wordSpacing,
        letterSpacing: _letterSpacing,
        lineSpacing: _lineSpacing,
      );
      
      if (!success) {
        throw Exception('Failed to change PDF font');
      }
      
      // Extract text from the PDF for text-to-speech
      final pdfDocument = PdfDocument(inputBytes: fileBytes);
      final pdfTextExtractor = PdfTextExtractor(pdfDocument);
      _extractedText = pdfTextExtractor.extractText();
      pdfDocument.dispose();
      
      // Upload the modified PDF to Firebase
      try {
        setState(() {
          _statusMessage = 'Uploading to Firebase...';
          _progressValue = 0.9;
        });
        
        final pdfFirebaseService = PdfFirebaseService();
        final result = await pdfFirebaseService.uploadModifiedPdf(
          pdfFile: File(outputFilePath),
          originalFileName: _inputFileName ?? 'Unknown',
          selectedFont: _selectedFont,
          fontSize: _fontSize,
          wordSpacing: _wordSpacing,
          letterSpacing: _letterSpacing,
          lineSpacing: _lineSpacing,
          context: context,
        );
        
        debugPrint('PDF uploaded to Firebase: ${result['downloadUrl']}');
        
        // Call the onFileUploaded callback with the result
        widget.onFileUploaded({
          'name': result['fileName'],
          'timestamp': DateTime.now().toString(),
          'downloadUrl': result['downloadUrl'],
          'type': 'modified_pdf',
          'font': _selectedFont,
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF uploaded to Firebase successfully')),
        );
      } catch (firebaseError) {
        debugPrint('Error uploading to Firebase: $firebaseError');
        // Continue with the process even if Firebase upload fails
      }
      
      setState(() {
        _outputFilePath = outputFilePath;
        _isLoading = false;
        _statusMessage = 'Font changed successfully!';
        _progressValue = 1.0;
      });
      
      // Navigate to the PDF viewer screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfViewerScreen(
              pdfPath: outputFilePath,
              pdfName: _inputFileName!.replaceAll('.pdf', '_converted.pdf'),
              extractedText: _extractedText,
            ),
          ),
        );
      }
    } catch (e) {
      _handleError(e);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change PDF Font'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Font selection
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Font Options',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Font family dropdown
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Font Family',
                          border: OutlineInputBorder(),
                        ),
                        value: _selectedFont,
                        items: _availableFonts.map((String font) {
                          return DropdownMenuItem<String>(
                            value: font,
                            child: Text(font),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedFont = newValue;
                            });
                          }
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Font size slider
                      Text(
                        'Font Size: ${_fontSize.toStringAsFixed(1)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Slider(
                        value: _fontSize,
                        min: 8.0,
                        max: 24.0,
                        divisions: 16,
                        label: _fontSize.toStringAsFixed(1),
                        onChanged: (double value) {
                          setState(() {
                            _fontSize = value;
                          });
                        },
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Word spacing slider
                      Text(
                        'Word Spacing: ${_wordSpacing.toStringAsFixed(1)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Slider(
                        value: _wordSpacing,
                        min: 0.0,
                        max: 10.0,
                        divisions: 10,
                        label: _wordSpacing.toStringAsFixed(1),
                        onChanged: (double value) {
                          setState(() {
                            _wordSpacing = value;
                          });
                        },
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Letter spacing slider
                      Text(
                        'Letter Spacing: ${_letterSpacing.toStringAsFixed(1)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Slider(
                        value: _letterSpacing,
                        min: 0.0,
                        max: 5.0,
                        divisions: 10,
                        label: _letterSpacing.toStringAsFixed(1),
                        onChanged: (double value) {
                          setState(() {
                            _letterSpacing = value;
                          });
                        },
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Line spacing slider
                      Text(
                        'Line Spacing: ${_lineSpacing.toStringAsFixed(1)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Slider(
                        value: _lineSpacing,
                        min: 1.0,
                        max: 3.0,
                        divisions: 10,
                        label: _lineSpacing.toStringAsFixed(1),
                        onChanged: (double value) {
                          setState(() {
                            _lineSpacing = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Preview section
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Preview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Text(
                          'This is a preview of how your text will look with the selected font and spacing options.',
                          style: TextStyle(
                            fontFamily: _selectedFont == 'OpenDyslexic' 
                                ? 'OpenDyslexic' 
                                : (_selectedFont == 'Comic Sans' ? 'Comic Sans MS' : null),
                            fontSize: _fontSize,
                            letterSpacing: _letterSpacing,
                            wordSpacing: _wordSpacing,
                            height: _lineSpacing,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Processing status
              if (_isLoading)
                Column(
                  children: [
                    LinearProgressIndicator(value: _progressValue),
                    const SizedBox(height: 8),
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              
              const SizedBox(height: 16),
              
              // Action buttons
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('Select PDF File'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _isLoading ? null : _changePdfFont,
              ),
              
              const SizedBox(height: 8),
              
              if (_outputFilePath != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.visibility),
                        label: const Text('View PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PdfViewerScreen(
                                pdfPath: _outputFilePath!,
                                pdfName: _inputFileName!.replaceAll('.pdf', '_converted.pdf'),
                                extractedText: _extractedText,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.share),
                        label: const Text('Share PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        onPressed: () {
                          Share.shareXFiles(
                            [XFile(_outputFilePath!)],
                            text: 'Sharing converted PDF',
                          );
                        },
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// PDF Viewer Screen
class PdfViewerScreen extends StatefulWidget {
  final String pdfPath;
  final String pdfName;
  final String extractedText;

  const PdfViewerScreen({
    Key? key,
    required this.pdfPath,
    required this.pdfName,
    required this.extractedText,
  }) : super(key: key);

  @override
  _PdfViewerScreenState createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  int? _totalPages;
  int? _currentPage;
  double _zoomLevel = 1.0;
  bool _isLoading = true;
  bool _isSpeaking = false;
  final FlutterTts _flutterTts = FlutterTts();
  List<String> _textChunks = [];
  int _currentChunkIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _checkFile();
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    
    _flutterTts.setCompletionHandler(() {
      if (_currentChunkIndex < _textChunks.length - 1) {
        _currentChunkIndex++;
        _speak(_textChunks[_currentChunkIndex]);
      } else {
        setState(() {
          _isSpeaking = false;
          _currentChunkIndex = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  void _zoomIn() {
    setState(() {
      _zoomLevel = _zoomLevel + 0.1;
      if (_zoomLevel > 3.0) {
        _zoomLevel = 3.0;
      }
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomLevel = _zoomLevel - 0.1;
      if (_zoomLevel < 0.5) {
        _zoomLevel = 0.5;
      }
    });
  }

  Future<void> _speak(String text) async {
    if (text.isNotEmpty) {
      setState(() {
        _isSpeaking = true;
      });
      await _flutterTts.speak(text);
    }
  }

  Future<void> _stop() async {
    await _flutterTts.stop();
    setState(() {
      _isSpeaking = false;
      _currentChunkIndex = 0;
    });
  }

  List<String> _splitTextIntoChunks(String text, int chunkSize) {
    List<String> chunks = [];
    for (int i = 0; i < text.length; i += chunkSize) {
      chunks.add(text.substring(i, i + chunkSize < text.length ? i + chunkSize : text.length));
    }
    return chunks;
  }

  Future<void> _checkFile() async {
    try {
      final file = File(widget.pdfPath);
      if (await file.exists()) {
        setState(() {
          _isLoading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF file not found')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pdfName),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(_isSpeaking ? Icons.stop : Icons.volume_up),
            onPressed: () {
              if (_isSpeaking) {
                _stop();
              } else {
                if (widget.extractedText.isNotEmpty) {
                  _textChunks = _splitTextIntoChunks(widget.extractedText, 4000);
                  _currentChunkIndex = 0;
                  _speak(_textChunks[_currentChunkIndex]);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No text available to read')),
                  );
                }
              }
            },
            tooltip: _isSpeaking ? 'Stop Reading' : 'Read Aloud',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              Share.shareXFiles(
                [XFile(widget.pdfPath)],
                text: 'Sharing PDF file',
              );
            },
            tooltip: 'Share PDF',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                PDFView(
                  filePath: widget.pdfPath,
                  enableSwipe: true,
                  swipeHorizontal: true,
                  autoSpacing: true,
                  pageFling: true,
                  pageSnap: true,
                  defaultPage: 0,
                  fitPolicy: FitPolicy.BOTH,
                  preventLinkNavigation: false,
                  onRender: (pages) {
                    setState(() {
                      _totalPages = pages;
                      _isLoading = false;
                    });
                  },
                  onError: (error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $error')),
                    );
                  },
                  onPageError: (page, error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error on page $page: $error')),
                    );
                  },
                  onViewCreated: (PDFViewController pdfViewController) {
                    // PDF view created
                  },
                  onPageChanged: (int? page, int? total) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                ),
                
                // Bottom toolbar
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    color: Colors.white.withOpacity(0.9),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Zoom controls
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Size:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.remove, size: 18),
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                visualDensity: VisualDensity.compact,
                                onPressed: _zoomOut,
                              ),
                              Text('${(_zoomLevel * 100).toInt()}%', style: const TextStyle(fontSize: 12)),
                              IconButton(
                                icon: const Icon(Icons.add, size: 18),
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                visualDensity: VisualDensity.compact,
                                onPressed: _zoomIn,
                              ),
                            ],
                          ),
                        ),
                        
                        // Divider
                        SizedBox(
                          height: 24,
                          child: VerticalDivider(
                            color: Colors.grey[300],
                            thickness: 1,
                            width: 16,
                          ),
                        ),
                        
                        // Page indicator
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Page:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 4),
                              Text(
                                _totalPages != null 
                                    ? '${(_currentPage ?? 0) + 1}/$_totalPages' 
                                    : 'Loading...',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        
                        // Divider
                        SizedBox(
                          height: 24,
                          child: VerticalDivider(
                            color: Colors.grey[300],
                            thickness: 1,
                            width: 16,
                          ),
                        ),
                        
                        // Text-to-speech button
                        ElevatedButton.icon(
                          icon: Icon(_isSpeaking ? Icons.stop : Icons.volume_up, size: 16),
                          label: Text(_isSpeaking ? 'Stop' : 'Read', style: const TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: const Size(70, 30),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () {
                            if (_isSpeaking) {
                              _stop();
                            } else {
                              if (widget.extractedText.isNotEmpty) {
                                _textChunks = _splitTextIntoChunks(widget.extractedText, 4000);
                                _currentChunkIndex = 0;
                                _speak(_textChunks[_currentChunkIndex]);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('No text available to read')),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
