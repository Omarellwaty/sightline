import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

// Text Editor Screen with improved UI
class TextEditorScreen extends StatefulWidget {
  final String extractedText;
  final String? inputFileName;
  final Function(String) onSave;
  final double initialFontSize;
  final double initialWordSpacing;
  final double initialLetterSpacing;
  final double initialLineSpacing;

  const TextEditorScreen({
    super.key,
    required this.extractedText,
    this.inputFileName,
    required this.onSave,
    this.initialFontSize = 14.0,
    this.initialWordSpacing = 0.0,
    this.initialLetterSpacing = 0.0,
    this.initialLineSpacing = 1.0,
  });

  @override
  State<TextEditorScreen> createState() => _TextEditorScreenState();
}

class _TextEditorScreenState extends State<TextEditorScreen> {
  late TextEditingController _textEditingController;
  String _selectedFont = 'Arial';
  late double _fontSize;
  late double _wordSpacing;
  late double _letterSpacing;
  late double _lineSpacing;
  
  // Fixed values for text color and alignment
  final Color _textColor = Colors.black87;
  final TextAlign _textAlign = TextAlign.left;
  
  // Font settings are mapped to custom fonts in the _getFontFamily method below
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  bool _isFullScreen = false; // Track fullscreen state
  int _currentPage = 0; // Current page in page view
  List<String> _pages = []; // List of pages for page view
  final PageController _pageController = PageController(); // Controller for page view
  
  // Available font options
  final List<String> _availableFonts = const [
    'Arial',
    'OpenDyslexic',
    'Comic Sans',
  ];

  @override
  void initState() {
    super.initState();
    _textEditingController = TextEditingController(text: widget.extractedText);
    _fontSize = widget.initialFontSize;
    _wordSpacing = widget.initialWordSpacing;
    _letterSpacing = widget.initialLetterSpacing;
    _lineSpacing = widget.initialLineSpacing;
    
    // Initialize TTS
    _initTts();
    
    // Split text into pages for fullscreen mode
    _splitTextIntoPages();
    
    // Set up auto-save feature
    _textEditingController.addListener(_autoSave);
  }
  
  // Auto-save function
  void _autoSave() {
    // Save the text whenever it changes
    widget.onSave(_textEditingController.text);
  }

