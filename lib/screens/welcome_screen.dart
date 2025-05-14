import 'package:flutter/material.dart';
import 'registration_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Color(0xFF3A86FF),
        ),
        child: Column(
          children: [
            // Top section with logo and app name
            Expanded(
              flex: 3, // Increased flex to give more space to the blue section
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(height: 10), // Reduced top spacing
                    // Logo positioned in the center of blue area
                    Center(
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              Colors.white,
                              Colors.white.withOpacity(0.9),
                              Colors.white.withOpacity(0.7),
                              Colors.white.withOpacity(0.1),
                            ],
                            stops: [0.4, 0.6, 0.8, 1.0],
                            radius: 0.8,
                          ),
                          shape: BoxShape.circle,
                        ),
                        padding: EdgeInsets.all(15),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    // Custom curved divider
                    SizedBox(
                      height: 40,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: CurvedDividerPainter(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom section with welcome text and buttons
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                width: double.infinity,
                padding: EdgeInsets.only(left: 40, right: 40, top: 30, bottom: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Logo is now in the wave, not here
                    Text(
                      'Welcome!',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 20),
                    // Get Started button with arrow
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => RegistrationScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF3A86FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 3,
                          shadowColor: Color(0xFF3A86FF).withOpacity(0.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Get Started',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                            ),
                            SizedBox(width: 12),
                            Icon(Icons.arrow_forward, size: 24),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom clipper for the curved edge with waves on both sides
class CurveClipper extends CustomClipper<Path> {
  final double waveOffset;
  
  CurveClipper({this.waveOffset = 0});
  
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 40 - waveOffset); // Start from left side, but lower
    
    // Left side wave
    final leftControlPoint1 = Offset(size.width * 0.25, size.height - 30 - waveOffset);
    final leftEndPoint1 = Offset(size.width * 0.5, size.height - 20 - waveOffset);
    path.quadraticBezierTo(
      leftControlPoint1.dx, leftControlPoint1.dy, 
      leftEndPoint1.dx, leftEndPoint1.dy
    );
    
    // Right side wave
    final rightControlPoint = Offset(size.width * 0.75, size.height - 10 - waveOffset);
    final rightEndPoint = Offset(size.width, size.height - 40 - waveOffset);
    path.quadraticBezierTo(
      rightControlPoint.dx, rightControlPoint.dy, 
      rightEndPoint.dx, rightEndPoint.dy
    );
    
    // Complete the path
    path.lineTo(size.width, 0);
    path.lineTo(0, 0);
    
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// Custom painter for the curved divider
class CurvedDividerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..strokeWidth = 1;
    
    final path = Path();
    
    // Start from the left edge, at the bottom
    path.moveTo(0, size.height);
    
    // Draw a line up to the top-left corner
    path.lineTo(0, 0);
    
    // Create a smooth curve across the width
    path.quadraticBezierTo(
      size.width / 2, // Control point x (middle of width)
      size.height * 0.8, // Control point y (80% down from top)
      size.width, // End point x (right edge)
      0, // End point y (top edge)
    );
    
    // Draw a line down to the bottom-right corner
    path.lineTo(size.width, size.height);
    
    // Close the path to form a complete shape
    path.close();
    
    // Draw the path
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
