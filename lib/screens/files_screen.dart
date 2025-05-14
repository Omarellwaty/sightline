import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FilesScreen extends StatefulWidget {
  final List<Map<String, dynamic>> recentFiles;
  final Function(List<int>) onFilesDeleted;
  final Function(Map<String, dynamic>, int) onToggleFavorite;
  final Function(Map<String, dynamic>) onFileOpen;

  const FilesScreen({
    Key? key,
    required this.recentFiles,
    required this.onFilesDeleted,
    required this.onToggleFavorite,
    required this.onFileOpen,
  }) : super(key: key);

  @override
  _FilesScreenState createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<int> _selectedIndices = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Toggle selection of a file
  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        if (_selectedIndices.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  // Start selection mode
  void _startSelectionMode(int index) {
    setState(() {
      _isSelectionMode = true;
      _selectedIndices.add(index);
    });
  }

  // Cancel selection mode
  void _cancelSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedIndices.clear();
    });
  }

  // Delete selected files
  Future<void> _deleteSelected() async {
    final bool? confirm = await _showDeleteConfirmationDialog();
    
    if (confirm == true) {
      // Convert set to list and sort in descending order to avoid index shifting issues
      final List<int> selectedIndices = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));
      
      // Notify parent to update data
      widget.onFilesDeleted(selectedIndices);
      
      // Exit selection mode
      _cancelSelection();
      
      // Show feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${selectedIndices.length} file(s) deleted')),
      );
    }
  }

  Future<bool?> _showDeleteConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text('Are you sure you want to delete ${_selectedIndices.length} file(s)?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('DELETE'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Files'),
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _deleteSelected,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _cancelSelection,
                ),
              ]
            : null,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Recent'),
            Tab(text: 'Favorites'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Recent Files Tab
          _buildFilesList(widget.recentFiles, isDark),
          
          // Favorites Tab
          _buildFilesList(
            widget.recentFiles.where((file) => file['isFavorite'] == true).toList(),
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFilesList(List<Map<String, dynamic>> files, bool isDark) {
    if (files.isEmpty) {
      return _buildEmptyState(isDark);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final int originalIndex = widget.recentFiles.indexOf(file);
        final bool isSelected = _selectedIndices.contains(originalIndex);
        
        return _buildFileListItem(
          context, 
          file, 
          originalIndex, 
          isSelected, 
          isDark
        );
      },
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
            'No files found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _tabController.index == 0
                ? 'Your recently opened files will appear here'
                : 'Your favorite files will appear here',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white70 : Colors.grey,
            ),
            textAlign: TextAlign.center,
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
        timestamp = DateTime.fromMillisecondsSinceEpoch(file['timestamp']);
      } else if (file['timestamp'] is String) {
        try {
          timestamp = DateTime.parse(file['timestamp']);
        } catch (e) {
          print('Error parsing timestamp string: $e');
        }
      } else if (file['timestamp'] is Timestamp) {
        try {
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
            color: isDark ? Colors.white70 : Colors.grey[600],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isSelectionMode)
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : (isDark ? Colors.white70 : Colors.grey),
                ),
                onPressed: () => widget.onToggleFavorite(file, index),
              ),
            if (_isSelectionMode)
              Checkbox(
                value: isSelected,
                onChanged: (bool? value) {
                  _toggleSelection(index);
                },
                activeColor: Colors.blue,
              ),
          ],
        ),
        onTap: _isSelectionMode
            ? () => _toggleSelection(index)
            : () => widget.onFileOpen(file),
        onLongPress: _isSelectionMode
            ? null
            : () => _startSelectionMode(index),
      ),
    );
  }

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
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'txt':
        return Colors.purple;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Colors.teal;
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
