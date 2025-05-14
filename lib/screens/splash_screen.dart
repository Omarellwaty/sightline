import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark 
          ? Colors.black 
          : Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo or icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.purple 
                    : Colors.blue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.remove_red_eye,
                size: 60,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 24),
            // App name
            Text(
              'Sight Line',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : Colors.blue,
              ),
            ),
            SizedBox(height: 16),
            // Loading indicator
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).brightness == Brightness.dark 
                    ? Colors.purple 
                    : Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
