import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'violin_tuner_screen.dart';

void main() {
  runApp(const ViolinTunerApp());
}

class ViolinTunerApp extends StatelessWidget {
  const ViolinTunerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Violin Tuner for Kids',
      theme: ThemeData(
        fontFamily: 'Georgia',
        primarySwatch: Colors.blue,
      ),
      home: const WelcomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    _checkPermissionAndNavigate();
  }

  Future<void> _checkPermissionAndNavigate() async {
    // Check if microphone permission is already granted
    PermissionStatus status = await Permission.microphone.status;
    
    if (status.isGranted && mounted) {
      // Permission already granted, go directly to tuner
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ViolinTunerScreen()),
      );
    }
    // If not granted, stay on welcome screen
  }

  Future<void> _requestMicrophoneAndNavigate(BuildContext context) async {
    PermissionStatus status = await Permission.microphone.status;
    
    if (status.isGranted) {
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ViolinTunerScreen()),
        );
      }
      return;
    }
    
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.lightBlue[300],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white, width: 3),
          ),
          content: const Text(
            'The tuner needs your microphone to hear your violin!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _handleMicrophonePermission(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'OK',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _handleMicrophonePermission(BuildContext context) async {
    PermissionStatus status = await Permission.microphone.request();
    
    if (!context.mounted) return;
    
    if (status.isGranted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ViolinTunerScreen()),
      );
    } else if (status.isDenied) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.orange[400],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white, width: 3),
          ),
          title: const Text(
            'Microphone Needed',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'The violin tuner needs microphone access to work. Please allow it!',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _handleMicrophonePermission(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    } else if (status.isPermanentlyDenied) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.red[400],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.white, width: 3),
          ),
          title: const Text(
            'Settings Required',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Please enable microphone in your device settings.',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red[400],
              ),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      body: GestureDetector(
        onTap: () => _requestMicrophoneAndNavigate(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Fullscreen responsive sloth image
            SizedBox(
              width: screenWidth,
              height: screenHeight,
              child: Image.asset(
                'assets/sloth_tuner_picture.webp',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFF87CEEB),
                    child: Center(
                      child: Icon(
                        Icons.music_note,
                        size: screenWidth * 0.3,
                        color: const Color(0xFF4B0082),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Semi-transparent overlay with text
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.1,
                    vertical: screenHeight * 0.05,
                  ),
                  child: Text(
                    'To start tuning, allow microphone access',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: screenWidth * 0.07,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: const [
                        Shadow(
                          blurRadius: 10.0,
                          color: Colors.black,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}