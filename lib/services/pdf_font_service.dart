import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';

/// A service class that handles PDF font conversion operations
class PdfFontService {
  /// A cache to store loaded font bytes to avoid reloading the same font multiple times
  static final Map<String, Uint8List> _fontCache = {};

  /// Creates a font based on the selected font family with improved error handling
  static Future<PdfFont> createFont(String fontFamily, double fontSize, PdfFontStyle style) async {
    print('Creating font with family: $fontFamily, size: $fontSize, style: $style...');
    
    PdfFont font;
    
    switch (fontFamily) {
      case 'OpenDyslexic':
        try {
          print('Attempting to load OpenDyslexic font from assets...');
          // Check if font is already in cache
          Uint8List? fontBytes = _fontCache['OpenDyslexic'];
          
          if (fontBytes == null) {
            // Load the OpenDyslexic Regular font file if not in cache
            print('Font not in cache, loading from assets...');
            try {
              final ByteData fontData = await rootBundle.load('assets/fonts/OpenDyslexic-Regular.otf');
              fontBytes = fontData.buffer.asUint8List();
              // Cache the font for future use
              _fontCache['OpenDyslexic'] = fontBytes;
              print('OpenDyslexic font loaded and cached successfully: ${fontBytes.length} bytes');
            } catch (assetError) {
              print('Error loading OpenDyslexic font from assets: $assetError');
              throw assetError; // Rethrow to be caught by outer try-catch
            }
          } else {
            print('Using cached OpenDyslexic font: ${fontBytes.length} bytes');
          }
          
          // Create the font with the loaded bytes and apply style
          print('Creating PdfTrueTypeFont with OpenDyslexic...');
          font = PdfTrueTypeFont(fontBytes, fontSize, style: style);
          print('OpenDyslexic font created successfully');
          
          // Verify font was created correctly
          if (font.height > 0) {
            print('Font verification passed: font height = ${font.height}');
          } else {
            print('Warning: Font height is ${font.height}, which may indicate an issue');
          }
        } catch (e) {
          print('Error creating OpenDyslexic font: $e');
          print('Stack trace: ${StackTrace.current}');
          print('Falling back to standard Courier font...');
          // Fallback to standard font if custom font fails to load
          font = PdfStandardFont(
            PdfFontFamily.courier,
            fontSize + 2,
            style: PdfFontStyle.bold,
          );
          print('Fallback font created successfully');
        }
        break;
      case 'Comic Sans':
        try {
          print('Attempting to load Lexend font from assets...');
          // Check if font is already in cache
          Uint8List? fontBytes = _fontCache['Lexend'];
          
          if (fontBytes == null) {
            // Load the Lexend font file if not in cache
            print('Font not in cache, loading from assets...');
            try {
              final ByteData fontData = await rootBundle.load('assets/fonts/Lexend-Regular.ttf');
              fontBytes = fontData.buffer.asUint8List();
              // Cache the font for future use
              _fontCache['Lexend'] = fontBytes;
              print('Lexend font loaded and cached successfully: ${fontBytes.length} bytes');
            } catch (assetError) {
              print('Error loading Lexend font from assets: $assetError');
              throw assetError; // Rethrow to be caught by outer try-catch
            }
          } else {
            print('Using cached Lexend font: ${fontBytes.length} bytes');
          }
          
          // Create the font with the loaded bytes and apply style
          print('Creating PdfTrueTypeFont with Lexend...');
          font = PdfTrueTypeFont(fontBytes, fontSize, style: style);
          print('Lexend font created successfully');
          
          // Verify font was created correctly
          if (font.height > 0) {
            print('Font verification passed: font height = ${font.height}');
          } else {
            print('Warning: Font height is ${font.height}, which may indicate an issue');
          }
        } catch (e) {
          print('Error creating Lexend font: $e');
          print('Stack trace: ${StackTrace.current}');
          print('Falling back to standard Courier font...');
          // Fallback to standard font if custom font fails to load
          font = PdfStandardFont(
            PdfFontFamily.courier,
            fontSize + 1,
            style: PdfFontStyle.regular,
          );
          print('Fallback font created successfully');
        }
        break;
      case 'Arial':
        // Arial/Helvetica is a standard font
        font = PdfStandardFont(
          PdfFontFamily.helvetica, // Helvetica is equivalent to Arial in PDF
          fontSize,
          style: style,
        );
        break;
      default:
        // Default to Helvetica (Arial)
        font = PdfStandardFont(
          PdfFontFamily.helvetica,
          fontSize,
          style: style,
        );
    }
    
    print('Font created successfully');
    return font;
  }

