import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart'; // Import for isDarkThemeNotifier
import '../services/database_service.dart';
import '../data/data_model/user_data.dart';
import '../providor/auth_service.dart';
import '../screens/sign_in_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatefulWidget {
  final UserData? userData;
  
  const SettingsScreen({Key? key, this.userData}) : super(key: key);
  
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkTheme = false;
  bool _notificationsEnabled = false;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();
  
  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // User data from Firestore
  Map<String, dynamic>? _firestoreUserData;

  @override
  void initState() {
    super.initState();
    _initializeSettings();
    _initializeNotifications();
    _fetchUserDataFromFirestore();
  }
  
  void _initializeSettings() {
    // Load the current theme setting from the global notifier
    _isDarkTheme = isDarkThemeNotifier.value;
    // Default notification setting
    _notificationsEnabled = true;
  }
  
  // Fetch user data from Firestore
  Future<void> _fetchUserDataFromFirestore() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          setState(() {
            _firestoreUserData = userDoc.data() as Map<String, dynamic>;
          });
        }
      }
    } catch (e) {
      print('Error fetching user data from Firestore: $e');
    }
  }
  


  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
    InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(initSettings);
  }

  Future<void> _showNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'channel_id',
      'Dyslexia Helper Notifications',
      channelDescription: 'Notifications for Dyslexia Helper app',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails notificationDetails =
    NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      0,
      'Dyslexia Helper',
      'This is a test notification!',
      notificationDetails,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Settings'),
        backgroundColor: isDark ? Colors.black : Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: isDark ? Colors.black : null,
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: ListView(
            children: [
              // User Profile Section at the top
              Card(
                elevation: 4,
                color: isDark ? Colors.black : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isDark ? BorderSide(color: Colors.purple.withOpacity(0.5), width: 1) : BorderSide.none,
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.person, size: 24, color: isDark ? Colors.purple : Colors.blue),
                      title: Text(
                        'User Profile',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.blueGrey[800],
                        ),
                      ),
                      trailing: Icon(Icons.arrow_forward, color: isDark ? Colors.purple : Colors.blue),
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          isScrollControlled: true,
                          builder: (context) => Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.person, size: 28, color: isDark ? Colors.purple : Colors.blue),
                                    SizedBox(width: 10),
                                    Text(
                                      'User Profile',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.blueGrey[800],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 20),
                                if (widget.userData != null || _firestoreUserData != null) ...[  
                                  _buildProfileItem(context, 'Email', _firestoreUserData?['email'] ?? widget.userData?.email ?? 'Not available', Icons.email),
                                  SizedBox(height: 15),
                                  _buildPasswordItem(context, 'Password', '••••••••', Icons.lock),
                                ] else
                                  Text(
                                    'No user profile data available',
                                    style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700]),
                                  ),
                                SizedBox(height: 20),
                                Divider(color: isDark ? Colors.grey[700] : Colors.grey[300]),
                                SizedBox(height: 10),
                                Text(
                                  'Security',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.teal : Colors.teal[700],
                                  ),
                                ),
                                SizedBox(height: 10),
                                // Change Password option
                                ListTile(
                                  leading: Icon(
                                    Icons.lock,
                                    color: isDark ? Colors.teal : Colors.teal,
                                  ),
                                  title: Text(
                                    'Change Password',
                                    style: TextStyle(color: isDark ? Colors.white : null),
                                  ),
                                  subtitle: Text(
                                    'Update your account password',
                                    style: TextStyle(color: isDark ? Colors.white70 : null),
                                  ),
                                  trailing: Icon(Icons.arrow_forward, size: 20),
                                  onTap: () {
                                    Navigator.pop(context); // Close the modal first
                                    _showChangePasswordDialog(context);
                                  },
                                ),
                                SizedBox(height: 5),
                                // Sign Out button
                                ListTile(
                                  leading: Icon(
                                    Icons.logout,
                                    color: isDark ? Colors.red : Colors.red,
                                  ),
                                  title: Text(
                                    'Sign Out',
                                    style: TextStyle(color: isDark ? Colors.white : null),
                                  ),
                                  subtitle: Text(
                                    'Log out of your account',
                                    style: TextStyle(color: isDark ? Colors.white70 : null),
                                  ),
                                  trailing: Icon(Icons.arrow_forward, size: 20),
                                  onTap: () {
                                    Navigator.pop(context); // Close the modal first
                                    // Show sign out confirmation dialog
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: isDark ? Colors.grey[900] : null,
                                        title: Text('Sign Out', style: TextStyle(color: isDark ? Colors.white : null)),
                                        content: Text(
                                          'Are you sure you want to sign out?',
                                          style: TextStyle(color: isDark ? Colors.white70 : null)
                                        ),
                                        actions: [
                                          TextButton(
                                            child: Text('Cancel'),
                                            onPressed: () => Navigator.of(context).pop(),
                                            style: TextButton.styleFrom(
                                              foregroundColor: isDark ? Colors.white : Colors.black54,
                                            ),
                                          ),
                                          TextButton(
                                            child: Text('Sign Out'),
                                            onPressed: () async {
                                              try {
                                                await AuthService().signOut();
                                                Navigator.of(context).pop(); // Close dialog
                                                
                                                // Navigate to sign in screen and clear navigation stack
                                                Navigator.of(context).pushAndRemoveUntil(
                                                  MaterialPageRoute(builder: (context) => SignInScreen()),
                                                  (route) => false,
                                                );
                                              } catch (e) {
                                                print('Error signing out: $e');
                                                Navigator.of(context).pop(); // Close dialog
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Error signing out. Please try again.')),
                                                );
                                              }
                                            },
                                            style: TextButton.styleFrom(
                                              foregroundColor: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                SizedBox(height: 15),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      icon: Icon(Icons.edit, size: 18),
                                      label: Text('Edit Profile'),
                                      onPressed: () {
                                        Navigator.pop(context); // Close the modal first
                                        _showEditProfileDialog(context);
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: isDark ? Colors.purple : Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.settings, size: 30, color: isDark ? Colors.purple : Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.blueGrey[800],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Card(
                elevation: 4,
                color: isDark ? Colors.black : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isDark ? BorderSide(color: Colors.purple.withOpacity(0.5), width: 1) : BorderSide.none,
                ),
                child: SwitchListTile(
                  title: Text(
                    'Dark Theme',
                    style: TextStyle(color: isDark ? Colors.white : null),
                  ),
                  subtitle: Text(
                    'Enable dark mode for the app',
                    style: TextStyle(color: isDark ? Colors.white70 : null),
                  ),
                  value: _isDarkTheme,
                  onChanged: (value) {
                    setState(() {
                      _isDarkTheme = value;
                      isDarkThemeNotifier.value = value; // Update global theme
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Dark Theme: ${_isDarkTheme ? 'On' : 'Off'}')),
                    );
                  },
                  secondary: Icon(
                    Icons.brightness_6,
                    color: isDark ? Colors.purple : null,
                  ),
                  activeColor: isDark ? Colors.purple : Colors.blue,
                ),
              ),
              SizedBox(height: 10),
              Card(
                elevation: 4,
                color: isDark ? Colors.black : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isDark ? BorderSide(color: Colors.purple.withOpacity(0.5), width: 1) : BorderSide.none,
                ),
                child: SwitchListTile(
                  title: Text(
                    'Notifications',
                    style: TextStyle(color: isDark ? Colors.white : null),
                  ),
                  subtitle: Text(
                    'Receive app notifications',
                    style: TextStyle(color: isDark ? Colors.white70 : null),
                  ),
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() {
                      _notificationsEnabled = value;
                      if (_notificationsEnabled) {
                        _showNotification(); // Show a test notification when enabled
                      }
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Notifications: ${_notificationsEnabled ? 'On' : 'Off'}')),
                    );
                  },
                  secondary: Icon(
                    Icons.notifications,
                    color: isDark ? Colors.purple : null,
                  ),
                  activeColor: isDark ? Colors.purple : Colors.blue,
                ),
              ),
              SizedBox(height: 20),
              // Feedback Section
              Row(
                children: [
                  Icon(Icons.feedback, size: 24, color: isDark ? Colors.orange : Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    'Feedback',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.blueGrey[800],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Card(
                elevation: 4,
                color: isDark ? Colors.black : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isDark ? BorderSide(color: Colors.purple.withOpacity(0.5), width: 1) : BorderSide.none,
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.rate_review,
                    color: isDark ? Colors.orange : Colors.orange,
                  ),
                  title: Text(
                    'Send Feedback',
                    style: TextStyle(color: isDark ? Colors.white : null),
                  ),
                  subtitle: Text(
                    'Help us improve the app',
                    style: TextStyle(color: isDark ? Colors.white70 : null),
                  ),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    _showFeedbackDialog(context);
                  },
                ),
              ),
              SizedBox(height: 20),
              // About Section
              Row(
                children: [
                  Icon(Icons.info_outline, size: 24, color: isDark ? Colors.purple : Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'About',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.blueGrey[800],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Card(
                elevation: 4,
                color: isDark ? Colors.black : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isDark ? BorderSide(color: Colors.purple.withOpacity(0.5), width: 1) : BorderSide.none,
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.info,
                    color: isDark ? Colors.purple : Colors.blue,
                  ),
                  title: Text(
                    'About Dyslexia Helper',
                    style: TextStyle(color: isDark ? Colors.white : null),
                  ),
                  subtitle: Text(
                    'Version 1.0.0\nA tool to assist with dyslexia support.',
                    style: TextStyle(color: isDark ? Colors.white70 : null),
                  ),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'Dyslexia Helper',
                      applicationVersion: '1.0.0',
                      applicationLegalese: '© 2025 xAI',
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Helper method to build profile item
  Widget _buildProfileItem(BuildContext context, String label, String value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      children: [
        Icon(icon, size: 20, color: isDark ? Colors.purple : Colors.blue),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // Helper method to build password item with stars and info button
  Widget _buildPasswordItem(BuildContext context, String label, String maskedValue, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      children: [
        Icon(icon, size: 20, color: isDark ? Colors.purple : Colors.blue),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              Row(
                children: [
                  Text(
                    maskedValue,  // Display stars instead of actual password
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  SizedBox(width: 8),
                  Tooltip(
                    message: 'Your password is securely stored as a hash in our database',
                    child: Icon(
                      Icons.info_outline,
                      size: 16,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // Show dialog to change password
  void _showChangePasswordDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final TextEditingController _currentPasswordController = TextEditingController();
    final TextEditingController _newPasswordController = TextEditingController();
    final TextEditingController _confirmPasswordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : null,
        title: Text('Change Password', style: TextStyle(color: isDark ? Colors.white : null)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _currentPasswordController,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: isDark ? Colors.white70 : null),
                ),
                obscureText: true,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _newPasswordController,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: isDark ? Colors.white70 : null),
                  helperText: 'At least 6 characters',
                  helperStyle: TextStyle(color: isDark ? Colors.white60 : null),
                ),
                obscureText: true,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: isDark ? Colors.white70 : null),
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Validate passwords
              if (_currentPasswordController.text.isEmpty ||
                  _newPasswordController.text.isEmpty ||
                  _confirmPasswordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('All fields are required')),
                );
                return;
              }
              
              if (_newPasswordController.text != _confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('New passwords don\'t match')),
                );
                return;
              }
              
              if (_newPasswordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Password must be at least 6 characters')),
                );
                return;
              }
              
              // Here you would typically update the password in your authentication system
              // For this example, we'll just show a success message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Password changed successfully')),
              );
              
              // Clear controllers and close dialog
              _currentPasswordController.clear();
              _newPasswordController.clear();
              _confirmPasswordController.clear();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.purple : Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text('Change Password'),
          ),
        ],
      ),
    );
  }
  
  // Method removed to fix duplicate definition error
  
  // Show support contact dialog
  void _showSupportContactDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : null,
        title: Text('Contact Support', style: TextStyle(color: isDark ? Colors.white : null)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('For assistance, please contact us at:', style: TextStyle(color: isDark ? Colors.white70 : null)),
            SizedBox(height: 10),
            _buildContactRow(Icons.email, 'Email', 'support@dyslexiahelper.com'),
            SizedBox(height: 5),
            _buildContactRow(Icons.phone, 'Phone', '+1 (800) 123-4567'),
            SizedBox(height: 5),
            _buildContactRow(Icons.access_time, 'Hours', 'Mon-Fri, 9AM-5PM EST'),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Close'),
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.purple : Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper method to build contact row
  Widget _buildContactRow(IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      children: [
        Icon(icon, color: isDark ? Colors.purple : Colors.blue),
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  // Show feedback dialog
  void _showFeedbackDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final TextEditingController _commentsController = TextEditingController();
    final DatabaseService _databaseService = DatabaseService();
    String _selectedFeedbackType = 'General';
    int _selectedRating = 5;
    bool _isSubmitting = false;
    
    // Feedback types
    final List<String> feedbackTypes = [
      'General',
      'Bug Report',
      'Feature Request',
      'Performance Issue',
      'Accessibility',
      'Other'
    ];
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : null,
          title: Text('Send Feedback', style: TextStyle(color: isDark ? Colors.white : null)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Feedback Type',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : null,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedFeedbackType,
                    isExpanded: true,
                    dropdownColor: isDark ? Colors.grey[800] : null,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black),
                    underline: SizedBox(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedFeedbackType = newValue;
                        });
                      }
                    },
                    items: feedbackTypes.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Rating',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : null,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < _selectedRating ? Icons.star : Icons.star_border,
                        color: index < _selectedRating ? Colors.amber : (isDark ? Colors.grey[600] : Colors.grey[400]),
                        size: 32,
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedRating = index + 1;
                        });
                      },
                    );
                  }),
                ),
                SizedBox(height: 16),
                Text(
                  'Comments',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : null,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _commentsController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Tell us what you think...',
                    hintStyle: TextStyle(color: isDark ? Colors.grey[500] : null),
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[400]!),
                    ),
                  ),
                  style: TextStyle(color: isDark ? Colors.white : null),
                ),
                if (_isSubmitting)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isSubmitting ? null : () async {
                // Validate input
                if (_commentsController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter your comments')),
                  );
                  return;
                }
                
                setState(() {
                  _isSubmitting = true;
                });
                
                // Submit feedback to Firebase
                bool success = await _databaseService.submitFeedback(
                  userId: FirebaseAuth.instance.currentUser?.uid ?? 'guest_user',
                  feedbackType: _selectedFeedbackType,
                  rating: _selectedRating,
                  comments: _commentsController.text.trim(),
                );
                
                setState(() {
                  _isSubmitting = false;
                });
                
                // Close dialog
                Navigator.pop(dialogContext);
                
                // Show success/failure message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(success 
                    ? 'Thank you for your feedback!' 
                    : 'Failed to submit feedback. Please try again.')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.orange : Colors.orange,
                foregroundColor: Colors.white,
                disabledBackgroundColor: isDark ? Colors.orange.withOpacity(0.5) : Colors.orange.withOpacity(0.5),
              ),
              child: Text('Submit Feedback'),
            ),
          ],
        ),
      ),
    );
  }
  
  // Show dialog to edit profile
  void _showEditProfileDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final TextEditingController _nameController = TextEditingController();
    final TextEditingController _emailController = TextEditingController();
    
    // Pre-fill with existing data if available
    if (widget.userData != null) {
      _nameController.text = 'Standard User'; // Default value since name is not in UserData
      _emailController.text = widget.userData!.email;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : null,
        title: Text('Edit Profile', style: TextStyle(color: isDark ? Colors.white : null)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: isDark ? Colors.white70 : null),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: isDark ? Colors.white70 : null),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Here you would typically update the user profile in your database
              // For this example, we'll just show a success message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Profile updated successfully')),
              );
              
              // Update user data in a real app
              // DatabaseService().saveUserProfile(
              //   userId: 'test_user_123',
              //   userData: {
              //     'name': _nameController.text,
              //     'email': _emailController.text,
              //   },
              // );
              
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.purple : Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}