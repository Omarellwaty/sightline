import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FavoritesScreen extends StatefulWidget {
  final String userId;
  final Function(Map<String, dynamic>)? onFileSelected;

  const FavoritesScreen({
    Key? key,
    required this.userId,
    this.onFileSelected,
  }) : super(key: key);

  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final StorageService _storageService = StorageService();
  List<Map<String, dynamic>> _favoriteFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavoriteFiles();
  }

  Future<void> _loadFavoriteFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get favorite files directly using the dedicated method
      _favoriteFiles = await _databaseService.getFavoriteFiles(widget.userId);
      
      // Process timestamps to ensure they're in the correct format
      for (var file in _favoriteFiles) {
        // Handle uploadedAt timestamp
        if (file['uploadedAt'] != null && file['uploadedAt'] is Timestamp) {
          // Store the DateTime separately to avoid conversion issues
          file['uploadedAtDateTime'] = (file['uploadedAt'] as Timestamp).toDate();
        }
        
        // Handle timestamp field
        if (file['timestamp'] != null) {
          if (file['timestamp'] is Timestamp) {
            file['timestampDateTime'] = (file['timestamp'] as Timestamp).toDate();
          } else if (file['timestamp'] is String) {
            try {
              file['timestampDateTime'] = DateTime.parse(file['timestamp']);
            } catch (e) {
              file['timestampDateTime'] = DateTime.now();
              print('Error parsing timestamp string: $e');
            }
          }
        }
      }
      
      // Sort by most recently added using the pre-processed DateTime fields
      _favoriteFiles.sort((a, b) {
        DateTime dateA;
        DateTime dateB;
        
        // Use the pre-processed DateTime fields for reliable sorting
        if (a['uploadedAtDateTime'] != null) {
          dateA = a['uploadedAtDateTime'];
        } else if (a['timestampDateTime'] != null) {
          dateA = a['timestampDateTime'];
        } else {
          dateA = DateTime.now();
        }
        
        if (b['uploadedAtDateTime'] != null) {
          dateB = b['uploadedAtDateTime'];
        } else if (b['timestampDateTime'] != null) {
          dateB = b['timestampDateTime'];
        } else {
          dateB = DateTime.now();
        }
        
        return dateB.compareTo(dateA); // Most recent first
      });
    } catch (e) {
      print('Error loading favorite files: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading favorite files: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite(Map<String, dynamic> file) async {
    try {
      // Toggle favorite status
      bool newFavoriteStatus = !(file['isFavorite'] ?? false);
      
      // Update in Firestore
      await _databaseService.updateFileFavoriteStatus(
        widget.userId, 
        file['id'], 
        newFavoriteStatus
      );
      
      // Refresh the list
      _loadFavoriteFiles();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newFavoriteStatus 
          ? 'Added to favorites' 
          : 'Removed from favorites')),
      );
    } catch (e) {
      print('Error toggling favorite status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating favorite status: $e')),
      );
    }
  }

  Future<void> _downloadFile(Map<String, dynamic> file) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading file...')),
      );
      
      // Get the download URL
      String downloadUrl = file['downloadURL'] ?? file['downloadUrl'];
      
      // Download the file
      final http.Response response = await http.get(Uri.parse(downloadUrl));
      
      // Get the temporary directory
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath = '${tempDir.path}/${file['fileName']}';
      
      // Write the file
      final File downloadedFile = File(filePath);
      await downloadedFile.writeAsBytes(response.bodyBytes);
      
      // Share the file
      await Share.shareFiles([filePath], text: 'Sharing ${file['fileName']}');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File downloaded successfully')),
      );
    } catch (e) {
      print('Error downloading file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading file: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorite Files'),
        backgroundColor: isDark ? Colors.black : Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFavoriteFiles,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favoriteFiles.isEmpty
              ? _buildEmptyState(isDark)
              : _buildFilesList(isDark),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.star_border,
            size: 80,
            color: isDark ? Colors.purple.withOpacity(0.5) : Colors.blue.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No favorite files yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.blueGrey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add files to your favorites from the home screen',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white60 : Colors.blueGrey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _favoriteFiles.length,
      itemBuilder: (context, index) {
        final file = _favoriteFiles[index];
        final String fileName = file['fileName'] ?? file['name'] ?? 'Unnamed file';
        final String fileType = file['type'] ?? 'unknown';
        // Use the pre-processed DateTime fields for display
        DateTime timestamp;
        if (file['uploadedAtDateTime'] != null) {
          timestamp = file['uploadedAtDateTime'];
        } else if (file['timestampDateTime'] != null) {
          timestamp = file['timestampDateTime'];
        } else {
          // Fallback to current time if no timestamp is available
          timestamp = DateTime.now();
        }
        
        IconData fileIcon;
        Color fileColor;
        
        // Determine icon and color based on file type
        switch (fileType) {
          case 'pdf':
            fileIcon = Icons.picture_as_pdf;
            fileColor = Colors.red;
            break;
          case 'extracted_text_pdfs':
            fileIcon = Icons.text_snippet;
            fileColor = Colors.green;
            break;
          case 'image':
            fileIcon = Icons.image;
            fileColor = Colors.blue;
            break;
          default:
            fileIcon = Icons.insert_drive_file;
            fileColor = Colors.orange;
        }
        
        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isDark 
                ? BorderSide(color: Colors.purple.withOpacity(0.5), width: 1) 
                : BorderSide.none,
          ),
          color: isDark ? Colors.black : null,
          child: InkWell(
            onTap: () {
              if (widget.onFileSelected != null) {
                widget.onFileSelected!(file);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(fileIcon, color: fileColor, size: 36),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fileName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Added on ${timestamp.day}/${timestamp.month}/${timestamp.year}',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.star,
                          color: Colors.amber,
                        ),
                        onPressed: () => _toggleFavorite(file),
                        tooltip: 'Remove from favorites',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.download),
                        label: const Text('Download'),
                        onPressed: () => _downloadFile(file),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open'),
                        onPressed: () {
                          if (widget.onFileSelected != null) {
                            widget.onFileSelected!(file);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