  @override
  void dispose() {
    // Remove listener before disposing controller
    _textEditingController.removeListener(_autoSave);
    _textEditingController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  // Initialize text-to-speech functionality
  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    
    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });
  }

  // Split text into pages for fullscreen reading mode
  void _splitTextIntoPages() {
    const int charsPerPage = 1000; // Approximate characters per page
    final String text = _textEditingController.text;
    
    if (text.isEmpty) {
      _pages = [''];
      return;
    }
    
    final List<String> pages = [];
    int startIndex = 0;
    
    while (startIndex < text.length) {
      int endIndex = startIndex + charsPerPage;
      if (endIndex >= text.length) {
        endIndex = text.length;
      } else {
        // Try to find a paragraph or sentence break
        int breakIndex = text.lastIndexOf('\n\n', endIndex);
        if (breakIndex > startIndex && breakIndex < endIndex) {
          endIndex = breakIndex + 2;
        } else {
          breakIndex = text.lastIndexOf('. ', endIndex);
          if (breakIndex > startIndex && breakIndex < endIndex) {
            endIndex = breakIndex + 2;
          }
        }
      }
      
      pages.add(text.substring(startIndex, endIndex));
      startIndex = endIndex;
    }
    
    setState(() {
      _pages = pages.isEmpty ? [''] : pages;
    });
  }

  // Toggle fullscreen mode
  void _toggleFullscreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      if (_isFullScreen) {
        _splitTextIntoPages();
        _currentPage = 0;
        _pageController.jumpToPage(0);
      }
    });
  }

  // Speak text using TTS
  Future<void> _speak(String text) async {
    if (text.isNotEmpty) {
      await _flutterTts.speak(text);
      setState(() {
        _isSpeaking = true;
      });
    }
  }

  // Get font family based on selected font
  String _getFontFamily() {
    switch (_selectedFont) {
      case 'OpenDyslexic':
        return 'OpenDyslexic';
      case 'Comic Sans':
        return 'Comic Sans MS';
      case 'Arial':
      default:
        return 'Arial';
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // If in fullscreen mode, exit fullscreen instead of going back
        if (_isFullScreen) {
          setState(() {
            _isFullScreen = false;
          });
          return false; // Prevent pop
        }
        // Otherwise, save text and allow pop
        widget.onSave(_textEditingController.text);
        return true; // Allow pop
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.inputFileName != null
              ? 'Edit: ${widget.inputFileName}'
              : 'Text Editor',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue.shade700,
        actions: [
          // Text-to-speech button
          IconButton(
            icon: Icon(_isSpeaking ? Icons.stop : Icons.volume_up, color: Colors.white),
            onPressed: () {
              if (_isSpeaking) {
                _flutterTts.stop();
                setState(() {
                  _isSpeaking = false;
                });
              } else {
                _speak(_textEditingController.text);
              }
            },
            tooltip: _isSpeaking ? 'Stop Speaking' : 'Read Aloud',
          ),
          // Fullscreen toggle button
          IconButton(
            icon: const Icon(Icons.fullscreen),
            onPressed: _toggleFullscreen,
            tooltip: 'Enter Fullscreen',
          ),
          // Save button
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: () {
              widget.onSave(_textEditingController.text);
              Navigator.pop(context);
            },
            tooltip: 'Save Changes',
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[100], // Light background color for the entire screen
        child: Stack(
          children: [
            // Main content column
            Column(
              children: [
                // Font controls section - hidden in fullscreen mode
                if (!_isFullScreen)
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Font controls header
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade700,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Font Settings',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 6),
                          
                          // Font family selection
                          const Text(
                            'Font Family',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedFont,
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down),
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
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Font size slider
                          Row(
                            children: [
                              const Text(
                                'Font Size',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _fontSize.toStringAsFixed(1),
                                style: TextStyle(color: Colors.blue.shade700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: Colors.blue.shade600,
                              inactiveTrackColor: Colors.blue.shade100,
                              thumbColor: Colors.white,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayColor: Colors.blue.shade700.withOpacity(0.2),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                              trackHeight: 4,
                            ),
                            child: Slider(
                              value: _fontSize,
                              min: 10.0,
                              max: 30.0,
                              divisions: 20,
                              onChanged: (double value) {
                                setState(() {
                                  _fontSize = value;
                                });
                              },
                            ),
                          ),
                          
                          const SizedBox(height: 6),
                          
                          // Word spacing slider
                          Row(
                            children: [
                              const Text(
                                'Word Spacing',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _wordSpacing.toStringAsFixed(1),
                                style: TextStyle(color: Colors.blue.shade700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: Colors.blue.shade600,
                              inactiveTrackColor: Colors.blue.shade100,
                              thumbColor: Colors.white,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayColor: Colors.blue.shade700.withOpacity(0.2),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                              trackHeight: 4,
                            ),
                            child: Slider(
                              value: _wordSpacing,
                              min: 0.0,
                              max: 10.0,
                              divisions: 10,
                              onChanged: (double value) {
                                setState(() {
                                  _wordSpacing = value;
                                });
                              },
                            ),
                          ),
                          
                          const SizedBox(height: 6),
                          
                          // Letter spacing slider
                          Row(
                            children: [
                              const Text(
                                'Letter Spacing',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _letterSpacing.toStringAsFixed(1),
                                style: TextStyle(color: Colors.blue.shade700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: Colors.blue.shade600,
                              inactiveTrackColor: Colors.blue.shade100,
                              thumbColor: Colors.white,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayColor: Colors.blue.shade700.withOpacity(0.2),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                              trackHeight: 4,
                            ),
                            child: Slider(
                              value: _letterSpacing,
                              min: 0.0,
                              max: 5.0,
                              divisions: 10,
                              onChanged: (double value) {
                                setState(() {
                                  _letterSpacing = value;
                                });
                              },
                            ),
                          ),
                          
                          const SizedBox(height: 6),
                          
                          // Line spacing slider
                          Row(
                            children: [
                              const Text(
                                'Line Spacing',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _lineSpacing.toStringAsFixed(1),
                                style: TextStyle(color: Colors.blue.shade700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: Colors.blue.shade600,
                              inactiveTrackColor: Colors.blue.shade100,
                              thumbColor: Colors.white,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayColor: Colors.blue.shade700.withOpacity(0.2),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                              trackHeight: 4,
                            ),
                            child: Slider(
                              value: _lineSpacing,
                              min: 1.0,
                              max: 3.0,
                              divisions: 10,
                              onChanged: (double value) {
                                setState(() {
                                  _lineSpacing = value;
                                });
                              },
                            ),
                          ),
                        ],
                    ),
                  ),
                
                // Text Editor - Takes most of the screen space
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _isFullScreen
                      ? PageView.builder(
                          controller: _pageController,
                          itemCount: _pages.length,
                          onPageChanged: (int page) {
                            setState(() {
                              _currentPage = page;
                            });
                          },
                          itemBuilder: (context, index) {
                            return SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Page header with navigation
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Page indicator
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade700,
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Text(
                                            'Page ${index + 1} of ${_pages.length}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        
                                        // Text-to-speech button - smaller
                                        IconButton(
                                          icon: Icon(_isSpeaking ? Icons.stop : Icons.volume_up, color: Colors.blue.shade700, size: 20),
                                          onPressed: () {
                                            if (_isSpeaking) {
                                              _flutterTts.stop();
                                              setState(() {
                                                _isSpeaking = false;
                                              });
                                            } else {
                                              _speak(_pages[_currentPage]);
                                            }
                                          },
                                          tooltip: _isSpeaking ? 'Stop Speaking' : 'Read Current Page',
                                          iconSize: 20,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 36,
                                            minHeight: 36,
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    const SizedBox(height: 6),
                                    
                                    // Page content
                                    Text(
                                      _pages[index],
                                      style: TextStyle(
                                        fontFamily: _getFontFamily(),
                                        fontSize: _fontSize,
                                        height: _lineSpacing, // Line height multiplier for proper spacing
                                        letterSpacing: _letterSpacing,
                                        wordSpacing: _wordSpacing, // Space between words in pixels
                                        color: _textColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                      : TextField(
                          controller: _textEditingController,
                          maxLines: null, // Allow unlimited lines
                          style: TextStyle(
                            fontFamily: _getFontFamily(),
                            fontSize: _fontSize,
                            height: _lineSpacing, // Line height multiplier
                            letterSpacing: _letterSpacing,
                            wordSpacing: _wordSpacing, // Space between words
                            color: _textColor,
                          ),
                          textAlign: _textAlign,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Start typing or paste text here...',
                          ),
                        ),
                  ),
                ),
              ],
            ),
            
            // Bottom action bar in fullscreen mode
            if (_isFullScreen)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.white.withOpacity(0.9),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Previous page button
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: _currentPage > 0 ? Colors.blue.shade700 : Colors.grey),
                        onPressed: _currentPage > 0
                          ? () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          : null,
                        tooltip: 'Previous Page',
                      ),
                      
                      // Page indicator
                      Text(
                        'Page ${_currentPage + 1} of ${_pages.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      
                      // Next page button
                      IconButton(
                        icon: Icon(Icons.arrow_forward, color: _currentPage < _pages.length - 1 ? Colors.blue.shade700 : Colors.grey),
                        onPressed: _currentPage < _pages.length - 1
                          ? () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          : null,
                        tooltip: 'Next Page',
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      // No bottom action bar
      bottomNavigationBar: null,
    ),
    );
  }
}
