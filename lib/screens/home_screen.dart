import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import '../services/firebase_service.dart';
import 'view_all_screen.dart';
import 'smart_scan/smart_scan_home_screen.dart';
import 'extract_text_from_pdf_screen.dart';
import 'text_to_speech_screen.dart';
import 'change_pdf_font_screen.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

class HomeScreen extends StatefulWidget {
  final List<Map<String, dynamic>> recentFiles;
  final Function(List<int>) onFilesDeleted; // Callback to notify MainScreen of deletions
  final Function(Map<String, dynamic>) onFileUploaded; // Callback to add new files

  const HomeScreen({
    Key? key, 
    required this.recentFiles, 
    required this.onFilesDeleted,
    required this.onFileUploaded,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final Set<int> _selectedIndices = {};
  late TabController _tabController;
  int _currentTabIndex = 0;
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Show confirmation dialog before deleting
  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Files'),
        content: Text('Are you sure you want to delete ${_selectedIndices.length} file${_selectedIndices.length == 1 ? '' : 's'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // Cancel
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), // Confirm
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ??
        false; // Default to false if dialog is dismissed
  }

  // Handle PDF upload
  Future<void> _pickPDF() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      
      if (result != null) {
        File file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        final timestamp = DateTime.now().toString();
        
        // Create a new file entry
        Map<String, dynamic> newFile = {
          'name': fileName,
          'path': file.path,
          'timestamp': timestamp,
          'type': 'pdf',
        };
        
        // Add to recent files
        widget.onFileUploaded(newFile);
        
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

  // Handle image upload for Smart Scan
  Future<void> _pickImageForSmartScan(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: source);
      
      if (pickedFile != null) {
        // Navigate to Smart Scan screen with the selected image
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SmartScanHomeScreen(
              onFileUploaded: widget.onFileUploaded,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  // Show image source selection dialog
  Future<void> _showImageSourceDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageForSmartScan(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageForSmartScan(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Handle opening a file when tapped
  Future<void> _openFile(Map<String, dynamic> file) async {
    try {
      // Print file details for debugging
      print('Opening file: ${file.toString()}');
      
      // Get file information with null safety
      final String? fileType = file['type']?.toString();
      final String? downloadUrl = file['downloadUrl']?.toString();
      final String? originalPath = file['originalPath']?.toString();
      final String fileName = file['name']?.toString() ?? 'Unknown File';
      
      print('File type: $fileType');
      print('Download URL: $downloadUrl');
      print('Original path: $originalPath');
      
      if (downloadUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot open file: Download URL not available')),
        );
        return;
      }
      
      // Determine file category based on type or other properties
      bool isPdf = false;
      bool isImage = false;
      
      // Check if it's a PDF file
      if (fileType != null && (
          fileType == 'pdf' || 
          fileType == 'modified_pdfs' || 
          fileType == 'extracted_text_pdfs' ||
          fileType.contains('pdf'))) {
        isPdf = true;
      }
      
      // Check if it's an image file
      if (fileType != null && (
          fileType == 'image' || 
          fileType == 'smart_scan' || 
          fileType == 'scanned_documents' ||
          fileType.contains('image'))) {
        isImage = true;
      }
      
      // If we can't determine the type from the 'type' field, try to guess from other properties
      if (!isPdf && !isImage) {
        if (downloadUrl.toLowerCase().endsWith('.pdf')) {
          isPdf = true;
        } else if (downloadUrl.toLowerCase().contains('.jpg') || 
                  downloadUrl.toLowerCase().contains('.jpeg') || 
                  downloadUrl.toLowerCase().contains('.png')) {
          isImage = true;
        }
      }
      
      // Handle PDF files
      if (isPdf) {
        // Try to open local file if it exists
        if (originalPath != null && await File(originalPath).exists()) {
          print('Opening local PDF file: $originalPath');
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PdfViewerScreen(
                pdfPath: originalPath,
                pdfName: fileName,
                extractedText: file['extractedText']?.toString() ?? '',
              ),
            ),
          );
        } else {
          // Try to download from Firebase
          try {
            print('Local file not found, trying to download from Firebase');
            
            // Show loading indicator
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              },
            );
            
            // Create a temporary file
            final tempDir = await getTemporaryDirectory();
            final tempFile = File('${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.pdf');
            
            // Download the file
            final response = await http.get(Uri.parse(downloadUrl));
            await tempFile.writeAsBytes(response.bodyBytes);
            
            // Close loading dialog
            Navigator.pop(context);
            
            // Open the downloaded file
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PdfViewerScreen(
                  pdfPath: tempFile.path,
                  pdfName: fileName,
                  extractedText: file['extractedText']?.toString() ?? '',
                ),
              ),
            );
          } catch (e) {
            // Close loading dialog if open
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
            
            print('Error downloading PDF: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not download PDF: $e')),
            );
          }
        }
      } 
      // Handle image files
      else if (isImage) {
        print('Opening image file');
        // Show image in a dialog
        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: Text(fileName),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Flexible(
                  child: Image.network(
                    downloadUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / 
                                  (loadingProgress.expectedTotalBytes ?? 1)
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      print('Error loading image: $error');
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error, size: 50, color: Colors.red),
                          const SizedBox(height: 16),
                          Text('Error loading image: $error'),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
                ),
                if (file['extractedText'] != null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Extracted Text: ${file['extractedText']}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
              ],
            ),
          ),
        );
      } 
      // Handle all other file types
      else {
        print('Unknown file type: $fileType');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot determine how to open this file. Please try downloading it directly.'),
            action: SnackBarAction(
              label: 'Details',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('File Details'),
                    content: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Name: $fileName'),
                          Text('Type: ${fileType ?? "Unknown"}'),
                          Text('URL: ${downloadUrl.substring(0, min(30, downloadUrl.length))}...'),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }
    } catch (e) {
      print('Error opening file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('home'),
        backgroundColor: isDark ? Colors.black : const Color(0xFF1E90FF),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: isDark ? Colors.purple : Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.file_copy,), text: 'Files'),
            Tab(icon: Icon(Icons.picture_as_pdf,), text: 'PDF'),
            Tab(icon: Icon(Icons.image), text: 'Smart Scan'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Home Tab with Recent Files
          _buildRecentFilesTab(),
          
          // PDF Upload Tab
          _buildPDFUploadTab(),
          
          // Smart Scan Tab
          _buildSmartScanTab(),
        ],
      ),
    );
  }

  // Tab 1: Recent Files
  Widget _buildRecentFilesTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      color: isDark ? Colors.black : Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recents',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedIndices.length == widget.recentFiles.length) {
                            _selectedIndices.clear(); // Deselect all
                          } else {
                            _selectedIndices.addAll(
                              List.generate(widget.recentFiles.length, (index) => index),
                            ); // Select all
                          }
                        });
                      },
                      child: Text(
                        _selectedIndices.length == widget.recentFiles.length
                            ? 'Deselect All'
                            : 'Select All',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.purple : const Color(0xFF1E90FF),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ViewAllScreen(recentFiles: widget.recentFiles),
                          ),
                        );
                      },
                      child: Text(
                        'View All >',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.purple : const Color(0xFF1E90FF),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: widget.recentFiles.isEmpty
                ? Center(
                    child: Text(
                      'No recent files',
                      style: TextStyle(fontSize: 18, color: isDark ? Colors.white70 : Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.recentFiles.length,
                    itemBuilder: (context, index) {
                      final file = widget.recentFiles[index];
                      final bool isSelected = _selectedIndices.contains(index);
                      
                      // Determine icon based on file type
                      IconData fileIcon;
                      Color iconColor;
                      
                      // Get file type with null safety
                      final String fileType = file['type']?.toString() ?? 'unknown';
                      
                      if (fileType == 'pdf' || fileType == 'modified_pdfs' || fileType == 'extracted_text_pdfs') {
                        fileIcon = Icons.picture_as_pdf;
                        iconColor = isDark ? Colors.purpleAccent : Colors.red;
                      } else if (fileType == 'image' || fileType == 'smart_scan' || fileType == 'scanned_documents') {
                        fileIcon = Icons.image;
                        iconColor = isDark ? Colors.purple : Colors.blue;
                      } else {
                        fileIcon = Icons.insert_drive_file;
                        iconColor = isDark ? Colors.white70 : Colors.grey;
                      }
                      
                      // Get file name and timestamp with null safety
                      final String fileName = file['name']?.toString() ?? 'Unnamed File';
                      final String timestamp = file['timestamp']?.toString() ?? 'Unknown date';
                      
                      // Format the timestamp to be more readable
                      String formattedDate = 'Unknown date';
                      try {
                        if (timestamp != 'Unknown date') {
                          final DateTime dateTime = DateTime.parse(timestamp);
                          formattedDate = '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
                        }
                      } catch (e) {
                        print('Error formatting date: $e');
                      }
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        elevation: 2,
                        color: isDark ? Colors.black : null,
                        child: ListTile(
                          leading: Icon(fileIcon, color: iconColor, size: 36),
                          title: Text(
                            fileName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : null,
                            ),
                          ),
                          subtitle: Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.grey[600],
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle,
                                  color: isDark ? Colors.purpleAccent : const Color(0xFF1E90FF),
                                )
                              : Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                  color: isDark ? Colors.white54 : Colors.grey,
                                ),
                          onTap: () {
                            if (_isSelectionMode) {
                              setState(() {
                                if (isSelected) {
                                  _selectedIndices.remove(index);
                                } else {
                                  _selectedIndices.add(index);
                                }
                              });
                            } else {
                              // Open the file
                              _openFile(file);
                            }
                          },
                          onLongPress: () {
                            setState(() {
                              if (!_isSelectionMode) {
                                _isSelectionMode = true;
                                _selectedIndices.add(index);
                              } else {
                                if (isSelected) {
                                  _selectedIndices.remove(index);
                                } else {
                                  _selectedIndices.add(index);
                                }
                              }
                            });
                          },
                        ),
                      );
                    },
                  ),
          ),
          if (widget.recentFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      if (_selectedIndices.isNotEmpty) {
                        List<Map<String, dynamic>> selectedFiles = _selectedIndices
                            .map((index) => widget.recentFiles[index])
                            .toList();
                        String shareText = 'Selected Files:\n${selectedFiles.map((f) => f['name']).join('\n')}';
                        Share.share(shareText);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select at least one file to share')),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.purple : const Color(0xFF1E90FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Share', style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                  if (_selectedIndices.isNotEmpty) // Show Delete button only if files are selected
                    ElevatedButton(
                      onPressed: () async {
                        bool confirm = await _confirmDelete(context);
                        if (confirm) {
                          widget.onFilesDeleted(_selectedIndices.toList());
                          setState(() {
                            _selectedIndices.clear(); // Clear selection after deletion
                            _isSelectionMode = false;
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Delete', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Tab 2: PDF Upload
  Widget _buildPDFUploadTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      color: isDark ? Colors.black : Colors.white,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              const SizedBox(height: 20),
              
              // Extract Text from PDF Card
              Card(
                elevation: 3,
                color: isDark ? Colors.black : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isDark ? BorderSide(color: Colors.purple.withOpacity(0.5), width: 1) : BorderSide.none,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.text_snippet,
                        size: 40,
                        color: isDark ? Colors.purple : Colors.blue,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Extract Text from PDF',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : null,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Extract and save text content from PDF documents',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 15),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ExtractTextFromPdfScreen(onFileUploaded: widget.onFileUploaded),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.purple : Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Extract Text'),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Text to Speech Card
              Card(
                elevation: 3,
                color: isDark ? Colors.black : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isDark ? BorderSide(color: Colors.purple.withOpacity(0.5), width: 1) : BorderSide.none,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.record_voice_over,
                        size: 40,
                        color: isDark ? Colors.purpleAccent : Colors.green,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Text to Speech',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : null,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Convert PDF text to speech for easier comprehension',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 15),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TextToSpeechScreen(extractedText: ''),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.purple : Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Text to Speech'),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Change PDF Font Card
              Card(
                elevation: 3,
                color: isDark ? Colors.black : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isDark ? BorderSide(color: Colors.purple.withOpacity(0.5), width: 1) : BorderSide.none,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.font_download,
                        size: 40,
                        color: isDark ? Colors.purpleAccent : Colors.redAccent,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Change PDF Font',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : null,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Customize PDF fonts for better readability',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 15),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChangePdfFontScreen(onFileUploaded: widget.onFileUploaded),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? Colors.purple : Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Change Font'),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Tab 3: Smart Scan
  Widget _buildSmartScanTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      color: isDark ? Colors.black : Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.document_scanner,
              size: 100,
              color: isDark ? Colors.purple : Colors.blue,
            ),
            const SizedBox(height: 20),
            Text(
              'Smart Scan',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Scan documents and extract text with advanced handwriting recognition',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.grey,
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImageForSmartScan(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.purple : Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                ElevatedButton.icon(
                  onPressed: () => _pickImageForSmartScan(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.purple : Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}