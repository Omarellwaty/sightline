import 'package:flutter/material.dart';
import '../text_to_speech_screen.dart';
import '../change_pdf_font_screen.dart';
import '../extract_text_from_pdf_screen.dart';

class PdfUploadTab extends StatelessWidget {
  final Function() pickPDF;
  final Function(Map<String, dynamic>) onFileUploaded;

  const PdfUploadTab({
    Key? key,
    required this.pickPDF,
    required this.onFileUploaded,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      color: isDark ? Colors.black : Colors.white,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // PDF Tools Section
              _buildPdfToolsSection(context, isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadSection(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.upload_file,
            size: 80,
            color: isDark ? Colors.purple : Colors.blue,
          ),
          const SizedBox(height: 20),
          Text(
            'Upload PDF',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Select a PDF file to upload and process',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white70 : Colors.grey,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: pickPDF,
            icon: const Icon(Icons.file_upload),
            label: const Text('Choose PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.purple : Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfToolsSection(BuildContext context, bool isDark) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
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
        _buildToolCard(
          context: context,
          icon: Icons.record_voice_over,
          title: 'Text to Speech',
          description: 'Convert PDF text to speech with customizable voice options',
          color: isDark ? Color(0xFF1A237E) : Color(0xFF3F51B5), // Indigo shades
          gradientColor: isDark ? Color(0xFF0D1642) : Color(0xFF303F9F),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TextToSpeechScreen(
                  extractedText: '', // Providing an empty string as initial text
                  onFileUploaded: onFileUploaded,
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 20),
        
        // Change Font Card
        _buildToolCard(
          context: context,
          icon: Icons.font_download,
          title: 'Change Font',
          description: 'Modify PDF fonts for better readability, including OpenDyslexic and Comic Sans',
          color: isDark ? Color(0xFF006064) : Color(0xFF00BCD4), // Cyan/Teal shades
          gradientColor: isDark ? Color(0xFF00363a) : Color(0xFF0097A7),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChangePdfFontScreen(
                  onFileUploaded: onFileUploaded,
                ),
              ),
            );
          },
        ),
      ],
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, gradientColor],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white.withOpacity(0.7),
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Open',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
