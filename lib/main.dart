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

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _requestMicrophoneAndNavigate(BuildContext context) async {
    PermissionStatus status = await Permission.microphone.status;
    
    if (status.isGranted) {
      if (context.mounted) {
        Navigator.push(
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
      Navigator.push(
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
    final size = MediaQuery.of(context).size;
    final double w = size.width;
    final double h = size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF87CEEB), // Sky blue
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(w * 0.08),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Title
                Text(
                  '🎻 Violin Tuner 🎻',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: w * 0.09,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF4B0082),
                  ),
                ),
                
                SizedBox(height: h * 0.05),

                // Image
                Container(
                  constraints: BoxConstraints.loose(Size(w * 0.7, h * 0.4)),
                  child: Image.asset(
                    'assets/sloth_tuner_picture.webp',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.music_note,
                        size: w * 0.3,
                        color: const Color(0xFF4B0082),
                      );
                    },
                  ),
                ),

                SizedBox(height: h * 0.05),

                // Start button
                SizedBox(
                  width: w * 0.7,
                  child: ElevatedButton(
                    onPressed: () => _requestMicrophoneAndNavigate(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF32CD32), // Lime green
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: h * 0.025),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                      elevation: 8,
                    ),
                    child: Text(
                      'Start Tuning!',
                      style: TextStyle(
                        fontSize: w * 0.07,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}