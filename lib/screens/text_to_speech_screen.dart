import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'extract_text_from_pdf_screen.dart';
import '../controllers/text_to_speech_controller.dart';
import '../models/text_to_speech_model.dart';
import '../services/storage_service.dart';
import '../services/database_service.dart';

/// View class for Text-to-Speech feature
/// Handles all UI presentation and user interaction
class TextToSpeechScreen extends StatefulWidget {
  final String extractedText;
  
  TextToSpeechScreen({required this.extractedText});

  @override
  _TextToSpeechScreenState createState() => _TextToSpeechScreenState();
}

class _TextToSpeechScreenState extends State<TextToSpeechScreen> {
  // Controller instance to handle all TTS logic
  late TextToSpeechController _controller;
  final StorageService _storageService = StorageService();
  final DatabaseService _databaseService = DatabaseService();
  // Use a temporary user ID for testing - in a real app, you'd get this from authentication
  final String _userId = 'user_${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _controller = TextToSpeechController();
    _initializeTts();
    
    // Set initial text if provided
    if (widget.extractedText.isNotEmpty) {
      _controller.model.textController.text = widget.extractedText;
    }
    
    // Add listener for speak-as-you-type functionality
    _controller.model.textController.addListener(() {
      _controller.onTextChanged();
    });
  }

  Future<void> _initializeTts() async {
    await _controller.initTts(context);
    setState(() {}); // Refresh UI after initialization
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _importPdf() async {
    try {
      // Navigate to the PDF extraction screen
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExtractTextFromPdfScreen(
            onFileUploaded: (data) async {
              // This callback will be called when a file is uploaded
              return data;
            },
          ),
        ),
      );
      
      // Check if we have valid data
      if (result != null && result is Map<String, dynamic>) {
        // Extract text content
        final String extractedText = result['content'] ?? '';
        
        // If we have a file path, upload to Firebase
        if (result['pdfPath'] != null && result['pdfPath'] is String) {
          try {
            setState(() {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Uploading PDF to cloud storage...')),
              );
            });
            
            // Upload file to Firebase Storage
            final File pdfFile = File(result['pdfPath']);
            final String? downloadURL = await _storageService.uploadFile(pdfFile, _userId);
            
            // Only save to Firestore if we got a valid download URL
            if (downloadURL != null) {
              // Save metadata to Firestore
              await _databaseService.saveFileData(
                userId: _userId,
                fileName: result['name'] ?? 'document.pdf',
                downloadURL: downloadURL,
              );
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('PDF uploaded to cloud storage successfully')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to upload PDF to cloud storage')),
              );
            }
          } catch (e) {
            print('Error uploading to Firebase: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error uploading to cloud: $e')),
            );
          }
        }
        
        // If text was extracted and returned, update the text controller
        if (extractedText.isNotEmpty) {
          setState(() {
            _controller.model.textController.text = extractedText;
          });
        }
      }
    } catch (e) {
      print('Error importing PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text to Speech'),
        backgroundColor: isDark ? Colors.black : Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: isDark ? Colors.black : null,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Text input field
              TextField(
                controller: _controller.model.textController,
                maxLines: 5,
                style: TextStyle(color: isDark ? Colors.white : null),
                decoration: InputDecoration(
                  hintText: 'Enter text to speak',
                  hintStyle: TextStyle(color: isDark ? Colors.white70 : null),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(color: isDark ? Colors.purple : Colors.grey),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(color: isDark ? Colors.purple.withOpacity(0.5) : Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: BorderSide(color: isDark ? Colors.purple : Colors.blue),
                  ),
                ),
              ),
              
              const SizedBox(height: 16.0),
              
              // Speak-as-you-type toggle
              Row(
                children: [
                  Text(
                    'Speak as you type:',
                    style: TextStyle(color: isDark ? Colors.white : null),
                  ),
                  Switch(
                    value: _controller.model.speakAsYouType,
                    onChanged: (value) {
                      setState(() {
                        _controller.model.setSpeakAsYouType(value);
                      });
                    },
                    activeColor: isDark ? Colors.purple : Colors.blue,
                  ),
                ],
              ),
              
              const SizedBox(height: 16.0),
              
              // Import PDF button
              ElevatedButton(
                onPressed: _importPdf,
                child: const Text('Import from PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.purple : Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            
            const SizedBox(height: 16.0),
            
            // Playback controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Play/Pause button
                ElevatedButton.icon(
                  onPressed: () async {
                    bool success = await _controller.speak(context);
                    if (success) {
                      setState(() {});
                    }
                  },
                  icon: Icon(_controller.model.isPlaying ? Icons.pause : Icons.play_arrow),
                  label: Text(_controller.model.isPlaying ? 'Pause' : 'Play'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:Colors.blueAccent,
                    foregroundColor:Colors.white,
                  ),
                ),
                
                // Stop button
                ElevatedButton.icon(
                  onPressed: () async {
                    await _controller.stop();
                    setState(() {});
                  },
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:Colors.red,
                    foregroundColor:Colors.white,
                  ),
                ),
                
                // Clear button
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _controller.model.textController.clear();
                    });
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24.0),
            
            // Language selection
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Language',
                border: OutlineInputBorder(),
              ),
              value: _controller.model.selectedLanguage,
              items: _controller.model.languages.map((String language) {
                return DropdownMenuItem<String>(
                  value: language,
                  child: Text(_controller.model.getLanguageDisplayName(language)),
                );
              }).toList(),
              onChanged: (String? newValue) async {
                if (newValue != null) {
                  await _controller.setLanguage(newValue);
                  setState(() {});
                }
              },
            ),
            
            const SizedBox(height: 16.0),
            
            // Volume slider
            Row(
              children: [
                Text(
                  'Volume:',
                  style: TextStyle(color: isDark ? Colors.white : null),
                ),
                Expanded(
                  child: Slider(
                    value: _controller.model.volume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    label: _controller.model.volumeFormatted,
                    activeColor: isDark ? Colors.purple : null,
                    thumbColor: isDark ? Colors.purpleAccent : null,
                    onChanged: (double value) async {
                      await _controller.setVolume(value);
                      setState(() {});
                    },
                  ),
                ),
                Text(
                  _controller.model.volumeFormatted,
                  style: TextStyle(color: isDark ? Colors.white : null),
                ),
              ],
            ),
            
            // Pitch slider
            Row(
              children: [
                Text(
                  'Pitch:',
                  style: TextStyle(color: isDark ? Colors.white : null),
                ),
                Expanded(
                  child: Slider(
                    value: _controller.model.pitch,
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    label: _controller.model.pitchFormatted,
                    activeColor: isDark ? Colors.purple : null,
                    thumbColor: isDark ? Colors.purpleAccent : null,
                    onChanged: (double value) async {
                      await _controller.setPitch(value);
                      setState(() {});
                    },
                  ),
                ),
                Text(
                  _controller.model.pitchFormatted,
                  style: TextStyle(color: isDark ? Colors.white : null),
                ),
              ],
            ),
            
            // Rate slider
            Row(
              children: [
                Text(
                  'Speed:',
                  style: TextStyle(color: isDark ? Colors.white : null),
                ),
                Expanded(
                  child: Slider(
                    value: _controller.model.rate,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    label: _controller.model.rateFormatted,
                    activeColor: isDark ? Colors.purple : null,
                    thumbColor: isDark ? Colors.purpleAccent : null,
                    onChanged: (double value) async {
                      await _controller.setRate(value);
                      setState(() {});
                    },
                  ),
                ),
                Text(
                  _controller.model.rateFormatted,
                  style: TextStyle(color: isDark ? Colors.white : null),
                ),
              ],
            ),
            
            const SizedBox(height: 24.0),
            
            // Tappable words section
            Text(
              'Tap on individual words to hear them:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : null,
              ),
            ),
            const SizedBox(height: 8.0),
            Container(
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: isDark ? Colors.purple : Colors.black),
                borderRadius: BorderRadius.circular(8.0),
                color: isDark ? Colors.black : null,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8.0),
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _controller.buildTappableWords(),
                ),
              ),
            ),
            
            const SizedBox(height: 24.0),
            
            // Diagnostic tools
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _controller.testTts(context),
                  icon: const Icon(Icons.record_voice_over),
                  label: const Text('Test TTS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.purple : Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _controller.checkTtsStatus(context),
                  icon: const Icon(Icons.info_outline),
                  label: const Text('TTS Status'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.purple : Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ));
  }
}
