import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../controllers/text_to_speech_controller.dart';
import '../models/text_to_speech_model.dart';
import '../services/storage_service.dart';
import '../services/database_service.dart';
import '../services/pdf_extraction_service.dart';

/// View class for Text-to-Speech feature
/// Handles all UI presentation and user interaction
class TextToSpeechScreen extends StatefulWidget {
  final String extractedText;
  final Function(Map<String, dynamic>)? onFileUploaded;
  
  TextToSpeechScreen({required this.extractedText, this.onFileUploaded});

  @override
  _TextToSpeechScreenState createState() => _TextToSpeechScreenState();
}

class _TextToSpeechScreenState extends State<TextToSpeechScreen> {
  // Controller instance to handle all TTS logic
  late TextToSpeechController _controller;
  final StorageService _storageService = StorageService();
  final DatabaseService _databaseService = DatabaseService();
  // Use a consistent user ID for testing - in a real app, you'd get this from authentication
  late String _userId; // Will be set from the current authenticated user

  @override
  void initState() {
    super.initState();
    
    // Get the current user ID from Firebase Auth
    final currentUser = FirebaseAuth.instance.currentUser;
    _userId = currentUser?.uid ?? 'guest_user';
    _controller = TextToSpeechController();
    _initializeTts();
    
    // Set initial text if provided
    if (widget.extractedText.isNotEmpty) {
      _controller.model.textController.text = widget.extractedText;
      // Process text to extract pages
      _controller.processTextPages();
    }
    
    // Add listener for speak-as-you-type functionality
    _controller.model.textController.addListener(() {
      _controller.onTextChanged();
    });
  }
  