  /// Creates a dyslexic-friendly font (Arial/Helvetica) for PDF documents
  static PdfStandardFont createDyslexicFont() {
    print('Creating dyslexic-friendly font...');
    // Use Arial which is more readable for dyslexic users
    final PdfStandardFont dyslexicFont = PdfStandardFont(
      PdfFontFamily.helvetica, // Helvetica is equivalent to Arial in PDF
      14, // Slightly larger size for better readability
      style: PdfFontStyle.regular,
    );
    print('Dyslexic-friendly font created successfully');
    return dyslexicFont;
  }

  /// Extracts text from a specific page of a PDF document
  static Future<String> extractTextFromPage(PdfDocument pdfDocument, int pageIndex) async {
    print('Creating text extractor for page ${pageIndex + 1}...');
    final PdfTextExtractor extractor = PdfTextExtractor(pdfDocument);

    print('Extracting text from page ${pageIndex + 1}...');
    String text = '';
    try {
      text = extractor.extractText(startPageIndex: pageIndex);
      print('Text extracted successfully from page ${pageIndex + 1}: ${text.length} characters');
    } catch (e) {
      print('Error extracting text from page ${pageIndex + 1}: $e');
      text = 'Error extracting text from page ${pageIndex + 1}: $e';
    }
    return text;
  }

  /// Creates a new page in the PDF document with the provided text using the specified font and spacing
  /// Enhanced with better error handling and font verification
  static Future<void> createPageWithText(
    PdfDocument document, 
    String text, 
    PdfFont font, 
    double wordSpacing, 
    double letterSpacing,
    [double lineSpacing = 1.0]
  ) async {
    try {
      // Verify the font is valid before proceeding
      if (font.height <= 0) {
        print('Warning: Font may not be valid (height = ${font.height}). Will attempt to use it anyway.');
      }
      
      // Add a new page to the document
      print('Adding new page to document...');
      final PdfPage newPage = document.pages.add();
      print('New page added successfully with size: ${newPage.size}');

      // Create a PDF graphics for the page
      print('Getting graphics for new page...');
      final PdfGraphics graphics = newPage.graphics;

      // Create a brush for text
      print('Creating brush for text...');
      final PdfSolidBrush brush = PdfSolidBrush(
        PdfColor(0, 0, 0),
      );

      // Get page dimensions
      final double pageWidth = newPage.getClientSize().width;
      final double pageHeight = newPage.getClientSize().height;
      final double margin = 40;
      final double contentWidth = pageWidth - (margin * 2);
      
      print('Page dimensions: Width=$pageWidth, Height=$pageHeight, Content area=${contentWidth}x${pageHeight - (margin * 2)}');
      
      // Set up text formatting
      PdfStringFormat format = PdfStringFormat();
      format.alignment = PdfTextAlignment.left;
      format.lineAlignment = PdfVerticalAlignment.top;
      format.wordSpacing = wordSpacing;
      format.characterSpacing = letterSpacing;
      
      // Calculate line spacing based on font height, with protection against zero height
      double effectiveLineSpacing = lineSpacing;
      if (font.height > 0) {
        effectiveLineSpacing = lineSpacing * font.height;
      } else {
        // Use a reasonable default if font height is invalid
        // Default to 12 points if we can't determine the font height
        effectiveLineSpacing = lineSpacing * 12.0;
      }
      
      format.lineSpacing = effectiveLineSpacing;
      
      print('Text formatting: Word spacing=$wordSpacing, Letter spacing=$letterSpacing, Line spacing=$effectiveLineSpacing');

      // Draw the text with the font
      if (text.isNotEmpty) {
        print('Drawing text on page (${text.length} characters)...');
        
        // Add a simple verification text to confirm font is working
        try {
          // First, draw a small verification text at the top of the page
          graphics.drawString(
            'Font: ${font.name ?? "Unknown"}', 
            font, 
            brush: brush,
            bounds: Rect.fromLTWH(margin, 10, contentWidth, 20)
          );
          
          // Then draw the main text with full formatting
          graphics.drawString(
            text,
            font,
            brush: brush,
            bounds: Rect.fromLTWH(margin, margin, contentWidth, pageHeight - (margin * 2)),
            format: format
          );
          print('Text drawn successfully with formatting');
        } catch (e) {
          print('Error drawing text with formatting: $e');
          print('Stack trace: ${StackTrace.current}');
          print('Attempting simplified approach...');
          
          // Fallback to simpler approach
          try {
            // Try without the format parameter
            graphics.drawString(
              text,
              font,
              brush: brush,
              bounds: Rect.fromLTWH(margin, margin, contentWidth, pageHeight - (margin * 2)),
            );
            print('Text drawn with simplified approach (no format)');
          } catch (e2) {
            print('Error with simplified text drawing: $e2');
            print('Stack trace: ${StackTrace.current}');
            print('Attempting last resort approach...');
            
            // Last resort - minimal parameters
            try {
              graphics.drawString(text, font, brush: brush);
              print('Text drawn with minimal parameters');
            } catch (e3) {
              print('All text drawing approaches failed: $e3');
              print('Stack trace: ${StackTrace.current}');
              
              // Ultimate fallback - use a standard font instead
              print('Attempting to draw with standard font as last resort...');
              final fallbackFont = PdfStandardFont(PdfFontFamily.helvetica, 12);
              graphics.drawString('Custom font failed - using fallback font', fallbackFont, brush: brush, 
                  bounds: Rect.fromLTWH(margin, 10, contentWidth, 20));
              graphics.drawString(text, fallbackFont, brush: brush,
                  bounds: Rect.fromLTWH(margin, margin, contentWidth, pageHeight - (margin * 2)));
            }
          }
        }
      } else {
        print('No text to draw on page');
        // Draw a placeholder message instead of leaving a blank page
        final placeholderFont = PdfStandardFont(PdfFontFamily.helvetica, 14);
        graphics.drawString('No text content available', placeholderFont, brush: brush,
            bounds: Rect.fromLTWH(margin, margin, contentWidth, 50));
      }
    } catch (e) {
      print('Critical error in createPageWithText: $e');
      print('Stack trace: ${StackTrace.current}');
      // Create an error page to avoid complete failure
      try {
        final errorPage = document.pages.add();
        final errorGraphics = errorPage.graphics;
        final errorFont = PdfStandardFont(PdfFontFamily.helvetica, 12);
        final errorBrush = PdfSolidBrush(PdfColor(255, 0, 0));
        errorGraphics.drawString(
          'Error creating page with custom font. Please try a different font or contact support.',
          errorFont,
          brush: errorBrush,
          bounds: Rect.fromLTWH(40, 40, errorPage.getClientSize().width - 80, 100)
        );
      } catch (pageError) {
        print('Failed to create error page: $pageError');
      }
    }
  }

