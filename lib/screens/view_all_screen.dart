import 'package:flutter/material.dart';

class ViewAllScreen extends StatelessWidget {
  final List<Map<String, dynamic>> recentFiles; // Updated to Map

  ViewAllScreen({required this.recentFiles});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Recent Files'),
        backgroundColor: Color(0xFF1E90FF),
      ),
      body: Container(
        color: Colors.white,
        child: ListView.builder(
          padding: EdgeInsets.all(16.0),
          itemCount: recentFiles.length,
          itemBuilder: (context, index) {
            final file = recentFiles[index];
            return Card(
              elevation: 2,
              margin: EdgeInsets.symmetric(vertical: 8.0),
              child: ListTile(
                leading: Icon(
                  Icons.picture_as_pdf,
                  color: Color(0xFF1E90FF),
                  size: 40,
                ),
                title: Text(
                  file['name'].length > 20
                      ? '${file['name'].substring(0, 20)}...'
                      : file['name'],
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
                subtitle: Text(
                  file['timestamp'], // Use the timestamp from the map
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Tapped: ${file['name']}')),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}