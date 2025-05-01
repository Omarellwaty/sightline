import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

import 'smart_scan_processor.dart';
import 'smart_scan_result_screen.dart';

class SmartScanHomeScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onFileUploaded;

  const SmartScanHomeScreen({super.key, required this.onFileUploaded});

  @override
  State<SmartScanHomeScreen> createState() => _SmartScanHomeScreenState();
}

class _SmartScanHomeScreenState extends State<SmartScanHomeScreen> {
  bool _isProcessing = false;
  String _statusMessage = '';
  bool _isHandwritingMode = false;
  int _recognitionQuality = 2; // 1=fast, 2=balanced, 3=accurate
  bool _enhancedCorrection = true;
  
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickImageFromCamera() async {
    try {
      bool permissionsGranted = await _checkAndRequestPermissions();
      if (!permissionsGranted) return;
      
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
      );
      
      if (pickedFile != null) {
        setState(() {
          _isProcessing = true;
          _statusMessage = 'Processing image...';
        });
        
        await _processImage(File(pickedFile.path));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
      setState(() {
        _isProcessing = false;
        _statusMessage = '';
      });
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      bool permissionsGranted = await _checkAndRequestPermissions();
      if (!permissionsGranted) return;
      
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      
      if (pickedFile != null) {
        setState(() {
          _isProcessing = true;
          _statusMessage = 'Processing image...';
        });
        
        await _processImage(File(pickedFile.path));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
      setState(() {
        _isProcessing = false;
        _statusMessage = '';
      });
    }
  }

  Future<void> _processImage(File imageFile) async {
    try {
      final SmartScanProcessor processor = SmartScanProcessor();
      
      // Process the image
      final result = await processor.processImage(
        imageFile: imageFile,
        isHandwritingMode: _isHandwritingMode,
        recognitionQuality: _recognitionQuality,
        enhancedCorrection: _enhancedCorrection,
        context: context, // Pass context for Firebase upload
      );
      
      if (!mounted) return;
      
      setState(() {
        _isProcessing = false;
        _statusMessage = '';
      });
      
      // Call the onFileUploaded callback with the result
      widget.onFileUploaded({
        'text': result.text,
        'confidence': result.confidence,
        'isHandwritingMode': _isHandwritingMode,
      });
      
      // Navigate to result screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SmartScanResultScreen(
            extractedText: result.text,
            isHandwritingMode: _isHandwritingMode,
          ),
        ),
      );
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing image: $e')),
      );
      setState(() {
        _isProcessing = false;
        _statusMessage = '';
      });
    }
  }

  Future<bool> _checkAndRequestPermissions() async {
    try {
      // Check Android version
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkVersion = androidInfo.version.sdkInt;
      
      if (sdkVersion >= 33) {
        // Android 13+ uses granular permissions
        final cameraStatus = await Permission.camera.request();
        final photosStatus = await Permission.photos.request();
        
        if (cameraStatus.isDenied || photosStatus.isDenied) {
          if (!mounted) return false;
          _showPermissionDeniedDialog('Camera or Photos');
          return false;
        }
        
        return true;
      } else {
        // Older Android versions
        final cameraStatus = await Permission.camera.request();
        final storageStatus = await Permission.storage.request();
        
        if (cameraStatus.isDenied || storageStatus.isDenied) {
          if (!mounted) return false;
          _showPermissionDeniedDialog('Camera or Storage');
          return false;
        }
        
        return true;
      }
    } catch (e) {
      debugPrint('Error checking permissions: $e');
      return false;
    }
  }

  void _showPermissionDeniedDialog(String permissionType) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Permission Required'),
          content: Text('$permissionType permission is required to use this feature. Please enable it in app settings.'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Open Settings'),
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Camera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImageFromCamera();
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImageFromGallery();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Scan Settings'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handwriting mode toggle
                    SwitchListTile(
                      title: Text('Handwriting Mode'),
                      subtitle: Text('Optimize for handwritten text'),
                      value: _isHandwritingMode,
                      onChanged: (value) {
                        setState(() {
                          _isHandwritingMode = value;
                        });
                      },
                    ),
                    
                    Divider(),
                    
                    // Recognition quality
                    Text('Recognition Quality', style: TextStyle(fontWeight: FontWeight.bold)),
                    RadioListTile(
                      title: Text('Fast'),
                      subtitle: Text('Lower quality, faster processing'),
                      value: 1,
                      groupValue: _recognitionQuality,
                      onChanged: (value) {
                        setState(() {
                          _recognitionQuality = value as int;
                        });
                      },
                    ),
                    RadioListTile(
                      title: Text('Balanced'),
                      subtitle: Text('Good quality, reasonable speed'),
                      value: 2,
                      groupValue: _recognitionQuality,
                      onChanged: (value) {
                        setState(() {
                          _recognitionQuality = value as int;
                        });
                      },
                    ),
                    RadioListTile(
                      title: Text('Accurate'),
                      subtitle: Text('Best quality, slower processing'),
                      value: 3,
                      groupValue: _recognitionQuality,
                      onChanged: (value) {
                        setState(() {
                          _recognitionQuality = value as int;
                        });
                      },
                    ),
                    
                    Divider(),
                    
                    // Enhanced correction toggle
                    SwitchListTile(
                      title: Text('Enhanced Correction'),
                      subtitle: Text('Apply advanced text corrections'),
                      value: _enhancedCorrection,
                      onChanged: (value) {
                        setState(() {
                          _enhancedCorrection = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: Text('Apply'),
                  onPressed: () {
                    this.setState(() {
                      // Update the main state with dialog values
                      this._isHandwritingMode = _isHandwritingMode;
                      this._recognitionQuality = _recognitionQuality;
                      this._enhancedCorrection = _enhancedCorrection;
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getQualityLabel() {
    switch (_recognitionQuality) {
      case 1:
        return 'Fast';
      case 2:
        return 'Balanced';
      case 3:
        return 'Accurate';
      default:
        return 'Balanced';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Smart Scan'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header section
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart Text Scanner',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Scan printed or handwritten text from images',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Current settings display
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Mode:'),
                        Chip(
                          label: Text(
                            _isHandwritingMode ? 'Handwriting' : 'Printed Text',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: _isHandwritingMode ? Colors.purple : Colors.blue,
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Quality:'),
                        Chip(
                          label: Text(
                            _getQualityLabel(),
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.green,
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Enhanced Correction:'),
                        Chip(
                          label: Text(
                            _enhancedCorrection ? 'On' : 'Off',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: _enhancedCorrection ? Colors.teal : Colors.grey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Main action area
            Expanded(
              child: _isProcessing
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(_statusMessage),
                      ],
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.document_scanner,
                          size: 100,
                          color: Colors.blue,
                        ),
                        SizedBox(height: 24),
                        Text(
                          'Tap the button below to scan text',
                          style: TextStyle(
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isProcessing
        ? null
        : FloatingActionButton.extended(
            onPressed: _showImageSourceDialog,
            icon: Icon(Icons.camera_alt),
            label: Text('Scan'),
          ),
    );
  }
}