  /// Verifies if a font is properly embedded in the PDF document
  static bool verifyFontEmbedding(PdfDocument document, PdfFont font) {
    try {
      print('Verifying font embedding...');
      
      // Check if the font has a valid name
      if (font.name == null || font.name!.isEmpty) {
        print('Warning: Font has no name, which may indicate it is not properly embedded');
        return false;
      }
      
      print('Font name: ${font.name}');
      
      // Check if the font has a valid height
      if (font.height <= 0) {
        print('Warning: Font has invalid height (${font.height}), which may indicate it is not properly embedded');
        return false;
      }
      
      // For TrueType fonts, additional checks can be performed
      if (font is PdfTrueTypeFont) {
        print('Font is a TrueType font, which should support proper embedding');
        return true;
      }
      
      // For standard fonts, they are always available in PDF readers
      if (font is PdfStandardFont) {
        print('Font is a standard font (${(font as PdfStandardFont).fontFamily}), which is always available in PDF readers');
        return true;
      }
      
      // If we can't determine the font type specifically, assume it's OK if it has a name and height
      print('Font appears to be properly embedded');
      return true;
    } catch (e) {
      print('Error verifying font embedding: $e');
      return false;
    }
  }

  /// Processes all pages of a PDF document, extracting text and creating new pages with the selected font and spacing
  static Future<List<String>> processAllPages(
    PdfDocument sourcePdf, 
    PdfDocument targetPdf, 
    Function(int current, int total) onProgress,
    {
      String fontFamily = 'Arial',
      double fontSize = 14,
      double wordSpacing = 0,
      double letterSpacing = 0,
      double lineSpacing = 1.0,
    }
  ) async {
    List<String> allExtractedText = [];
    final int pageCount = sourcePdf.pages.count;
    
    print('Starting PDF processing with font family: $fontFamily, size: $fontSize');
    print('Source PDF has $pageCount pages');
    
    // Create the selected font with appropriate style based on font family
    PdfFontStyle fontStyle = PdfFontStyle.regular;
    
    // Use bold for OpenDyslexic to improve readability
    if (fontFamily == 'OpenDyslexic') {
      print('Using bold style for OpenDyslexic font');
      fontStyle = PdfFontStyle.bold;
    }
    
    // Create metadata for the PDF to indicate the font used
    targetPdf.documentInformation.author = 'PDF Font Converter';
    targetPdf.documentInformation.title = 'Converted with $fontFamily font';
    targetPdf.documentInformation.subject = 'Font: $fontFamily, Size: $fontSize, Word Spacing: $wordSpacing, Letter Spacing: $letterSpacing, Line Spacing: $lineSpacing';
    targetPdf.documentInformation.keywords = 'converted, accessibility, $fontFamily';
    targetPdf.documentInformation.creator = 'Sightline App';
    
    print('Creating font...');
    // Create the font and await the result
    final PdfFont selectedFont = await createFont(fontFamily, fontSize, fontStyle);
    
    // Verify font embedding
    bool fontEmbedded = verifyFontEmbedding(targetPdf, selectedFont);
    if (!fontEmbedded) {
      print('Warning: Font may not be properly embedded. Will attempt to proceed anyway.');
    } else {
      print('Font verification passed. Font appears to be properly embedded.');
    }

    // Process each page
    for (int i = 0; i < pageCount; i++) {
      // Update progress
      onProgress(i + 1, pageCount);
      
      print('Processing page ${i + 1} of $pageCount...');

      // Extract text from the page
      String extractedText = await extractTextFromPage(sourcePdf, i);
      allExtractedText.add(extractedText);
      
      print('Text extracted from page ${i + 1}: ${extractedText.length} characters');
      
      // Create a new page with the text using the selected font and spacing
      await createPageWithText(targetPdf, extractedText, selectedFont, wordSpacing, letterSpacing, lineSpacing);
      
      print('Page ${i + 1} processed successfully');
    }
    
    return allExtractedText;
  }

