import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:untitled/services/firebase_service.dart';

class ScanResult {
  final String text;
  final double confidence;
  final String rawText;

  ScanResult({
    required this.text,
    this.confidence = 0.0,
    required this.rawText,
  });
}

class SmartScanProcessor {
  late final TextRecognizer _textRecognizer;
  
  SmartScanProcessor() {
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  }
  
  void dispose() {
    _textRecognizer.close();
  }
  
  Future<ScanResult> processImage({
    required File imageFile,
    bool isHandwritingMode = false,
    int recognitionQuality = 2,
    bool enhancedCorrection = true,
    BuildContext? context,
  }) async {
    try {
      // Apply image preprocessing for better recognition
      File enhancedImage = await _enhanceImageForOCR(imageFile);
      
      final inputImage = InputImage.fromFile(enhancedImage);
      
      // Process the image with appropriate settings based on handwriting mode
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      String extractedText = recognizedText.text;
      String rawExtractedText = extractedText; // Store raw text
      
      if (extractedText.isEmpty) {
        debugPrint('No text recognized in the image');
        return ScanResult(
          text: '',
          confidence: 0.0,
          rawText: '',
        );
      }
      
      // Apply different processing based on mode and quality settings
      double confidence = 0.0;
      
      if (isHandwritingMode) {
        // For handwriting, process each text block separately for better results
        String combinedText = '';
        double totalConfidence = 0.0;
        int blockCount = 0;
        
        for (TextBlock block in recognizedText.blocks) {
          String blockText = block.text;
          
          // Calculate confidence for this block (based on recognition score if available)
          double blockConfidence = 0.7; // Default confidence
          
          // Process handwritten text with specialized corrections
          String processedText = _applyAdvancedHandwritingCorrections(blockText);
          
          combinedText += processedText + ' ';
          totalConfidence += blockConfidence;
          blockCount++;
        }
        
        if (blockCount > 0) {
          confidence = totalConfidence / blockCount;
          extractedText = combinedText.trim();
        }
        
        // Apply additional handwriting-specific processing
        extractedText = _processHandwrittenText(extractedText);
      } else {
        // For printed text
        extractedText = _processExtractedText(extractedText);
        
        // Apply enhanced corrections if enabled
        if (enhancedCorrection) {
          extractedText = _applyEnhancedCorrection(extractedText);
        }
        
        // Estimate confidence based on text quality indicators
        confidence = _estimateConfidence(extractedText, rawExtractedText);
      }
      
      // Format the text for better display
      extractedText = _formatTextForDisplay(extractedText);
      
      // Upload the image and extracted text to Firebase
      try {
        if (context != null) {
          // Show uploading message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uploading to Firebase...')),
          );
        }
        
        final FirebaseService firebaseService = FirebaseService();
        final result = await firebaseService.uploadScannedDocument(
          imageFile: imageFile,
          extractedText: extractedText,
          confidence: confidence,
          context: context,
        );
        
        debugPrint('Document uploaded to Firebase: ${result['downloadUrl']}');
        
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document uploaded successfully')),
          );
        }
      } catch (firebaseError) {
        debugPrint('Error uploading to Firebase: $firebaseError');
        // Continue with the process even if Firebase upload fails
      }
      
      return ScanResult(
        text: extractedText,
        confidence: confidence,
        rawText: rawExtractedText,
      );
    } catch (e) {
      debugPrint('Error in processImage: $e');
      // Return an empty result with error information instead of rethrowing
      return ScanResult(
        text: 'Error processing image: $e',
        confidence: 0.0,
        rawText: '',
      );
    }
  }
  
  // Enhanced image preprocessing for better OCR
  Future<File> _enhanceImageForOCR(File imageFile) async {
    try {
      // Read the image file
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        debugPrint('Image decoding failed, returning original image');
        return imageFile; // Return original if decoding fails
      }
      
      // Apply basic image enhancements - keeping it simple to avoid compatibility issues
      img.Image processedImage = img.copyResize(image, width: image.width, height: image.height);
      
      // Convert to grayscale for better OCR - this is the most important step for text recognition
      processedImage = img.grayscale(processedImage);
      
      // Create a temporary file to save the processed image
      final tempDir = await Directory.systemTemp.createTemp('ocr_');
      final tempFile = File('${tempDir.path}/enhanced_${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      // Save the processed image
      await tempFile.writeAsBytes(img.encodeJpg(processedImage, quality: 100));
      
      debugPrint('Image enhanced successfully: ${tempFile.path}');
      return tempFile;
    } catch (e) {
      debugPrint('Error enhancing image: $e');
      return imageFile; // Return original if processing fails
    }
  }
  
  // Basic text processing for extracted text
  String _processExtractedText(String text) {
    if (text.isEmpty) return text;
    
    // Fix common OCR issues
    String processed = text;
    
    // Replace common OCR errors
    Map<String, String> replacements = {
      'l': 'I', // Replace lowercase l with uppercase I in specific contexts
      '0': 'O', // Replace 0 with O in specific contexts
      '1': 'l', // Replace 1 with l in specific contexts
    };
    
    // Apply contextual replacements
    // This is a simplified version - in a real app, you'd use more sophisticated NLP
    replacements.forEach((wrong, right) {
      // Only replace in specific contexts to avoid incorrect replacements
      if (wrong == 'l' && right == 'I') {
        // Replace 'l' with 'I' when it appears as a standalone word
        processed = processed.replaceAllMapped(RegExp(r'\bl\b'), (match) {
          return right;
        });
      }
      // Add more contextual replacements as needed
      if (wrong == '0' && right == 'O') {
        // Replace '0' with 'O' when it appears as a standalone word
        processed = processed.replaceAllMapped(RegExp(r'\b0\b'), (match) {
          return right;
        });
      }
      if (wrong == '1' && right == 'l') {
        // Replace '1' with 'l' when it appears as a standalone word
        processed = processed.replaceAllMapped(RegExp(r'\b1\b'), (match) {
          return right;
        });
      }
    });
    
    // Fix spacing issues
    processed = processed.replaceAllMapped(RegExp(r'\s{2,}'), (match) {
      return ' ';
    }); // Replace multiple spaces with single space
    processed = processed.replaceAllMapped(RegExp(r'(\r\n|\r|\n){2,}'), (match) {
      return '\n\n';
    }); // Replace multiple newlines with double newline
    
    return processed;
  }
  
  // Specialized processing for handwritten text
  String _processHandwrittenText(String text) {
    if (text.isEmpty) return text;
    
    // Apply more aggressive corrections for handwriting
    String processed = text;
    
    // Fix common handwriting OCR issues
    processed = processed.replaceAllMapped(RegExp(r'([a-z])\.([a-z])'), (match) {
      return '${match.group(1)}${match.group(2)}';
    }); // Remove periods between letters
    processed = processed.replaceAllMapped(RegExp(r'([a-z])\,([a-z])'), (match) {
      return '${match.group(1)}${match.group(2)}';
    }); // Remove commas between letters
    
    // Fix spacing in handwriting
    processed = processed.replaceAllMapped(RegExp(r'([a-zA-Z])(\s*)([.,;:])'), (match) {
      return '${match.group(1)}${match.group(3)}';
    }); // Remove spaces before punctuation
    processed = processed.replaceAllMapped(RegExp(r'([.,;:])([a-zA-Z])'), (match) {
      return '${match.group(1)} ${match.group(2)}';
    }); // Add space after punctuation if missing
    
    // Fix common word patterns in handwriting
    processed = _correctCommonWords(processed);
    
    return processed;
  }
  
  // Correct common words based on dictionary
  String _correctCommonWords(String text) {
    if (text.isEmpty) return text;
    
    // Common word corrections
    Map<String, String> commonWords = {
      'tbe': 'the',
      'amd': 'and',
      'tbat': 'that',
      'witb': 'with',
      'bave': 'have',
      'tben': 'then',
      'tbis': 'this',
      'tbese': 'these',
      'tbose': 'those',
      'tbeir': 'their',
      'wbat': 'what',
      'wben': 'when',
      'wbere': 'where',
      'wbich': 'which',
      'wbo': 'who',
      'wby': 'why',
    };
    
    // Split text into words and correct each word
    List<String> words = text.split(RegExp(r'\s+'));
    for (int i = 0; i < words.length; i++) {
      String word = words[i].toLowerCase();
      
      // Remove punctuation for checking
      String wordNoPunct = word.replaceAll(RegExp(r'[^\w\s]'), '');
      
      if (commonWords.containsKey(wordNoPunct)) {
        // Preserve case and punctuation when replacing
        String replacement = commonWords[wordNoPunct]!;
        words[i] = _preserveCase(words[i], replacement);
      }
    }
    
    return words.join(' ');
  }
  
  // Apply enhanced correction using more sophisticated techniques
  String _applyEnhancedCorrection(String text) {
    if (text.isEmpty) return text;
    
    String corrected = text;
    
    // 1. Fix common character confusion
    Map<String, String> charCorrections = {
      'rn': 'm',
      'vv': 'w',
      'cl': 'd',
      'li': 'h',
      'ii': 'u',
    };
    
    charCorrections.forEach((wrong, right) {
      // Only replace in word context to avoid incorrect replacements
      try {
        final pattern = '\\b\\w*' + RegExp.escape(wrong) + '\\w*\\b';
        corrected = corrected.replaceAllMapped(
          RegExp(pattern, caseSensitive: false),
          (match) {
            String word = match.group(0) ?? '';
            // Check if this is likely a real word containing the pattern
            // This is a simplified check - in a real app, you'd use a dictionary
            if (word.length > 5) {
              return word.replaceAll(wrong, right);
            }
            return word;
          }
        );
      } catch (e) {
        debugPrint('Error in character correction: $e');
        // Continue with the original text if there's an error
      }
    });
    
    // 2. Fix spacing around punctuation
    try {
      corrected = corrected.replaceAllMapped(RegExp(r'([.,;:!?])(\s*)([a-zA-Z])'), (match) {
        return '${match.group(1)} ${match.group(3)}';
      });
    } catch (e) {
      debugPrint('Error fixing spacing around punctuation: $e');
    }
    
    // 3. Fix capitalization after periods
    try {
      corrected = corrected.replaceAllMapped(
        RegExp(r'([.!?])\s+([a-z])'),
        (match) {
          String punctuation = match.group(1) ?? '';
          String letter = match.group(2) ?? '';
          return '$punctuation ${letter.toUpperCase()}';
        }
      );
    } catch (e) {
      debugPrint('Error fixing capitalization: $e');
    }
    
    // 4. Fix paragraph formatting
    try {
      corrected = corrected.replaceAllMapped(RegExp(r'(\r\n|\r|\n){3,}'), (match) {
        return '\n\n';
      });
    } catch (e) {
      debugPrint('Error fixing paragraph formatting: $e');
    }
    
    return corrected;
  }
  
  // Format text for better display
  String _formatTextForDisplay(String text) {
    if (text.isEmpty) return text;
    
    // Normalize line breaks
    String formatted = text.replaceAllMapped(RegExp(r'\r\n|\r'), (match) {
      return '\n';
    });
    
    // Ensure proper paragraph spacing
    formatted = formatted.replaceAllMapped(RegExp(r'\n{3,}'), (match) {
      return '\n\n';
    });
    
    // Ensure space after punctuation
    formatted = formatted.replaceAllMapped(RegExp(r'([.,;:!?])(\s*)([a-zA-Z])'), (match) {
      return '${match.group(1)} ${match.group(3)}';
    });
    
    // Remove extra spaces
    formatted = formatted.replaceAllMapped(RegExp(r' {2,}'), (match) {
      return ' ';
    });
    
    return formatted;
  }
  
  // Advanced handwriting-specific corrections
  String _applyAdvancedHandwritingCorrections(String text) {
    if (text.isEmpty) return text;
    
    // Apply more aggressive handwriting-specific corrections
    
    // 1. Fix common letter confusions in handwriting
    Map<String, String> letterCorrections = {
      'cl': 'd',
      'rn': 'm',
      'vv': 'w',
      'lT': 'lt',
      'rnm': 'mm',
      'ii': 'u',
      'ri': 'n',
      'l1': 'h',
      '0': 'o',
      '1': 'l',
      '5': 's',
      '8': 'B',
      '6': 'b',
      '9': 'g',
    };
    
    String corrected = text;
    try {
      letterCorrections.forEach((wrong, right) {
        // Only replace when it's likely to be a mistake, not part of a valid word
        corrected = corrected.replaceAllMapped(RegExp('\\b$wrong\\b'), (match) {
          return right;
        });
      });
      
      // 2. Fix common word patterns in handwriting
      corrected = _correctCommonWords(corrected);
      
      // 3. Apply context-aware corrections
      corrected = _applyContextAwareCorrections(corrected);
      
      return corrected;
    } catch (e) {
      debugPrint('Error in handwriting corrections: $e');
      return text; // Return original text if there's an error
    }
  }
  
  // Context-aware corrections that consider surrounding words
  String _applyContextAwareCorrections(String text) {
    // Split text into words
    List<String> words = text.split(RegExp(r'\s+'));
    if (words.length <= 1) return text;
    
    try {
      // Common word pairs and phrases that often appear together
      Map<String, Map<String, String>> contextCorrections = {
        'tlie': {'following': 'the', 'same': 'the', 'first': 'the'},
        'witli': {'the': 'with', 'a': 'with', 'my': 'with'},
        'tliat': {'is': 'that', 'was': 'that', 'are': 'that'},
        'liere': {'is': 'here', 'are': 'here'},
        'tliis': {'is': 'this', 'was': 'this'},
        'liave': {'to': 'have', 'not': 'have', 'been': 'have'},
        'tbe': {'of': 'the', 'in': 'the', 'on': 'the'},
        'tbat': {'is': 'that', 'was': 'that', 'the': 'that'},
      };
      
      // Apply context corrections
      for (int i = 0; i < words.length; i++) {
        if (words[i].isEmpty) continue;
        
        String currentWord = words[i].toLowerCase();
        
        // Check if this word has potential context corrections
        if (contextCorrections.containsKey(currentWord)) {
          // Check previous word (if exists)
          if (i > 0) {
            String prevWord = words[i-1].toLowerCase();
            if (contextCorrections[currentWord]!.containsKey(prevWord)) {
              words[i] = _preserveCase(words[i], contextCorrections[currentWord]![prevWord]!);
              continue;
            }
          }
          
          // Check next word (if exists)
          if (i < words.length - 1) {
            String nextWord = words[i+1].toLowerCase();
            if (contextCorrections[currentWord]!.containsKey(nextWord)) {
              words[i] = _preserveCase(words[i], contextCorrections[currentWord]![nextWord]!);
            }
          }
        }
      }
      
      return words.join(' ');
    } catch (e) {
      debugPrint('Error in context-aware corrections: $e');
      return text; // Return original text if there's an error
    }
  }
  
  // Helper to preserve the case pattern when replacing words
  String _preserveCase(String original, String replacement) {
    if (original.isEmpty || replacement.isEmpty) return replacement;
    
    // If original is all uppercase, make replacement all uppercase
    if (original == original.toUpperCase()) {
      return replacement.toUpperCase();
    }
    
    // If original is capitalized, capitalize the replacement
    if (original[0] == original[0].toUpperCase()) {
      return replacement[0].toUpperCase() + replacement.substring(1);
    }
    
    return replacement;
  }
  
  // Estimate confidence based on text quality indicators
  double _estimateConfidence(String processedText, String rawText) {
    if (processedText.isEmpty) return 0.0;
    
    double confidence = 0.8; // Start with a base confidence
    
    try {
      // Reduce confidence if there were significant changes during processing
      double textDifferenceRatio = 0.0;
      if (rawText.isNotEmpty) {
        int levenshteinDistance = _calculateLevenshteinDistance(rawText, processedText);
        textDifferenceRatio = levenshteinDistance / rawText.length;
        
        // If more than 20% of the text was changed, reduce confidence
        if (textDifferenceRatio > 0.2) {
          confidence -= (textDifferenceRatio - 0.2) * 2; // Progressive penalty
        }
      }
      
      // Check for common indicators of low-quality OCR
      if (processedText.contains('�') || processedText.contains('□')) {
        confidence -= 0.2;
      }
      
      // Check for unusual character distributions
      if (processedText.isNotEmpty) {
        double specialCharRatio = processedText.replaceAll(RegExp(r'[a-zA-Z0-9\s]'), '').length / processedText.length;
        if (specialCharRatio > 0.3) {
          confidence -= 0.2;
        }
      }
    } catch (e) {
      debugPrint('Error calculating confidence: $e');
      // Default to a moderate confidence if calculation fails
      confidence = 0.5;
    }
    
    // Ensure confidence is between 0 and 1
    return confidence.clamp(0.0, 1.0);
  }
  
  // Calculate Levenshtein distance between two strings
  int _calculateLevenshteinDistance(String s, String t) {
    try {
      if (s == t) return 0;
      if (s.isEmpty) return t.length;
      if (t.isEmpty) return s.length;
      
      // Limit the string lengths to prevent excessive processing
      // for very long texts
      final int maxLength = 1000;
      if (s.length > maxLength) s = s.substring(0, maxLength);
      if (t.length > maxLength) t = t.substring(0, maxLength);
      
      List<int> v0 = List<int>.filled(t.length + 1, 0);
      List<int> v1 = List<int>.filled(t.length + 1, 0);
      
      for (int i = 0; i < v0.length; i++) {
        v0[i] = i;
      }
      
      for (int i = 0; i < s.length; i++) {
        v1[0] = i + 1;
        
        for (int j = 0; j < t.length; j++) {
          int cost = (s[i] == t[j]) ? 0 : 1;
          v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce((curr, next) => curr < next ? curr : next);
        }
        
        for (int j = 0; j < v0.length; j++) {
          v0[j] = v1[j];
        }
      }
      
      return v1[t.length];
    } catch (e) {
      debugPrint('Error calculating Levenshtein distance: $e');
      // Return a default approximation based on length difference
      return (s.length - t.length).abs();
    }
  }
}
