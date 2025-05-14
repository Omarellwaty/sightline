import 'package:flutter/material.dart';

class SmartScanTab extends StatelessWidget {
  final VoidCallback onStartScan;

  const SmartScanTab({super.key, required this.onStartScan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      color: isDark ? Colors.black : Colors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Icon(
              Icons.document_scanner,
              size: 100,
              color: isDark ? Colors.purple : Colors.blue,
            ),
            
            const SizedBox(height: 24),
            
            // Title
            Text(
              'Smart Scan',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'Scan documents and extract text with advanced handwriting recognition',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : Colors.grey[700],
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Start Scan Button
            ElevatedButton.icon(
              onPressed: onStartScan,
              icon: const Icon(Icons.document_scanner),
              label: const Text('Start Scan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.purple : Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
