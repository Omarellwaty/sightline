import 'package:flutter/material.dart';

/// Model class for Text-to-Speech feature
/// Contains all data structures and state for TTS functionality
class TextToSpeechModel {
  // Text content
  final TextEditingController textController = TextEditingController();
  String lastSpokenText = '';
  String originalText = ''; // Stores the original full text when in full-screen mode
  
  // TTS state
  bool isPlaying = false;
  
  // Voice settings
  double volume = 1.0;
  double pitch = 1.0;
  double rate = 0.5;
  String selectedLanguage = 'en-US';
  List<String> languages = ['en-US', 'ar-SA',]; //'fr-FR', 'de-DE', 'es-ES'];
  
  // Feature toggles
  bool speakAsYouType = false;
  bool isFullScreenMode = false;
  
  // Page selection
  List<String> pages = [];
  int selectedPageIndex = 0;
  
  // Engine information
  String? engineName;
  List<String> availableVoices = [];
  bool isLanguageAvailable = false;
  
  // Getters for formatted values (useful for UI display)
  String get volumeFormatted => volume.toStringAsFixed(1);
  String get pitchFormatted => pitch.toStringAsFixed(1);
  String get rateFormatted => rate.toStringAsFixed(1);
  
  // Methods to update model state
  void setVolume(double value) {
    volume = value;
  }
  
  void setPitch(double value) {
    pitch = value;
  }
  
  void setRate(double value) {
    rate = value;
  }
  
  void setLanguage(String value) {
    selectedLanguage = value;
  }
  
  void setSpeakAsYouType(bool value) {
    speakAsYouType = value;
  }
  
  void setPlaying(bool value) {
    isPlaying = value;
  }
  
  void setFullScreenMode(bool value) {
    isFullScreenMode = value;
  }
  
  void setPages(String text) {
    // Split the text into pages based on 'Page X:' markers
    pages = [];
    if (text.contains('Page')) {
      // Try to extract pages using regex pattern
      RegExp pageRegex = RegExp(r'Page\s+\d+:\s*([\s\S]*?)(?=Page\s+\d+:|$)');
      Iterable<RegExpMatch> matches = pageRegex.allMatches(text);
      
      if (matches.isNotEmpty) {
        // Extract page numbers and content
        for (var match in matches) {
          String pageContent = match.group(0) ?? '';
          if (pageContent.trim().isNotEmpty) {
            pages.add(pageContent.trim());
          }
        }
      } else {
        // Fallback: just add the whole text as one page
        pages = [text];
      }
    } else {
      // If no page markers, treat the whole text as one page
      pages = [text];
    }
    
    // Reset to first page
    selectedPageIndex = 0;
  }
  
  void setSelectedPageIndex(int index) {
    if (index >= 0 && index < pages.length) {
      selectedPageIndex = index;
    }
  }
  
  String get currentPageContent {
    if (pages.isEmpty) return '';
    return pages[selectedPageIndex];
  }
  
  void setEngineInfo(String? engine, List<String> voices, bool langAvailable) {
    engineName = engine;
    availableVoices = voices.map((v) => v.toString()).toList();
    isLanguageAvailable = langAvailable;
  }
  
  // Helper method to get language display name
  String getLanguageDisplayName(String langCode) {
    switch (langCode) {
      case 'en-US': return 'English';
      case 'ar-SA': return 'Arabic';
     // case 'fr-FR': return 'French';
      //case 'de-DE': return 'German';
      //case 'es-ES': return 'Spanish';
      default: return langCode;
    }
  }
  
  // Clean up resources
  void dispose() {
    textController.dispose();
  }
}
