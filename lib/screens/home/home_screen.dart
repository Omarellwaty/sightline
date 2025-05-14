import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../view_all_screen.dart';
import 'recent_files_tab.dart';
import 'pdf_upload_tab.dart';
import 'smart_scan_tab.dart';
import 'file_operations.dart';
import 'file_handler.dart';
import 'home_screen_components.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<Map<String, dynamic>> recentFiles;
  final Function(List<int>) onFilesDeleted; // Callback to notify MainScreen of deletions
  final Function(Map<String, dynamic>) onFileUploaded; // Callback to add new files

  const HomeScreen({
    Key? key, 
    required this.recentFiles, 
    required this.onFilesDeleted,
    required this.onFileUploaded,
  }) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final Set<int> _selectedIndices = {};
  late TabController _tabController;
  int _currentTabIndex = 0;
  bool _isSelectionMode = false;
  bool _isAdmin = false;
  
  // Helper classes
  late FileOperations _fileOperations;
  late FileHandler _fileHandler;
  
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
        // Exit selection mode when changing tabs
        if (_isSelectionMode) {
          _cancelSelection();
        }
      });
    });
    
    // Initialize helper classes
    _fileOperations = FileOperations(
      context: context,
      onFileUploaded: widget.onFileUploaded,
    );
    
    _fileHandler = FileHandler(
      context: context,
      onFileUploaded: widget.onFileUploaded,
    );
    
    // Check if current user is admin
    _checkAdminStatus();
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
    final bool? confirm = await HomeScreenComponents.showDeleteConfirmationDialog(context);
    
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

  // Toggle favorite status
  Future<void> _toggleFavorite(Map<String, dynamic> file, int index) async {
    await _fileOperations.toggleFavorite(file, index, widget.recentFiles);
    setState(() {
      // Update UI with new favorite status
      widget.recentFiles[index]['isFavorite'] = !widget.recentFiles[index]['isFavorite'];
    });
  }

  // Share file
  Future<void> _shareFile(Map<String, dynamic> file) async {
    await _fileOperations.shareFile(file);
  }

  // Pick PDF file
  Future<void> _pickPDF() async {
    await _fileOperations.pickPDF();
  }

  // Pick image for smart scan
  Future<void> _pickImageForSmartScan(ImageSource source) async {
    await _fileOperations.pickImageForSmartScan(source);
  }
  
  // Show scan options dialog
  void _showScanOptions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choose Scan Method'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImageForSmartScan(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImageForSmartScan(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Open file
  Future<void> _openFile(Map<String, dynamic> file) async {
    await _fileHandler.openFile(file);
  }
  
  // Check if current user is an admin
  Future<void> _checkAdminStatus() async {
    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _isAdmin = userData['isAdmin'] == true;
        });
      }
    }
  }
  
  // Navigate to profile screen
  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Sightline'),
        actions: [
          if (_currentTabIndex == 0 && widget.recentFiles.isNotEmpty && !_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.view_list),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ViewAllScreen(
                      title: 'All Files',
                      items: widget.recentFiles,
                    ),
                  ),
                );
              },
            ),
          // Profile button - available to all users
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: 'My Profile',
            onPressed: _navigateToProfile,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Recent files'),
            Tab(text: 'pdf tools'),
            Tab(text: 'Smart Scan'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Recent Files
          RecentFilesTab(
            recentFiles: widget.recentFiles,
            selectedIndices: _selectedIndices,
            isSelectionMode: _isSelectionMode,
            toggleFavorite: _toggleFavorite,
            shareFile: _shareFile,
            openFile: _openFile,
            onTap: _toggleSelection,
            onLongPress: _startSelectionMode,
            cancelSelection: _cancelSelection,
            deleteSelected: _deleteSelected,
          ),
          
          // Tab 2: PDF Upload
          PdfUploadTab(
            pickPDF: _pickPDF,
            onFileUploaded: widget.onFileUploaded,
          ),
          
          // Tab 3: Smart Scan
          SmartScanTab(
            onStartScan: _showScanOptions,
          ),
        ],
      ),
    );
  }
}
