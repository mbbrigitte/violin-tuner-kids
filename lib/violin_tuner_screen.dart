import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';

class ViolinTunerScreen extends StatefulWidget {
  const ViolinTunerScreen({super.key});

  @override
  State<ViolinTunerScreen> createState() => _ViolinTunerScreenState();
}

class _ViolinTunerScreenState extends State<ViolinTunerScreen> {
  static const platform = MethodChannel('com.violin_tuner_kids.tuner/audio');

  static const Map<String, double> violinStrings = {
    'G': 196.00,
    'D': 293.66,
    'A': 440.00,
    'E': 659.26,
  };

  double currentPitch = 0.0;
  double currentAmplitude = 0.0;
  String currentString = '';
  double detuneAmount = 0.0;
  bool isInTune = false;
  bool isTooHigh = false;
  bool isTooLow = false;
  bool hasError = false;

  List<double> pitchBuffer = [];
  Timer? pitchTimer;

  @override
  void initState() {
    super.initState();
    _startRealTuning();
  }

  Future<void> _startRealTuning() async {
    setState(() {
      currentPitch = 0.0;
      currentAmplitude = 0.0;
      currentString = '';
      hasError = false;
    });

    try {
      await platform.invokeMethod('startListening');
      print('✅ Native audio started successfully');

      pitchTimer = Timer.periodic(const Duration(milliseconds: 50), (_) async {
        if (!mounted) return;

        try {
          final result = await platform.invokeMethod('getPitch');
          if (result != null) {
            double pitch = result['pitch'] ?? 0.0;
            double amplitude = result['amplitude'] ?? 0.0;
            setState(() {
              currentAmplitude = amplitude;
              if (amplitude > 0.005) {
                currentPitch = _smoothPitch(pitch);
                _updateTuningState();
              }
            });
          }
        } catch (e) {
          print('Error getting pitch: $e');
          _showPermanentError();
        }
      });
    } catch (e) {
      print('❌ Error starting native audio: $e');
      _showPermanentError();
    }
  }

  void _showPermanentError() {
    if (!mounted) return;
    setState(() {
      hasError = true;
    });
  }

  double _smoothPitch(double pitch) {
    pitchBuffer.add(pitch);
    if (pitchBuffer.length > 5) pitchBuffer.removeAt(0);
    return pitchBuffer.reduce((a, b) => a + b) / pitchBuffer.length;
  }

  void _updateTuningState() {
    if (currentPitch < 150 || currentPitch > 800) {
      currentString = '';
      return;
    }

    double minDistance = double.infinity;
    String nearestString = '';
    double targetFreq = 0.0;

    violinStrings.forEach((stringName, frequency) {
      double distance = (currentPitch - frequency).abs();
      if (distance < minDistance) {
        minDistance = distance;
        nearestString = stringName;
        targetFreq = frequency;
      }
    });

    if (nearestString != currentString) {
      double halfDistance = _getHalfDistanceToNextString(nearestString);
      if (minDistance > halfDistance && pitchBuffer.length < 3) return;
    }

    currentString = nearestString;

    detuneAmount = 1200 * log(currentPitch / targetFreq) / log(2);
    detuneAmount = detuneAmount.clamp(-50.0, 50.0);

    isInTune = detuneAmount.abs() < 5;
    isTooHigh = detuneAmount > 5;
    isTooLow = detuneAmount < -5;
  }

  double _getHalfDistanceToNextString(String stringName) {
    final order = ['G', 'D', 'A', 'E'];
    int index = order.indexOf(stringName);
    if (index < 0 || index >= order.length - 1) return 50;

    double current = violinStrings[stringName]!;
    double next = violinStrings[order[index + 1]]!;
    return (next - current) / 2;
  }

  Future<void> _stopAudio() async {
    pitchTimer?.cancel();
    pitchTimer = null;
    try {
      await platform.invokeMethod('stopListening');
    } catch (e) {
      print('Error stopping audio: $e');
    }
  }

  @override
  void dispose() {
    _stopAudio();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fullscreen responsive sloth image in background
          SizedBox(
            width: screenWidth,
            height: screenHeight,
            child: Image.asset(
              "assets/sloth_tuner_picture.webp",
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: const Color(0xFF87CEEB),
                );
              },
            ),
          ),
          
          // Semi-transparent overlay
          Container(
            color: Colors.black.withOpacity(0.2),
          ),
          
          // Content overlay
          SafeArea(
            child: Column(
              children: [
                // "Play one string" at top
                Padding(
                  padding: EdgeInsets.all(screenHeight * 0.025),
                  child: Text(
                    'Play one string',
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
                
                SizedBox(height: screenHeight * 0.02),
                
                // Error message if any
                if (hasError)
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Audio system failed - Restart app',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                
                const Spacer(),
                
                // Hat indicator (sloth with moving hat)
                _buildHatIndicator(),
                
                const Spacer(),
                
                // String detection and tuning info
                if (currentString.isNotEmpty)
                  Container(
                    margin: EdgeInsets.all(screenWidth * 0.05),
                    padding: EdgeInsets.all(screenWidth * 0.05),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // "You are tuning your X string"
                        Text(
                          'You are tuning your $currentString string',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: screenWidth * 0.055,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF4B0082),
                          ),
                        ),
                        
                        SizedBox(height: screenHeight * 0.01),
                        
                        // Hz display
                        Text(
                          currentPitch > 0
                              ? '${currentPitch.toStringAsFixed(1)} Hz'
                              : '-- Hz',
                          style: TextStyle(
                            fontSize: screenWidth * 0.045,
                            color: const Color(0xFF4B0082),
                          ),
                        ),
                        
                        SizedBox(height: screenHeight * 0.02),
                        
                        // In tune message
                        SizedBox(
                          height: 36,
                          child: Opacity(
                            opacity: isInTune ? 1.0 : 0.0,
                            child: Text(
                              'In tune! 🎉',
                              style: TextStyle(
                                fontSize: screenWidth * 0.07,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF32CD32),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  // Discrete "Waiting for sound..." without white background
                  Padding(
                    padding: EdgeInsets.all(screenWidth * 0.05),
                    child: Text(
                      'Waiting for sound...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: screenWidth * 0.045,
                        color: Colors.white.withOpacity(0.6),
                        shadows: const [
                          Shadow(
                            blurRadius: 5.0,
                            color: Colors.black,
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHatIndicator() {
    double normalized = (detuneAmount + 50) / 100;
    double verticalDrop = isInTune ? 40 : 0; // Increased drop for bigger hat

    return LayoutBuilder(
      builder: (context, constraints) {
        // Get screen width for responsive sizing
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        
        // Make hat responsive to screen size - 200% bigger than before
        final double hatSize = screenWidth * 0.4; // Was 0.2, now doubled
        final double trackWidth = screenWidth * 0.8; // Area for hat to move
        final double hatX = (screenWidth - trackWidth) / 2 + normalized * (trackWidth - hatSize);

        return SizedBox(
          width: screenWidth,
          height: screenHeight * 0.25, // Responsive height
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                top: verticalDrop - 200, // Position higher (was -30, now +10)
                left: hatX,
                child: Image.asset(
                  "assets/Hat.webp",
                  width: hatSize,
                  height: hatSize,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.star,
                      size: hatSize,
                      color: Colors.yellow,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}