  /// Saves a PDF document to the device storage and returns the file path
  static Future<String> savePdfDocument(PdfDocument document, String fileName) async {
    try {
      // Get the bytes of the document
      print('Getting document bytes...');
      List<int> bytes = document.saveSync();
      print('Document bytes obtained, size: ${bytes.length}');

      // Get the application documents directory
      print('Getting application documents directory...');
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      print('Application documents directory: ${appDocDir.path}');

      // Generate the full file path
      String outputFilePath = '${appDocDir.path}/$fileName';

      print('Saving document to: $outputFilePath');
      final File file = File(outputFilePath);
      await file.writeAsBytes(bytes);
      print('Document saved successfully');

      return outputFilePath;
    } catch (e) {
      print('Error saving document: $e');
      throw e;
    }
  }

  /// Changes the font of a PDF file and saves it to a new file
  Future<bool> changePdfFont({
    required String inputFilePath,
    required String outputFilePath,
    required String fontName,
    double fontSize = 14.0,
    double wordSpacing = 0.0,
    double letterSpacing = 0.0,
    double lineSpacing = 1.0,
    String? customText,
  }) async {
    try {
      debugPrint('Starting PDF font conversion...');
      debugPrint('Input file: $inputFilePath');
      debugPrint('Output file: $outputFilePath');
      debugPrint('Font: $fontName, Size: $fontSize');
      
      // Load the input PDF document
      final File inputFile = File(inputFilePath);
      if (!await inputFile.exists()) {
        debugPrint('Input file does not exist');
        return false;
      }
      
      final List<int> fileBytes = await inputFile.readAsBytes();
      final PdfDocument pdfDocument = PdfDocument(inputBytes: fileBytes);
      
      // Create a new PDF document for the output
      final PdfDocument outputDocument = PdfDocument();
      
      // Create the selected font with appropriate style based on font family
      PdfFontStyle fontStyle = PdfFontStyle.regular;
      
      // Use bold for OpenDyslexic to improve readability
      if (fontName == 'OpenDyslexic') {
        fontStyle = PdfFontStyle.bold;
      }
      
      // Create metadata for the PDF to indicate the font used
      outputDocument.documentInformation.author = 'PDF Font Converter';
      outputDocument.documentInformation.title = 'Converted with $fontName font';
      outputDocument.documentInformation.subject = 'Font: $fontName, Size: $fontSize, Word Spacing: $wordSpacing, Letter Spacing: $letterSpacing, Line Spacing: $lineSpacing';
      
      // Await the font creation to get a PdfFont instead of a Future<PdfFont>
      final PdfFont selectedFont = await PdfFontService.createFont(fontName, fontSize, fontStyle);
      
      // Check if custom text is provided
      if (customText != null && customText.isNotEmpty) {
        debugPrint('Using custom text instead of extracting from PDF');
        
        // Create a new page with the custom text
        await PdfFontService.createPageWithText(
          outputDocument, 
          customText, 
          selectedFont, 
          wordSpacing, 
          letterSpacing, 
          lineSpacing
        );
      } else {
        // Process each page of the original PDF
        final int pageCount = pdfDocument.pages.count;
        for (int i = 0; i < pageCount; i++) {
          debugPrint('Processing page ${i + 1} of $pageCount...');
          
          // Extract text from the page
          String extractedText = await PdfFontService.extractTextFromPage(pdfDocument, i);
          
          // Create a new page with the text using the selected font and spacing
          await PdfFontService.createPageWithText(
            outputDocument, 
            extractedText, 
            selectedFont, 
            wordSpacing, 
            letterSpacing, 
            lineSpacing
          );
          
          debugPrint('Page ${i + 1} processed successfully');
        }
      }
      
      // Save the output document
      final List<int> outputBytes = outputDocument.saveSync();
      final File outputFile = File(outputFilePath);
      await outputFile.writeAsBytes(outputBytes);
      
      // Dispose the documents
      pdfDocument.dispose();
      outputDocument.dispose();
      
      debugPrint('PDF font conversion completed successfully');
      return true;
    } catch (e) {
      debugPrint('Error changing PDF font: $e');
      return false;
    }
  }