  // Helper method to update text field with current page content
  void _updateTextFieldWithCurrentPage() {
    if (_controller.model.isFullScreenMode && _controller.model.pages.isNotEmpty) {
      // Store the original text if not already stored
      if (_controller.model.originalText.isEmpty) {
        _controller.model.originalText = _controller.model.textController.text;
      }
      
      // Update text field to show only the current page
      _controller.model.textController.text = _controller.model.currentPageContent;
    } else if (!_controller.model.isFullScreenMode && _controller.model.originalText.isNotEmpty) {
      // Restore original text when exiting full screen mode
      _controller.model.textController.text = _controller.model.originalText;
    }
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
      // Use the PDF extraction service instead of navigating to a separate screen
      final result = await PdfExtractionService.extractTextFromPdf(context);
      
      // Check if we have valid data
      if (result != null && result is Map<String, dynamic>) {
        // Extract text content
        final String extractedText = result['content'] ?? '';
        
        // If text was extracted, update the text controller
        if (extractedText.isNotEmpty) {
          setState(() {
            _controller.model.textController.text = extractedText;
            // Process text to extract pages
            _controller.processTextPages();
          });
          
          // Save the extracted text to recent files without requiring cloud storage upload
          try {
            // Generate a unique name for the extracted text
            final String fileName = result['name'] ?? 'Extracted Text - ${DateTime.now().toString().substring(0, 16)}';
            
            // Notify user
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Saving extracted text...')),
            );
            
            // Add to recent files if callback is provided
            if (widget.onFileUploaded != null) {
              print('Calling onFileUploaded callback with extracted text');
              
              // Create a timestamp for the file
              final String timestamp = DateTime.now().toString();
              
              // Generate a unique ID for the file
              final String fileId = DateTime.now().millisecondsSinceEpoch.toString();
              
              // Upload text content to Firebase Storage
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Uploading text to cloud storage...')),
              );
              
              // Upload the text content as a file
              final String? downloadURL = await _storageService.uploadTextContent(
                extractedText,
                fileName,
                _userId
              );
              
              if (downloadURL == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to upload text to cloud storage')),
                );
                return;
              }
              
              // Create file data map with all required fields
              Map<String, dynamic> fileData = {
                'id': fileId,
                'name': fileName,
                'timestamp': timestamp,
                'type': 'extracted_text',
                'content': extractedText,
                'isFavorite': false,
                'downloadURL': downloadURL,  // Add the download URL from Firebase Storage
              };
              
              // Add original path if available
              if (result['pdfPath'] != null) {
                fileData['originalPath'] = result['pdfPath'];
              }
              
              // Call the callback to add to recent files
              widget.onFileUploaded!(fileData);
              
              // Also save to database for persistence
              await _databaseService.saveFileMetadata(_userId, fileData);
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Extracted text saved successfully')),
              );
            } else {
              print('onFileUploaded callback is null');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not save extracted text to recent files')),
              );
            }
          } catch (e) {
            print('Error saving extracted text: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error saving extracted text: $e')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No text was extracted from the PDF')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to extract text from PDF')),
        );
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
    
    // If in full-screen mode, show only the text area
    if (_controller.model.isFullScreenMode) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Text to Speech - Full Screen'),
          backgroundColor: isDark ? Colors.black : Colors.blueAccent,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.fullscreen_exit),
              onPressed: () {
                setState(() {
                  _controller.model.setFullScreenMode(false);
                  // Restore original text when exiting full screen mode
                  _updateTextFieldWithCurrentPage();
                });
              },
              tooltip: 'Exit Full Screen',
            ),
          ],
        ),
        body: Container(
          color: isDark ? Colors.black : null,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Page selection dropdown if multiple pages are available
              if (_controller.model.pages.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    children: [
                      Text(
                        'Select Page: ',
                        style: TextStyle(color: isDark ? Colors.white : null),
                      ),
                      Expanded(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: _controller.model.selectedPageIndex,
                          items: List.generate(_controller.model.pages.length, (index) {
                            return DropdownMenuItem<int>(
                              value: index,
                              child: Text('Page ${index + 1}'),
                            );
                          }),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _controller.model.setSelectedPageIndex(value);
                                // Update text field if in full screen mode
                                if (_controller.model.isFullScreenMode) {
                                  _updateTextFieldWithCurrentPage();
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Full-screen text area - now shows only current page
              Expanded(
                child: TextField(
                  controller: _controller.model.textController,
                  maxLines: null,
                  expands: true,
                  style: TextStyle(
                    color: isDark ? Colors.white : null,
                    fontSize: 18.0,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Text content will appear here',
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
              ),
              
              // Playback controls
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
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
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
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
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Regular mode with all controls
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text to Speech'),
        backgroundColor: isDark ? Colors.black : Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen),
            onPressed: () {
              setState(() {
                _controller.model.setFullScreenMode(true);
                // Update text field to show only the current page
                _updateTextFieldWithCurrentPage();
              });
            },
            tooltip: 'Full Screen Mode',
          ),
        ],
      ),
      body: Container(
        color: isDark ? Colors.black : null,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Page selection dropdown if multiple pages are available
              if (_controller.model.pages.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    children: [
                      Text(
                        'Select Page: ',
                        style: TextStyle(color: isDark ? Colors.white : null),
                      ),
                      Expanded(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: _controller.model.selectedPageIndex,
                          items: List.generate(_controller.model.pages.length, (index) {
                            return DropdownMenuItem<int>(
                              value: index,
                              child: Text('Page ${index + 1}'),
                            );
                          }),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _controller.model.setSelectedPageIndex(value);
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Language selection with auto-detection info
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Language: ',
                          style: TextStyle(color: isDark ? Colors.white : null),
                        ),
                        Expanded(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _controller.model.selectedLanguage,
                            items: _controller.model.languages.map((String language) {
                              return DropdownMenuItem<String>(
                                value: language,
                                child: Text(_controller.model.getLanguageDisplayName(language)),
                              );
                            }).toList(),
                            onChanged: (String? value) {
                              if (value != null) {
                                setState(() {
                                  _controller.setLanguage(value);
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Language will be auto-detected for Arabic text',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: isDark ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Text input field
              TextField(
                controller: _controller.model.textController,
                maxLines: 5,
                style: TextStyle(color: isDark ? Colors.white : null),
                textDirection: TextDirection.ltr, // Default to left-to-right, will be overridden by RTL text
                textAlign: TextAlign.start, // Start alignment works with both LTR and RTL
                decoration: InputDecoration(
                  hintText: 'Enter text to speak (English or Arabic)',
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
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.fullscreen),
                    onPressed: () {
                      setState(() {
                        _controller.model.setFullScreenMode(true);
                        // Update text field to show only the current page
                        _updateTextFieldWithCurrentPage();
                      });
                    },
                    tooltip: 'Full Screen Mode',
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
              
              // Import PDF button with Arabic support info
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _importPdf,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Import PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Supports PDFs with Arabic text',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: isDark ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
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
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
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
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
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
