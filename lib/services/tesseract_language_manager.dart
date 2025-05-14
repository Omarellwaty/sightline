import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class TesseractLanguageManager {
  static const String _baseUrl = 'https://github.com/tesseract-ocr/tessdata/raw/main/';
  static const Map<String, String> _availableLanguages = {
    'eng': 'English',
    'ara': 'Arabic',
    'chi_sim': 'Chinese (Simplified)',
    'chi_tra': 'Chinese (Traditional)',
    'deu': 'German',
    'fra': 'French',
    'hin': 'Hindi',
    'ita': 'Italian',
    'jpn': 'Japanese',
    'kor': 'Korean',
    'por': 'Portuguese',
    'rus': 'Russian',
    'spa': 'Spanish',
    'tur': 'Turkish',
  };
  
  // Get available languages
  static Map<String, String> getAvailableLanguages() {
    return _availableLanguages;
  }
  
  // Check if a language is downloaded
  static Future<bool> isLanguageDownloaded(String languageCode) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final tessDataPath = '${directory.path}/tessdata';
      final languageFile = File('$tessDataPath/$languageCode.traineddata');
      
      return await languageFile.exists();
    } catch (e) {
      debugPrint('Error checking language file: $e');
      return false;
    }
  }
  
  // Get the tessdata directory path
  static Future<String> getTessDataPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final tessDataPath = '${directory.path}/tessdata';
    
    // Create the directory if it doesn't exist
    final tessDataDir = Directory(tessDataPath);
    if (!await tessDataDir.exists()) {
      await tessDataDir.create(recursive: true);
    }
    
    return tessDataPath;
  }
  
  // Download a language file
  static Future<bool> downloadLanguage(String languageCode, {Function(double)? onProgress}) async {
    try {
      // Get the tessdata directory path
      final tessDataPath = await getTessDataPath();
      final languageFile = File('$tessDataPath/$languageCode.traineddata');
      
      // Check if the file already exists
      if (await languageFile.exists()) {
        return true;
      }
      
      // Download the file
      final url = '$_baseUrl$languageCode.traineddata';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        // Write the file
        await languageFile.writeAsBytes(response.bodyBytes);
        return true;
      } else {
        debugPrint('Failed to download language file: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('Error downloading language file: $e');
      return false;
    }
  }
  
  // Download multiple languages
  static Future<Map<String, bool>> downloadLanguages(List<String> languageCodes, {Function(double)? onProgress}) async {
    Map<String, bool> results = {};
    
    for (int i = 0; i < languageCodes.length; i++) {
      final languageCode = languageCodes[i];
      final result = await downloadLanguage(languageCode);
      results[languageCode] = result;
      
      if (onProgress != null) {
        onProgress((i + 1) / languageCodes.length);
      }
    }
    
    return results;
  }
  
  // Delete a language file
  static Future<bool> deleteLanguage(String languageCode) async {
    try {
      final tessDataPath = await getTessDataPath();
      final languageFile = File('$tessDataPath/$languageCode.traineddata');
      
      if (await languageFile.exists()) {
        await languageFile.delete();
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error deleting language file: $e');
      return false;
    }
  }
  
  // Get downloaded languages
  static Future<List<String>> getDownloadedLanguages() async {
    try {
      final tessDataPath = await getTessDataPath();
      final tessDataDir = Directory(tessDataPath);
      
      if (!await tessDataDir.exists()) {
        return [];
      }
      
      final files = await tessDataDir.list().toList();
      final languageCodes = files
          .where((file) => file.path.endsWith('.traineddata'))
          .map((file) => file.path.split('/').last.split('.').first)
          .toList();
      
      return languageCodes;
    } catch (e) {
      debugPrint('Error getting downloaded languages: $e');
      return [];
    }
  }
}
