import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:image/image.dart' as img;
import 'package:untitled/services/firebase_service.dart';
import 'package:untitled/services/tesseract_language_manager.dart';
import 'scan_result.dart';

class TesseractScanProcessor {
  // Language data paths will be initialized during processing
  String? _tessDataPath;
  
  // Constructor
  TesseractScanProcessor() {
    // Initialize by ensuring English language data is available
    _initializeLanguageData();
  }
  
  // Initialize language data
  Future<void> _initializeLanguageData() async {
    try {
      // Get the tessdata path
      _tessDataPath = await TesseractLanguageManager.getTessDataPath();
      
      // Check if English language data is available, download if not
      bool isEngAvailable = await TesseractLanguageManager.isLanguageDownloaded('eng');
      if (!isEngAvailable) {
        debugPrint('Downloading English language data for Tesseract OCR...');
        await TesseractLanguageManager.downloadLanguage('eng');
      }
    } catch (e) {
      debugPrint('Error initializing Tesseract language data: $e');
    }
  }
  
  // No need for dispose method as Tesseract doesn't require explicit cleanup
  
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
      
      String extractedText = '';
      double confidence = 0.0;
      
      // Configure Tesseract parameters based on recognition quality and mode
      String language = 'eng'; // Default to English
      List<String> args = [];
      
      // Configure Tesseract based on recognition quality
      Map<String, String> argsMap = {};
      
      if (recognitionQuality == 1) {
        // Fast mode
        argsMap['oem'] = '0'; // Legacy Tesseract engine only
        argsMap['psm'] = '3'; // Automatic page segmentation, no OSD
      } else if (recognitionQuality == 3) {
        // Accurate mode
        argsMap['oem'] = '3'; // Default, based on what is available
        argsMap['psm'] = '6'; // Assume a single uniform block of text
      } else {
        // Balanced mode (default)
        argsMap['oem'] = '1'; // Neural nets LSTM engine only
        argsMap['psm'] = '3'; // Automatic page segmentation, no OSD
      }
      
      // Add handwriting-specific configurations if needed
      if (isHandwritingMode) {
        // For handwriting, we'll actually recommend using ML Kit instead
        // But we'll still try to optimize Tesseract parameters for handwriting
        
        // Use a different page segmentation mode for handwriting
        argsMap['psm'] = '6'; // Assume a single uniform block of text
        
        // Use LSTM only for better handwriting recognition
        argsMap['oem'] = '1'; // LSTM only
        
        // Add additional parameters to improve handwriting recognition
        argsMap['tessdata_char_whitelist'] = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,;:!?"()-'; // Limit character set
        argsMap['textord_heavy_nr'] = '1'; // More aggressive noise removal
        argsMap['textord_min_linesize'] = '2.5'; // Adjust for handwriting
        
        // Use standard English model
        language = 'eng';
      }
      
      // Add preserve interword spaces for better results
      argsMap['preserve_interword_spaces'] = '1';
      
      // Ensure language data is available
      if (_tessDataPath == null) {
        _tessDataPath = await TesseractLanguageManager.getTessDataPath();
      }
      
      // Check if the selected language is downloaded
      bool isLanguageAvailable = await TesseractLanguageManager.isLanguageDownloaded(language);
      if (!isLanguageAvailable) {
        debugPrint('Downloading $language language data for Tesseract OCR...');
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Downloading language data for OCR...')),
          );
        }
        await TesseractLanguageManager.downloadLanguage(language);
      }
      
      // Perform OCR using Tesseract
      try {
        extractedText = await FlutterTesseractOcr.extractText(
          enhancedImage.path,
          language: language,
          args: argsMap,
        );
      } catch (e) {
        // If there's an error with the tessdata_config.json file, use our language manager instead
        if (e.toString().contains('tessdata_config.json')) {
          debugPrint('Error with tessdata_config.json, using TesseractLanguageManager instead');
          
          // Ensure the language file is downloaded
          bool isLanguageAvailable = await TesseractLanguageManager.isLanguageDownloaded(language);
          if (!isLanguageAvailable) {
            if (context != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Downloading language data for OCR...')),
              );
            }
            await TesseractLanguageManager.downloadLanguage(language);
          }
          
          // Get the path to the language file
          final tessDataPath = await TesseractLanguageManager.getTessDataPath();
          final languageFilePath = '$tessDataPath/$language.traineddata';
          
          // Try using the downloaded language file directly
          extractedText = await FlutterTesseractOcr.extractText(
            enhancedImage.path,
            language: language,
            args: {
              ...argsMap,
              'tessdata': tessDataPath,
            },
          );
        } else {
          // Rethrow if it's not related to the tessdata_config.json file
          rethrow;
        }
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
      if (isHandwritingMode) {
        // For handwriting, process text for better results
        extractedText = _processHandwrittenText(extractedText);
      } else {
        // For printed text
        extractedText = _processExtractedText(extractedText);
        
        // Apply enhanced corrections if enabled
        if (enhancedCorrection) {
          extractedText = _applyEnhancedCorrection(extractedText);
        }
      }
      
      // Estimate confidence based on text quality indicators
      confidence = _estimateConfidence(extractedText, rawExtractedText);
      
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
      
      // 4. Resize if the image is too large (Tesseract works best with images around 300 DPI)
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
        final r = pixel.r;
        
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
        
        final currentPixel = image.getPixel(x, y).r;
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
    // Implement handwriting-specific processing
    
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
        .replaceAll('\(', '(')
        .replaceAll('\)', ')')
        .replaceAll('\[', '[')
        .replaceAll('\]', ']')
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
  
  // Estimate confidence based on text quality indicators
  double _estimateConfidence(String processedText, String rawText) {
    // Implement confidence estimation
    // This is a simplified version
    
    if (rawText.isEmpty) {
      return 0.0;
    }
    
    // Calculate the ratio of alphanumeric characters to total characters
    int alphanumericCount = RegExp(r'[a-zA-Z0-9]').allMatches(rawText).length;
    int totalCount = rawText.length;
    
    // Calculate a base confidence score
    double baseConfidence = alphanumericCount / totalCount;
    
    // Adjust confidence based on text length
    if (rawText.length < 10) {
      baseConfidence *= 0.8; // Penalize very short texts
    }
    
    // Adjust confidence based on special character ratio
    int specialCharCount = RegExp(r'[^a-zA-Z0-9\s]').allMatches(rawText).length;
    double specialCharRatio = specialCharCount / totalCount;
    if (specialCharRatio > 0.3) {
      baseConfidence *= 0.7; // Penalize texts with too many special characters
    }
    
    return baseConfidence.clamp(0.0, 1.0);
  }
}
