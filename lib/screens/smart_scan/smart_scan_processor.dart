import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:untitled/services/firebase_service.dart';
import 'scan_result.dart';

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
      
      String extractedText = '';
      double confidence = 0.0;
      
      if (isHandwritingMode) {
        // For handwriting, use image segmentation approach for better accuracy
        debugPrint('Using image segmentation for handwriting recognition');
        
        // Step 1: Segment the image into smaller chunks (lines or words)
        List<img.Image> segments = await _segmentImage(enhancedImage);
        debugPrint('Created ${segments.length} image segments');
        
        // Step 2: Process each segment separately
        List<String> segmentTexts = [];
        double totalConfidence = 0.0;
        
        for (int i = 0; i < segments.length; i++) {
          // Save segment to temporary file
          final tempDir = await Directory.systemTemp.createTemp('segment_');
          final segmentFile = File('${tempDir.path}/segment_$i.jpg');
          await segmentFile.writeAsBytes(img.encodeJpg(segments[i], quality: 100));
          
          // Process the segment
          final segmentInputImage = InputImage.fromFile(segmentFile);
          final segmentRecognizedText = await _textRecognizer.processImage(segmentInputImage);
          
          // Add to results if text was found
          if (segmentRecognizedText.text.isNotEmpty) {
            segmentTexts.add(segmentRecognizedText.text);
            totalConfidence += 0.8; // Default confidence for successful segments
          }
          
          // Clean up temporary file
          try {
            await segmentFile.delete();
            await tempDir.delete();
          } catch (e) {
            // Ignore cleanup errors
          }
        }
        
        // Combine results from all segments
        extractedText = segmentTexts.join(' ');
        confidence = segments.isNotEmpty ? totalConfidence / segments.length : 0.0;
        
      } else {
        // For printed text, process the whole image at once
        final inputImage = InputImage.fromFile(enhancedImage);
        final recognizedText = await _textRecognizer.processImage(inputImage);
        extractedText = recognizedText.text;
      }
      
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
      // confidence is already defined above, so we'll reuse it
      
      if (isHandwritingMode) {
        // For handwriting, process each text block separately for better results
        String combinedText = '';
        double totalConfidence = 0.0;
        int blockCount = 0;
        
        // Use the extracted text we already have from the segmentation approach
        // This is already processed line by line in the segmentation code above
        // No need to use combinedText, blockCount, or totalConfidence
        // as we already have extractedText and confidence from the segmentation process
        
        // Apply additional handwriting-specific processing
        extractedText = _processHandwrittenText(extractedText);
        extractedText = _applyHandwritingSpellChecking(extractedText);
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
  
  // Segment image into smaller chunks for better recognition
  Future<List<img.Image>> _segmentImage(File imageFile) async {
    List<img.Image> segments = [];
    
    try {
      // Read and decode the image
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        debugPrint('Failed to decode image for segmentation');
        return segments;
      }
      
      // Convert to grayscale for better processing
      final grayImage = img.grayscale(image);
      
      // Step 1: Detect horizontal lines of text using projection profile
      List<Map<String, int>> textLines = _detectTextLines(grayImage);
      debugPrint('Detected ${textLines.length} text lines');
      
      // Step 2: Create segments from the detected lines
      for (var line in textLines) {
        // Skip very small lines (likely noise)
        if (line['height']! < 20 || line['width']! < 50) continue;
        
        // Create a segment for this line
        img.Image lineSegment = img.copyCrop(
          grayImage,
          x: line['x']!,
          y: line['y']!,
          width: line['width']!,
          height: line['height']!
        );
        
        // Add padding around the segment for better recognition
        int padding = 10;
        img.Image paddedSegment = img.Image(
          width: lineSegment.width + padding * 2,
          height: lineSegment.height + padding * 2
        );
        
        // Fill with white background
        for (int y = 0; y < paddedSegment.height; y++) {
          for (int x = 0; x < paddedSegment.width; x++) {
            paddedSegment.setPixel(x, y, img.ColorRgb8(255, 255, 255));
          }
        }
        
        // Copy the line segment into the padded image
        for (int y = 0; y < lineSegment.height; y++) {
          for (int x = 0; x < lineSegment.width; x++) {
            paddedSegment.setPixel(
              x + padding,
              y + padding,
              lineSegment.getPixel(x, y)
            );
          }
        }
        
        segments.add(paddedSegment);
      }
      
      // If no segments were detected, return the whole image as a single segment
      if (segments.isEmpty) {
        debugPrint('No segments detected, using whole image');
        segments.add(grayImage);
      }
      
      return segments;
    } catch (e) {
      debugPrint('Error in image segmentation: $e');
      // Return the whole image as a single segment in case of error
      final image = img.decodeImage(await imageFile.readAsBytes());
      if (image != null) {
        segments.add(img.grayscale(image));
      }
      return segments;
    }
  }
  
  // Enhance contrast using adaptive histogram equalization
  img.Image _enhanceContrast(img.Image image) {
    try {
      // Create a new image with the same dimensions
      img.Image enhancedImage = img.Image(width: image.width, height: image.height);
      
      // Find the minimum and maximum pixel values in the image
      int minPixel = 255;
      int maxPixel = 0;
      
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          final gray = img.getLuminance(pixel).round();
          minPixel = gray < minPixel ? gray : minPixel;
          maxPixel = gray > maxPixel ? gray : maxPixel;
        }
      }
      
      // Calculate the range of pixel values
      final range = maxPixel - minPixel;
      
      // If the range is too small, apply a more aggressive contrast enhancement
      if (range < 100) {
        // Apply a more aggressive contrast enhancement for low contrast images
        for (int y = 0; y < image.height; y++) {
          for (int x = 0; x < image.width; x++) {
            final pixel = image.getPixel(x, y);
            final gray = img.getLuminance(pixel).round();
            
            // Apply a stronger stretch to increase contrast
            int newValue = ((gray - minPixel) * 255 ~/ range).clamp(0, 255);
            
            // Apply additional contrast boost for mid-range values
            if (newValue > 30 && newValue < 225) {
              newValue = (newValue < 128) ? 
                  (newValue * 0.8).round() : 
                  (newValue * 1.2).round().clamp(0, 255);
            }
            
            enhancedImage.setPixel(x, y, img.ColorRgb8(newValue, newValue, newValue));
          }
        }
      } else {
        // For images with good contrast, apply a gentler enhancement
        for (int y = 0; y < image.height; y++) {
          for (int x = 0; x < image.width; x++) {
            final pixel = image.getPixel(x, y);
            final gray = img.getLuminance(pixel).round();
            
            // Apply a standard contrast stretch
            int newValue = ((gray - minPixel) * 255 ~/ range).clamp(0, 255);
            enhancedImage.setPixel(x, y, img.ColorRgb8(newValue, newValue, newValue));
          }
        }
      }
      
      return enhancedImage;
    } catch (e) {
      debugPrint('Error enhancing contrast: $e');
      return image; // Return original image if enhancement fails
    }
  }
  
  // Detect text lines in an image using projection profile
  List<Map<String, int>> _detectTextLines(img.Image image) {
    List<Map<String, int>> textLines = [];
    
    try {
      // Create a binary image (black and white)
      img.Image binaryImage = img.Image(width: image.width, height: image.height);
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          var pixel = image.getPixel(x, y);
          int gray = img.getLuminance(pixel).round();
          // Apply threshold (adjust as needed)
          int value = gray < 180 ? 0 : 255;
          binaryImage.setPixel(x, y, img.ColorRgb8(value, value, value));
        }
      }
      
      // Calculate horizontal projection profile (sum of black pixels in each row)
      List<int> horizontalProfile = List<int>.filled(image.height, 0);
      for (int y = 0; y < image.height; y++) {
        int blackPixels = 0;
        for (int x = 0; x < image.width; x++) {
          var pixel = binaryImage.getPixel(x, y);
          int gray = img.getLuminance(pixel).round();
          if (gray < 128) {
            blackPixels++;
          }
        }
        horizontalProfile[y] = blackPixels;
      }
      
      // Detect text lines based on the profile
      bool inTextLine = false;
      int startY = 0;
      int minLineHeight = 15; // Minimum height for a text line
      
      for (int y = 0; y < image.height; y++) {
        // Start of a text line
        if (!inTextLine && horizontalProfile[y] > 0) {
          inTextLine = true;
          startY = y;
        }
        
        // End of a text line
        if (inTextLine && (horizontalProfile[y] == 0 || y == image.height - 1)) {
          inTextLine = false;
          int endY = y;
          int lineHeight = endY - startY;
          
          // Only consider lines with sufficient height
          if (lineHeight >= minLineHeight) {
            // Find the left and right boundaries of the text line
            int leftX = image.width;
            int rightX = 0;
            
            for (int lineY = startY; lineY < endY; lineY++) {
              for (int x = 0; x < image.width; x++) {
                var pixel = binaryImage.getPixel(x, lineY);
                int gray = img.getLuminance(pixel).round();
                if (gray < 128) {
                  leftX = x < leftX ? x : leftX;
                  rightX = x > rightX ? x : rightX;
                }
              }
            }
            
            // Add some margin to the line
            int margin = 5;
            leftX = (leftX - margin).clamp(0, image.width - 1);
            rightX = (rightX + margin).clamp(0, image.width - 1);
            startY = (startY - margin).clamp(0, image.height - 1);
            endY = (endY + margin).clamp(0, image.height - 1);
            
            // Add the text line to the result
            textLines.add({
              'x': leftX,
              'y': startY,
              'width': rightX - leftX + 1,
              'height': endY - startY + 1
            });
          }
        }
      }
      
      return textLines;
    } catch (e) {
      debugPrint('Error detecting text lines: $e');
      return textLines;
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
      
      // Apply adaptive contrast enhancement for better text visibility
      processedImage = _enhanceContrast(processedImage);
      
      // Apply edge enhancement to make text boundaries more distinct
      processedImage = _enhanceEdges(processedImage);
      
      // Apply noise reduction to clean up the image
      processedImage = img.gaussianBlur(processedImage, radius: 1);
      
      // Apply adaptive thresholding for better text/background separation with handwriting
      if (imageFile.path.contains('handwriting') || imageFile.path.contains('segment')) {
        processedImage = _applyAdaptiveThreshold(processedImage);
      }
      
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
  
  // Edge enhancement using Sobel operator to improve text boundary detection
  img.Image _enhanceEdges(img.Image image) {
    try {
      // Create a new image for the edge-enhanced result
      img.Image enhancedImage = img.Image(width: image.width, height: image.height);
      
      // Create a copy of the original image for edge detection
      img.Image edgeImage = img.Image(width: image.width, height: image.height);
      
      // Sobel operator kernels for X and Y directions
      List<List<int>> sobelX = [
        [-1, 0, 1],
        [-2, 0, 2],
        [-1, 0, 1]
      ];
      
      List<List<int>> sobelY = [
        [-1, -2, -1],
        [0, 0, 0],
        [1, 2, 1]
      ];
      
      // Edge enhancement strength - adjust as needed
      double edgeStrength = 1.5;
      
      // Apply Sobel operators to detect edges
      for (int y = 1; y < image.height - 1; y++) {
        for (int x = 1; x < image.width - 1; x++) {
          int gradientX = 0;
          int gradientY = 0;
          
          // Apply Sobel X and Y kernels
          for (int ky = -1; ky <= 1; ky++) {
            for (int kx = -1; kx <= 1; kx++) {
              int pixel = img.getLuminance(image.getPixel(x + kx, y + ky)).round();
              gradientX += pixel * sobelX[ky + 1][kx + 1];
              gradientY += pixel * sobelY[ky + 1][kx + 1];
            }
          }
          
          // Calculate gradient magnitude
          int magnitude = (gradientX.abs() + gradientY.abs()).round();
          
          // Normalize and store in edge image
          int edgeValue = (magnitude).clamp(0, 255);
          edgeImage.setPixel(x, y, img.ColorRgb8(edgeValue, edgeValue, edgeValue));
        }
      }
      
      // Blend the edge image with the original image
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          // Get pixel values from both images
          int originalValue = img.getLuminance(image.getPixel(x, y)).round();
          
          // For edge pixels, use the edge image value
          int edgeValue = 0;
          if (x > 0 && y > 0 && x < image.width - 1 && y < image.height - 1) {
            edgeValue = img.getLuminance(edgeImage.getPixel(x, y)).round();
          }
          
          // Enhance text edges by darkening edge pixels
          int newValue;
          if (edgeValue > 30) { // Edge threshold
            // Darken edges to enhance text boundaries
            newValue = (originalValue - (edgeValue * edgeStrength / 10).round()).clamp(0, 255);
          } else {
            // Keep original value for non-edge pixels
            newValue = originalValue;
          }
          
          enhancedImage.setPixel(x, y, img.ColorRgb8(newValue, newValue, newValue));
        }
      }
      
      return enhancedImage;
    } catch (e) {
      debugPrint('Error enhancing edges: $e');
      return image; // Return original image if edge enhancement fails
    }
  }
  
  // Apply adaptive thresholding for better text/background separation
  img.Image _applyAdaptiveThreshold(img.Image image) {
    try {
      // Create a new image with the same dimensions
      img.Image thresholdedImage = img.Image(width: image.width, height: image.height);
      
      // Window size for adaptive thresholding
      int windowSize = 15;
      double c = 5.0; // Constant subtracted from the mean
      
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          // Calculate the local mean in the window around the pixel
          int sum = 0;
          int count = 0;
          
          for (int wy = -windowSize ~/ 2; wy <= windowSize ~/ 2; wy++) {
            for (int wx = -windowSize ~/ 2; wx <= windowSize ~/ 2; wx++) {
              int nx = x + wx;
              int ny = y + wy;
              
              if (nx >= 0 && nx < image.width && ny >= 0 && ny < image.height) {
                sum += img.getLuminance(image.getPixel(nx, ny)).round();
                count++;
              }
            }
          }
          
          double mean = count > 0 ? sum / count : 0;
          
          // Apply threshold: if pixel < (mean - c), it's foreground (black), otherwise background (white)
          int pixelValue = img.getLuminance(image.getPixel(x, y)).round();
          int newValue = (pixelValue < (mean - c)) ? 0 : 255;
          
          thresholdedImage.setPixel(x, y, img.ColorRgb8(newValue, newValue, newValue));
        }
      }
      
      return thresholdedImage;
    } catch (e) {
      debugPrint('Error applying adaptive threshold: $e');
      return image; // Return original image if thresholding fails
    }
  }
  
  // Apply spell checking with a handwriting-specific dictionary
  String _applyHandwritingSpellChecking(String text) {
    if (text.isEmpty) return text;
    
    // Dictionary of common handwriting recognition errors
    Map<String, String> handwritingCorrections = {
      // Letter confusions
      'cl': 'd',
      'rn': 'm',
      'vv': 'w',
      'nn': 'm',
      'ii': 'u',
      // Common word errors
      'teh': 'the',
      'adn': 'and',
      'wiht': 'with',
      'frorn': 'from',
      'rnore': 'more',
      'sorne': 'some',
      'thier': 'their',
      'becuase': 'because',
      'recieve': 'receive',
      'differnt': 'different',
      'problen': 'problem',
      'problern': 'problem',
      'rnany': 'many',
      'tirne': 'time',
      'sarne': 'same',
      'narne': 'name',
      'horne': 'home',
    };
    
    // Split text into words and process each word
    List<String> words = text.split(' ');
    List<String> correctedWords = [];
    
    for (String word in words) {
      String correctedWord = word;
      
      // Check if the word is in our corrections dictionary
      handwritingCorrections.forEach((error, correction) {
        // Only replace if the error is the whole word
        if (correctedWord.toLowerCase() == error) {
          correctedWord = correction;
        }
      });
      
      correctedWords.add(correctedWord);
    }
    
    return correctedWords.join(' ');
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
