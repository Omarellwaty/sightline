import 'package:flutter/material.dart';
import '../view_all_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RecentFilesTab extends StatelessWidget {
  final List<Map<String, dynamic>> recentFiles;
  final Set<int> selectedIndices;
  final bool isSelectionMode;
  final Function(Map<String, dynamic>, int) toggleFavorite;
  final Function(Map<String, dynamic>) shareFile;
  final Function(Map<String, dynamic>) openFile;
  final Function(int) onTap;
  final Function(int) onLongPress;
  final Function() cancelSelection;
  final Function() deleteSelected;

  const RecentFilesTab({
    Key? key,
    required this.recentFiles,
    required this.selectedIndices,
    required this.isSelectionMode,
    required this.toggleFavorite,
    required this.shareFile,
    required this.openFile,
    required this.onTap,
    required this.onLongPress,
    required this.cancelSelection,
    required this.deleteSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    if (recentFiles.isEmpty) {
      return _buildEmptyState(isDark);
    }

    return Column(
      children: [
        // Selection mode app bar
        if (isSelectionMode)
          _buildSelectionAppBar(isDark),
          
        // Files list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8),
            itemCount: recentFiles.length,
            itemBuilder: (context, index) {
              final file = recentFiles[index];
              final bool isSelected = selectedIndices.contains(index);
              
              return _buildFileListItem(
                context, 
                file, 
                index, 
                isSelected, 
                isDark
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 80,
            color: isDark ? Colors.white54 : Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No recent files',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your recently opened files will appear here',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white70 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionAppBar(bool isDark) {
    return Container(
      color: isDark ? Colors.grey[900] : Colors.grey[200],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            '${selectedIndices.length} selected',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: deleteSelected,
            color: Colors.red,
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: cancelSelection,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ],
      ),
    );
  }

  Widget _buildFileListItem(
    BuildContext context, 
    Map<String, dynamic> file, 
    int index, 
    bool isSelected, 
    bool isDark
  ) {
    final String fileName = file['name'] ?? 'Unnamed File';
    final String fileType = fileName.split('.').last.toUpperCase();
    
    // Handle different timestamp formats
    DateTime? timestamp;
    if (file['timestamp'] != null) {
      if (file['timestamp'] is int) {
        // Handle integer timestamp (milliseconds since epoch)
        timestamp = DateTime.fromMillisecondsSinceEpoch(file['timestamp']);
      } else if (file['timestamp'] is String) {
        // Handle string timestamp
        try {
          timestamp = DateTime.parse(file['timestamp']);
        } catch (e) {
          print('Error parsing timestamp string: $e');
        }
      } else if (file['timestamp'] is Timestamp) {
        // Handle Firebase Timestamp
        try {
          // Use the proper Timestamp class from cloud_firestore
          timestamp = (file['timestamp'] as Timestamp).toDate();
        } catch (e) {
          print('Error converting Firestore timestamp: $e');
        }
      }
    }
    
    final String timeAgo = timestamp != null 
      ? _getTimeAgo(timestamp) 
      : 'Unknown time';
    final bool isFavorite = file['isFavorite'] == true;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? Colors.blueGrey[700] : Colors.blue[50])
            : (isDark ? Colors.grey[850] : Colors.white),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getColorForFileType(fileType),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              fileType.length > 3 ? fileType.substring(0, 3) : fileType,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Text(
          fileName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          timeAgo,
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.grey,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isFavorite ? Icons.star : Icons.star_border,
                color: isFavorite ? Colors.amber : (isDark ? Colors.white70 : Colors.grey),
              ),
              onPressed: () => toggleFavorite(file, index),
            ),
            IconButton(
              icon: Icon(
                Icons.share,
                color: isDark ? Colors.white70 : Colors.grey,
              ),
              onPressed: () => shareFile(file),
            ),
          ],
        ),
        onTap: () {
          if (isSelectionMode) {
            onTap(index);
          } else {
            openFile(file);
          }
        },
        onLongPress: () => onLongPress(index),
        selected: isSelected,
      ),
    );
  }

  // These methods have been moved to the parent component
  // and are now passed in as callbacks

  Color _getColorForFileType(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year(s) ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month(s) ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day(s) ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour(s) ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute(s) ago';
    } else {
      return 'Just now';
    }
  }
}
