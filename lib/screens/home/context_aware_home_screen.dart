import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../view_all_screen.dart';
import 'file_operations.dart';
import 'file_handler.dart';
import '../text_to_speech_screen.dart';
import '../change_pdf_font_screen.dart';
import '../extract_text_from_pdf_screen.dart';
import '../smart_scan/smart_scan_home_screen.dart';
import 'package:flutter/services.dart';

class ContextAwareHomeScreen extends StatefulWidget {
  final List<Map<String, dynamic>> recentFiles;
  final Function(List<int>) onFilesDeleted;
  final Function(Map<String, dynamic>) onFileUploaded;

  const ContextAwareHomeScreen({
    Key? key,
    required this.recentFiles,
    required this.onFilesDeleted,
    required this.onFileUploaded,
  }) : super(key: key);

  @override
  State<ContextAwareHomeScreen> createState() => _ContextAwareHomeScreenState();
}

class _ContextAwareHomeScreenState extends State<ContextAwareHomeScreen> {
  // Helper classes
  late FileOperations _fileOperations;
  late FileHandler _fileHandler;
  
  // Track which upload path is selected
  String _selectedPath = ''; // Empty means no selection yet

  @override
  void initState() {
    super.initState();
    
    // Initialize helper classes
    _fileOperations = FileOperations(
      context: context,
      onFileUploaded: widget.onFileUploaded,
    );
    
    _fileHandler = FileHandler(
      context: context,
      onFileUploaded: widget.onFileUploaded,
    );
  }

  // Pick PDF file
  Future<void> _pickPDF() async {
    await _fileOperations.pickPDF();
  }

  // Pick image for smart scan
  Future<void> _pickImageForSmartScan(ImageSource source) async {
    await _fileOperations.pickImageForSmartScan(source);
  }
  
  // Show scan options dialog
  void _showScanOptions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choose Scan Method'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImageForSmartScan(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImageForSmartScan(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Open file
  Future<void> _openFile(Map<String, dynamic> file) async {
    await _fileHandler.openFile(file);
  }

  // Reset selection to go back to main choice
  void _resetSelection() {
    setState(() {
      _selectedPath = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sightline'),
        // Show back button when a path is selected
        leading: _selectedPath.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _resetSelection,
              )
            : null,
      ),
      body: SafeArea(
        child: _buildBody(isDark),
      ),
      resizeToAvoidBottomInset: true,
    );
  }

  Widget _buildBody(bool isDark) {
    // If no path is selected, show the main choice screen
    if (_selectedPath.isEmpty) {
      return _buildPathSelectionScreen(isDark);
    }
    
    // Show PDF tools if PDF path is selected
    if (_selectedPath == 'pdf') {
      return _buildPdfToolsScreen(isDark);
    }
    
    // Show image tools if image path is selected
    if (_selectedPath == 'image') {
      return _buildImageToolsScreen(isDark);
    }
    
    // Fallback
    return const SizedBox.shrink();
  }

  Widget _buildPathSelectionScreen(bool isDark) {
    return Container(
      color: isDark ? Colors.black : Colors.grey[50],
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text(
                'What would you like to do?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              // PDF Card
              _buildChoiceCard(
                context: context,
                icon: Icons.picture_as_pdf,
                title: 'Work with PDF',
                description: 'Upload a PDF file to read, modify or convert to speech',
                color: isDark ? const Color(0xFFC62828) : const Color(0xFFE53935), // Red for PDF
                gradientColor: isDark ? const Color(0xFFB71C1C) : const Color(0xFFD32F2F),
                onPressed: () {
                  setState(() {
                    _selectedPath = 'pdf';
                  });
                },
              ),
              
              const SizedBox(height: 20),
              
              // Image Card
              _buildChoiceCard(
                context: context,
                icon: Icons.image,
                title: 'Work with Image',
                description: 'Scan documents or upload images for text recognition',
                color: isDark ? const Color(0xFF00796B) : const Color(0xFF009688), // Teal for Image
                gradientColor: isDark ? const Color(0xFF004D40) : const Color(0xFF00796B),
                onPressed: () {
                  setState(() {
                    _selectedPath = 'image';
                  });
                },
              ),
              // Add padding at bottom to avoid overflow
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPdfToolsScreen(bool isDark) {
    return Container(
      color: isDark ? Colors.black : Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // PDF Tools Section
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Text(
                  'PDF Tools',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              
              // Text to Speech Card
              _buildLargeToolCard(
                context: context,
                icon: Icons.record_voice_over,
                title: 'Text to Speech',
                description: 'Convert PDF text to speech with customizable voice options',
                color: isDark ? const Color(0xFF1A237E) : const Color(0xFF3F51B5),
                gradientColor: isDark ? const Color(0xFF0D1642) : const Color(0xFF303F9F),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TextToSpeechScreen(
                        extractedText: '',
                        onFileUploaded: widget.onFileUploaded,
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 24),
              
              // Change Font Card
              _buildLargeToolCard(
                context: context,
                icon: Icons.font_download,
                title: 'Change Font',
                description: 'Modify PDF fonts for better readability, including OpenDyslexic and Comic Sans',
                color: isDark ? const Color(0xFF006064) : const Color(0xFF00BCD4),
                gradientColor: isDark ? const Color(0xFF00363a) : const Color(0xFF0097A7),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChangePdfFontScreen(
                        onFileUploaded: widget.onFileUploaded,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageToolsScreen(bool isDark) {
    return Container(
      color: isDark ? Colors.black : Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Image Tools Section
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Text(
                  'Smart Scan',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              
              // Smart Scan Card - Larger version to fill screen
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SmartScanHomeScreen(
                          onFileUploaded: widget.onFileUploaded,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    height: 200, // Reduced height to prevent overflow
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          isDark ? const Color(0xFF4A148C) : const Color(0xFF9C27B0),
                          isDark ? const Color(0xFF12005E) : const Color(0xFF7B1FA2),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.document_scanner,
                              color: Colors.white,
                              size: 40, // Smaller icon
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Scan Document',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Scan documents and extract text with advanced recognition',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _showScanOptions,
                                  icon: const Icon(Icons.camera_alt, size: 18),
                                  label: const Text('Start Scanning'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: isDark ? const Color(0xFF4A148C) : const Color(0xFF9C27B0),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
                ))],
          ),
        ),
      ),
    );
  }

  // Bottom navigation bar has been removed as requested

  Widget _buildLargeToolCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required Color gradientColor,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 8,
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          height: 150, // Balanced height that fits well on screen
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, gradientColor],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward,
                  color: Colors.white.withOpacity(0.7),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required Color gradientColor,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 8,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          height: 160, // Reduced height to avoid overflow
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, gradientColor],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0), // Reduced padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10), // Reduced padding
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: Colors.white, size: 28), // Smaller icon
                    ),
                    const SizedBox(width: 12), // Reduced spacing
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20, // Smaller font
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12), // Reduced spacing
                Expanded(
                  child: Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14, // Smaller font
                    ),
                    maxLines: 3, // Limit lines
                    overflow: TextOverflow.ellipsis, // Handle overflow text
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Icon(
                    Icons.arrow_forward,
                    color: Colors.white.withOpacity(0.7),
                    size: 20, // Smaller icon
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadSection({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required String title,
    required String description,
    required String buttonText,
    required VoidCallback onUpload,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 50,
            color: isDark ? Colors.purple : Colors.blue,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.grey,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onUpload,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.purple : Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required Color gradientColor,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 6,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          height: 120, // Fixed height to prevent overflow
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, gradientColor],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0), // Reduced padding
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  color: Colors.white.withOpacity(0.7),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
