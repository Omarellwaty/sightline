import 'package:flutter/material.dart';
import 'data/data_model/user_data.dart';
import 'screens/registration_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/context_aware_home_screen.dart';
import 'screens/files_screen.dart';
import 'screens/user_info.dart';
import 'screens/settings_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'providor/auth_service.dart';
import 'services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<bool> isDarkThemeNotifier = ValueNotifier(false);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Load theme preference
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('isDarkTheme') ?? false;
  isDarkThemeNotifier.value = isDark;
  
  // Listen for theme changes and save them
  isDarkThemeNotifier.addListener(() {
    prefs.setBool('isDarkTheme', isDarkThemeNotifier.value);
  });
  
  runApp(DyslexiaApp());
}

class DyslexiaApp extends StatefulWidget {
  @override
  _DyslexiaAppState createState() => _DyslexiaAppState();
}

class _DyslexiaAppState extends State<DyslexiaApp> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  bool _isInitialized = false;
  bool _isAuthenticated = false;
  UserData? _userData;
  List<Map<String, dynamic>> _recentFiles = [];
  
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }
  
  Future<void> _checkAuthState() async {
    try {
      // Check if user is already signed in
      User? currentUser = _authService.currentUser;
      
      if (currentUser != null) {
        print('User is already signed in: ${currentUser.email}');
        
        // Load user data
        _userData = UserData(
          email: currentUser.email ?? '',
          password: '', // We don't store the password
        );
        
        // Load recent files from Firestore
        try {
          final currentUser = FirebaseAuth.instance.currentUser;
          final userId = currentUser?.uid ?? 'guest_user';
          final files = await _databaseService.getUserFiles(userId);
          if (files.isNotEmpty) {
            setState(() {
              _recentFiles = files;
              _isAuthenticated = true;
            });
          }
        } catch (e) {
          print('Error loading recent files: $e');
        }
        
        setState(() {
          _isAuthenticated = true;
        });
      }
      
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Error checking auth state: $e');
      setState(() {
        _isInitialized = true;
        _isAuthenticated = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkThemeNotifier,
      builder: (context, isDarkTheme, child) {
        return MaterialApp(
          theme: isDarkTheme
              ? ThemeData.dark().copyWith(
                  primaryColor: Colors.purple,
                  scaffoldBackgroundColor: Colors.black,
                  colorScheme: ColorScheme.dark(
                    primary: Colors.purple,
                    secondary: Colors.purpleAccent,
                    surface: Colors.black,
                    background: Colors.black,
                    onPrimary: Colors.white,
                    onSecondary: Colors.white,
                    onSurface: Colors.white,
                    onBackground: Colors.white,
                  ),
                  appBarTheme: AppBarTheme(backgroundColor: Colors.black),
                  bottomNavigationBarTheme: BottomNavigationBarThemeData(
                    backgroundColor: Colors.black,
                    selectedItemColor: Colors.purple,
                    unselectedItemColor: Colors.white70,
                  ),
                  cardColor: Colors.black,
                  dialogBackgroundColor: Colors.black,
                  dividerColor: Colors.purple[700],
                  textTheme: TextTheme(
                    bodyLarge: TextStyle(color: Colors.white),
                    bodyMedium: TextStyle(color: Colors.white),
                    titleLarge: TextStyle(color: Colors.white),
                    titleMedium: TextStyle(color: Colors.white),
                  ),
                  iconTheme: IconThemeData(color: Colors.purple),
                )
              : ThemeData(
                  primaryColor: Color(0xFF3A86FF),
                  scaffoldBackgroundColor: Color(0xFFF8F7F2), // Soft off-white background
                  colorScheme: ColorScheme.light(
                    primary: Color(0xFF3A86FF), // Primary blue
                    secondary: Color(0xFF8338EC), // Purple
                    tertiary: Color(0xFFFF006E), // Pink accent
                    surface: Colors.white,
                    background: Color(0xFFF8F7F2),
                    error: Color(0xFFFF5252),
                  ),
                  textTheme: TextTheme(
                    displayLarge: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                      letterSpacing: 0.5,
                      height: 1.5,
                    ),
                    displayMedium: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                      height: 1.5,
                    ),
                    titleLarge: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF333333),
                      height: 1.5,
                    ),
                    titleMedium: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF333333),
                      height: 1.5,
                    ),
                    bodyLarge: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF333333),
                      height: 1.5,
                    ),
                    bodyMedium: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF333333),
                      height: 1.5,
                    ),
                  ),
                  cardTheme: CardTheme(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: Colors.white,
                  ),
                  elevatedButtonTheme: ElevatedButtonThemeData(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF3A86FF),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  outlinedButtonTheme: OutlinedButtonThemeData(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Color(0xFF3A86FF),
                      side: BorderSide(color: Color(0xFF3A86FF)),
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  inputDecorationTheme: InputDecorationTheme(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF3A86FF), width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  dividerTheme: DividerThemeData(
                    color: Color(0xFFE0E0E0),
                    thickness: 1,
                    space: 32,
                  ),
                  appBarTheme: AppBarTheme(
                    backgroundColor: Color(0xFF3A86FF),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    centerTitle: false,
                    titleTextStyle: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  bottomNavigationBarTheme: BottomNavigationBarThemeData(
                    backgroundColor: Colors.white,
                    selectedItemColor: Color(0xFF3A86FF),
                    unselectedItemColor: Color(0xFF757575),
                    selectedIconTheme: IconThemeData(size: 26),
                    selectedLabelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    unselectedLabelStyle: TextStyle(fontSize: 14),
                    showSelectedLabels: true,
                    showUnselectedLabels: true,
                    elevation: 8,
                    type: BottomNavigationBarType.fixed,
                  ),
                  iconTheme: IconThemeData(
                    color: Color(0xFF3A86FF),
                    size: 24,
                  ),
                  dialogTheme: DialogTheme(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    backgroundColor: Colors.white,
                    elevation: 4,
                  ),
                ),
          home: _isInitialized
              ? (_isAuthenticated
                  ? MainScreen(
                      userData: _userData,
                      initialRecentFiles: _recentFiles,
                    )
                  : WelcomeScreen())
              : SplashScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  final UserData? userData;
  final List<Map<String, dynamic>>? initialRecentFiles;

  MainScreen({this.userData, this.initialRecentFiles});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late List<Map<String, dynamic>> _recentFiles;
  final DatabaseService _databaseService = DatabaseService();
  late String _userId; // Will be set from the current authenticated user
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    
    // Get the current user ID from Firebase Auth
    final currentUser = FirebaseAuth.instance.currentUser;
    _userId = currentUser?.uid ?? 'guest_user';
    
    // Initialize recent files from props or default
    _recentFiles = widget.initialRecentFiles ?? [];
    
    // If no files were provided, load default examples
    if (_recentFiles.isEmpty) {
      _recentFiles = [
        {'name': 'file1.pdf', 'timestamp': DateTime.now().toString()},
        {'name': 'file2.pdf', 'timestamp': DateTime.now().subtract(Duration(minutes: 5)).toString()},
      ];
    }
    
    _initScreens();
    
    // Save the initial files to database if they came from default
    if (widget.initialRecentFiles == null || widget.initialRecentFiles!.isEmpty) {
      _saveRecentFilesToDatabase();
    }
  }
  
  void _initScreens() {
    _screens = [
      ContextAwareHomeScreen(
        recentFiles: _recentFiles,
        onFilesDeleted: _onFilesDeleted,
        onFileUploaded: _onFileUploaded,
      ),
      FilesScreen(
        recentFiles: _recentFiles,
        onFilesDeleted: _onFilesDeleted,
        onToggleFavorite: _onToggleFavorite,
        onFileOpen: _onFileOpen,
      ),
      SettingsScreen(userData: widget.userData),
    ];
  }
  
  Future<void> _saveRecentFilesToDatabase() async {
    try {
      // Save recent files to database
      for (var file in _recentFiles) {
        await _databaseService.saveFileMetadata(_userId, file);
      }
    } catch (e) {
      print('Error saving recent files to database: $e');
    }
  }

  void _onFileUploaded(Map<String, dynamic> file) {
    setState(() {
      _recentFiles.insert(0, file);
      if (_recentFiles.length > 5) _recentFiles.removeLast();
      _selectedIndex = 0;
    });
    
    // Save the new file to database
    _databaseService.saveFileMetadata(_userId, file).then((_) {
      print('File metadata saved to database');
    }).catchError((error) {
      print('Error saving file metadata: $error');
    });
  }

  void _onFilesDeleted(List<int> indicesToDelete) {
    // Get the files to be deleted for database update
    List<Map<String, dynamic>> filesToDelete = [];
    for (int index in indicesToDelete) {
      if (index >= 0 && index < _recentFiles.length) {
        filesToDelete.add(_recentFiles[index]);
      }
    }
    
    setState(() {
      // Sort indices in descending order to avoid index shifting when removing
      indicesToDelete.sort((a, b) => b.compareTo(a));
      for (int index in indicesToDelete) {
        if (index >= 0 && index < _recentFiles.length) {
          _recentFiles.removeAt(index);
        }
      }
    });
    
    // Update database by removing deleted files
    for (var file in filesToDelete) {
      _databaseService.deleteFileMetadata(_userId, file).then((_) {
        print('File metadata deleted from database');
      }).catchError((error) {
        print('Error deleting file metadata: $error');
      });
    }
  }
  
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  
  // Toggle favorite status for a file
  void _onToggleFavorite(Map<String, dynamic> file, int index) {
    setState(() {
      // Toggle the favorite status
      file['isFavorite'] = !(file['isFavorite'] == true);
      
      // Update the file in the list
      _recentFiles[index] = file;
    });
    
    // Update the file in the database
    _databaseService.updateFileMetadata(_userId, file).then((_) {
      print('File favorite status updated in database');
    }).catchError((error) {
      print('Error updating file favorite status: $error');
    });
  }
  
  // Open a file
  void _onFileOpen(Map<String, dynamic> file) {
    // Handle file opening logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening: ${file["name"]}'))
    );
    
    // You would typically navigate to a file viewer here
    // For example:
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => FileViewerScreen(file: file),
    //   ),
    // );
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      // Title removed as requested
      elevation: 2,
    ),
    body: _screens[_selectedIndex],
    bottomNavigationBar: BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.folder),
          activeIcon: Icon(Icons.folder),
          label: 'Files',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          activeIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
    ),
  );
}
}