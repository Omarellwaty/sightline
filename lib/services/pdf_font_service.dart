import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';

/// A service class that handles PDF font conversion operations
class PdfFontService {
  /// Creates a font based on the selected font family
  static PdfFont createFont(String fontFamily, double fontSize, PdfFontStyle style) {
    print('Creating font with family: $fontFamily, size: $fontSize...');
    
    PdfFont font;
    
    switch (fontFamily) {
      case 'OpenDyslexic':
        // Since we can't embed OpenDyslexic font directly without the font file,
        // we'll create a distinctive font appearance for dyslexic users
        font = PdfStandardFont(
          PdfFontFamily.courier, // Courier is more readable for dyslexic users than Helvetica
          fontSize + 2, // Larger font size for better readability
          style: PdfFontStyle.bold, // Bold for better visibility
        );
        break;
      case 'Comic Sans':
        // Create a font that mimics Comic Sans characteristics
        font = PdfStandardFont(
          PdfFontFamily.courier, // Courier has more distinctive character shapes
          fontSize + 1, // Slightly larger
          style: PdfFontStyle.regular,
        );
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
  static Future<void> createPageWithText(
    PdfDocument document, 
    String text, 
    PdfFont font, 
    double wordSpacing, 
    double letterSpacing,
    [double lineSpacing = 1.0]
  ) async {
    // Add a new page to the document
    print('Adding new page to document...');
    final PdfPage newPage = document.pages.add();
    print('New page added successfully');

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
    
    // Set up text formatting
    PdfStringFormat format = PdfStringFormat();
    format.alignment = PdfTextAlignment.left;
    format.lineAlignment = PdfVerticalAlignment.top;
    format.wordSpacing = wordSpacing;
    format.characterSpacing = letterSpacing;
    format.lineSpacing = lineSpacing * font.height; // Apply line spacing

    // Draw the text with the font
    if (text.isNotEmpty) {
      print('Drawing text on page with word spacing: $wordSpacing, letter spacing: $letterSpacing...');
      try {
        // Draw text with formatting
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
        // Fallback to simpler approach
        try {
          graphics.drawString(
            text,
            font,
            brush: brush,
            bounds: Rect.fromLTWH(margin, margin, contentWidth, pageHeight - (margin * 2)),
          );
          print('Text drawn with simplified approach');
        } catch (e) {
          print('Error with simplified text drawing: $e');
          // Last resort
          graphics.drawString(text, font, brush: brush);
        }
      }
    } else {
      print('No text to draw on page');
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
    
    // Create the selected font with appropriate style based on font family
    PdfFontStyle fontStyle = PdfFontStyle.regular;
    
    // Use bold for OpenDyslexic to improve readability
    if (fontFamily == 'OpenDyslexic') {
      fontStyle = PdfFontStyle.bold;
    }
    
    // Create metadata for the PDF to indicate the font used
    targetPdf.documentInformation.author = 'PDF Font Converter';
    targetPdf.documentInformation.title = 'Converted with $fontFamily font';
    targetPdf.documentInformation.subject = 'Font: $fontFamily, Size: $fontSize, Word Spacing: $wordSpacing, Letter Spacing: $letterSpacing, Line Spacing: $lineSpacing';
    
    final selectedFont = createFont(fontFamily, fontSize, fontStyle);

    // Process each page
    for (int i = 0; i < pageCount; i++) {
      // Update progress
      onProgress(i + 1, pageCount);
      
      print('Processing page ${i + 1}...');

      // Extract text from the page
      String extractedText = await extractTextFromPage(sourcePdf, i);
      allExtractedText.add(extractedText);
      
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
      
      final selectedFont = PdfFontService.createFont(fontName, fontSize, fontStyle);
      
      // Process each page
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
}