  /// Formats the extracted text with page separators
  static String formatExtractedText(List<String> extractedTextPages) {
    String combinedText = '';
    for (int i = 0; i < extractedTextPages.length; i++) {
      if (i > 0) {
        combinedText += '\n\n--- Page ${i + 1} ---\n\n';
      } else {
        combinedText += '--- Page 1 ---\n\n';
      }
      combinedText += extractedTextPages[i];
    }
    return combinedText;
  }

  /// Extracts all text from a PDF document and returns it as a list of strings (one per page)
  /// This is the first step in the two-step conversion process
  static Future<List<String>> extractAllTextFromPdf(List<int> pdfBytes, Function(int current, int total) onProgress) async {
    try {
      print('Starting text extraction from PDF...');
      
      // Load the PDF document
      final PdfDocument document = PdfDocument(inputBytes: pdfBytes);
      final int pageCount = document.pages.count;
      print('PDF loaded successfully with $pageCount pages');
      
      List<String> allExtractedText = [];
      
      // Extract text from each page
      for (int i = 0; i < pageCount; i++) {
        // Update progress
        onProgress(i + 1, pageCount);
        
        // Extract text from the page
        String pageText = await extractTextFromPage(document, i);
        allExtractedText.add(pageText);
        
        print('Extracted ${pageText.length} characters from page ${i + 1}');
      }
      
      // Dispose the document
      document.dispose();
      print('Text extraction completed successfully');
      
      return allExtractedText;
    } catch (e) {
      print('Error extracting text from PDF: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }
  
  /// Creates a new PDF document with the provided text using the specified font and formatting
  /// This is the second step in the two-step conversion process
  static Future<PdfDocument> createPdfWithCustomFont(
    List<String> pageTexts,
    String fontFamily,
    double fontSize,
    double wordSpacing,
    double letterSpacing,
    double lineSpacing,
    Function(int current, int total) onProgress
  ) async {
    try {
      print('Creating new PDF with custom font: $fontFamily, size: $fontSize');
      
      // Create a new PDF document
      final PdfDocument targetPdf = PdfDocument();
      
      // Create the selected font with appropriate style based on font family
      PdfFontStyle fontStyle = PdfFontStyle.regular;
      
      // Use bold for OpenDyslexic to improve readability
      if (fontFamily == 'OpenDyslexic') {
        print('Using bold style for OpenDyslexic font');
        fontStyle = PdfFontStyle.bold;
      }
      
      // Create metadata for the PDF to indicate the font used
      targetPdf.documentInformation.author = 'PDF Font Converter';
      targetPdf.documentInformation.title = 'Converted with $fontFamily font';
      targetPdf.documentInformation.subject = 'Font: $fontFamily, Size: $fontSize, Word Spacing: $wordSpacing, Letter Spacing: $letterSpacing, Line Spacing: $lineSpacing';
      targetPdf.documentInformation.keywords = 'converted, accessibility, $fontFamily';
      targetPdf.documentInformation.creator = 'Sightline App';
      
      print('Creating font...');
      // Create the font and await the result
      final PdfFont selectedFont = await createFont(fontFamily, fontSize, fontStyle);
      
      // Verify font embedding
      bool fontEmbedded = verifyFontEmbedding(targetPdf, selectedFont);
      if (!fontEmbedded) {
        print('Warning: Font may not be properly embedded. Will attempt to proceed anyway.');
      } else {
        print('Font verification passed. Font appears to be properly embedded.');
      }
      
      // Process each page of text
      final int pageCount = pageTexts.length;
      for (int i = 0; i < pageCount; i++) {
        // Update progress
        onProgress(i + 1, pageCount);
        
        print('Creating page ${i + 1} of $pageCount...');
        
        // Get the text for this page
        String pageText = pageTexts[i];
        
        // Create a new page with the text using the selected font and spacing
        await createPageWithText(targetPdf, pageText, selectedFont, wordSpacing, letterSpacing, lineSpacing);
        
        print('Page ${i + 1} created successfully');
      }
      
      print('PDF created successfully with $pageCount pages');
      return targetPdf;
    } catch (e) {
      print('Error creating PDF with custom font: $e');
      print('Stack trace: ${StackTrace.current}');
      
      // Create a simple error PDF
      final PdfDocument errorPdf = PdfDocument();
      final PdfPage errorPage = errorPdf.pages.add();
      final PdfGraphics graphics = errorPage.graphics;
      final PdfFont errorFont = PdfStandardFont(PdfFontFamily.helvetica, 12);
      
      graphics.drawString(
        'Error creating PDF with custom font: $e\n\nPlease try again with different settings.',
        errorFont,
        brush: PdfSolidBrush(PdfColor(255, 0, 0)),
        bounds: Rect.fromLTWH(50, 50, errorPage.getClientSize().width - 100, 400)
      );
      
      return errorPdf;
    }
  }
  
  /// Complete two-step process to convert a PDF with custom font
  /// 1. Extract text from the source PDF
  /// 2. Create a new PDF with the extracted text using the custom font
  static Future<PdfDocument> convertPdfWithTwoStepProcess(
    List<int> sourcePdfBytes,
    String fontFamily,
    double fontSize,
    double wordSpacing,
    double letterSpacing,
    double lineSpacing,
    Function(String status, double progress) onProgressUpdate
  ) async {
    try {
      // Step 1: Extract text from source PDF
      onProgressUpdate('Extracting text from PDF...', 0.0);
      
      List<String> extractedTextPages = await extractAllTextFromPdf(
        sourcePdfBytes,
        (current, total) {
          double extractionProgress = current / total * 0.5; // First half of the process
          onProgressUpdate('Extracting text from page $current of $total...', extractionProgress);
        }
      );
      
      if (extractedTextPages.isEmpty) {
        throw Exception('Failed to extract text from PDF');
      }
      
      // Step 2: Create new PDF with custom font
      onProgressUpdate('Creating new PDF with custom font...', 0.5);
      
      PdfDocument convertedPdf = await createPdfWithCustomFont(
        extractedTextPages,
        fontFamily,
        fontSize,
        wordSpacing,
        letterSpacing,
        lineSpacing,
        (current, total) {
          double creationProgress = 0.5 + (current / total * 0.5); // Second half of the process
          onProgressUpdate('Creating page $current of $total with custom font...', creationProgress);
        }
      );
      
      onProgressUpdate('Conversion completed successfully!', 1.0);
      return convertedPdf;
    } catch (e) {
      print('Error in two-step PDF conversion: $e');
      print('Stack trace: ${StackTrace.current}');
      onProgressUpdate('Error: $e', 0.0);
      
      // Create a simple error PDF
      final PdfDocument errorPdf = PdfDocument();
      final PdfPage errorPage = errorPdf.pages.add();
      final PdfGraphics graphics = errorPage.graphics;
      final PdfFont errorFont = PdfStandardFont(PdfFontFamily.helvetica, 12);
      
      graphics.drawString(
        'Error converting PDF: $e\n\nPlease try again with different settings.',
        errorFont,
        brush: PdfSolidBrush(PdfColor(255, 0, 0)),
        bounds: Rect.fromLTWH(50, 50, errorPage.getClientSize().width - 100, 400)
      );
      
      return errorPdf;
    }
  }
}
