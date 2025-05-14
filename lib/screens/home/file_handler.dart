import 'dart:io';
import 'package:flutter/material.dart';
import '../text_to_speech_screen.dart';
import '../change_pdf_font_screen.dart';
import '../extract_text_from_pdf_screen.dart';
import '../../services/pdf_extraction_service.dart';

/// Class that handles file opening and processing
class FileHandler {
  final BuildContext context;
  final Function(Map<String, dynamic>) onFileUploaded;
  final PdfExtractionService pdfExtractionService = PdfExtractionService();

  FileHandler({
    required this.context,
    required this.onFileUploaded,
  });

  /// Open a file and show options
  Future<void> openFile(Map<String, dynamic> file) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final String? filePath = file['path'];
    
    if (filePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File path not found')),
      );
      return;
    }
    
    final File fileToOpen = File(filePath);
    if (!await fileToOpen.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found on device')),
      );
      return;
    }
    
    // Show bottom sheet with options
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildFileOptionsSheet(context, file, isDark),
    );
  }

  Widget _buildFileOptionsSheet(BuildContext context, Map<String, dynamic> file, bool isDark) {
    final String fileName = file['name'] ?? 'Unnamed File';
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // File name and close button
          Row(
            children: [
              Expanded(
                child: Text(
                  fileName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          
          const Divider(),
          
          // Options
          _buildOptionTile(
            context: context,
            icon: Icons.text_fields,
            title: 'Extract Text',
            subtitle: 'Extract text content from this PDF',
            onTap: () => _extractText(file),
            isDark: isDark,
          ),
          
          _buildOptionTile(
            context: context,
            icon: Icons.record_voice_over,
            title: 'Text to Speech',
            subtitle: 'Convert PDF text to speech',
            onTap: () => _textToSpeech(file),
            isDark: isDark,
          ),
          
          _buildOptionTile(
            context: context,
            icon: Icons.font_download,
            title: 'Change Font',
            subtitle: 'Change the font of this PDF',
            onTap: () => _changeFont(file),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDark ? Colors.white : Colors.blue,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isDark ? Colors.white70 : Colors.black54,
        ),
      ),
      onTap: () {
        Navigator.pop(context); // Close bottom sheet
        onTap();
      },
    );
  }

  // Extract text from PDF
  Future<void> _extractText(Map<String, dynamic> file) async {
    final String? filePath = file['path'];
    if (filePath == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExtractTextFromPdfScreen(
          onFileUploaded: onFileUploaded,
        ),
      ),
    );
  }

  // Text to speech
  Future<void> _textToSpeech(Map<String, dynamic> file) async {
    final String? filePath = file['path'];
    final String? extractedText = file['text'] ?? '';
    if (filePath == null) return;
    
    // Use the static method from PdfExtractionService to get text
    String text = extractedText ?? '';
    
    // If we don't have extracted text already, try to extract it
    if (text.isEmpty) {
      // Show a loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Extracting text from PDF...')),
      );
      
      // Use the extractTextFromPdf method
      final result = await PdfExtractionService.extractTextFromPdf(context);
      if (result != null && result.containsKey('content')) {
        text = result['content'] as String;
      }
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TextToSpeechScreen(
          extractedText: text,
          onFileUploaded: onFileUploaded,
        ),
      ),
    );
  }

  // Change font
  Future<void> _changeFont(Map<String, dynamic> file) async {
    final String? filePath = file['path'];
    if (filePath == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChangePdfFontScreen(
          onFileUploaded: onFileUploaded,
        ),
      ),
    );
  }
}
