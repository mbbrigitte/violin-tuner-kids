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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF6DD5B0),
              const Color(0xFF4CAF93),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top section: Title and tuning info
              Padding(
                padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
                child: Column(
                  children: [
                    Text(
                      'Play one string',
                      style: TextStyle(
                        fontSize: screenWidth * 0.08,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: const [
                          Shadow(
                            blurRadius: 10.0,
                            color: Colors.black26,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                    if (currentString.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: screenHeight * 0.008),
                        child: Text(
                          'Tuning $currentString, ${currentPitch.toStringAsFixed(1)} Hz',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: screenWidth * 0.045,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.9),
                            shadows: const [
                              Shadow(
                                blurRadius: 5.0,
                                color: Colors.black26,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Error message
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

              // Middle section: Sloths and hat (responsive)
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        // Sloth image
                        Positioned(
                          top: constraints.maxHeight * 0.4, // 20% from top
                          left: 0,
                          right: 0,
                          child: Image.asset(
                            "assets/sloth_tuner_picture.webp",
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(Icons.pets, size: 100, color: Colors.white),
                              );
                            },
                          ),
                        ),

                        // Hat
                        _buildHatIndicator(constraints),
                      ],
                    );
                  },
                ),
              ),

              // Bottom section: In tune message
              SizedBox(
                height: screenHeight * 0.12,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: isInTune ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      'In tune! 🎉',
                      style: TextStyle(
                        fontSize: screenWidth * 0.09,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: const [
                          Shadow(
                            blurRadius: 10.0,
                            color: Colors.black26,
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
      ),
    );
  }

  Widget _buildHatIndicator(BoxConstraints constraints) {
    double normalized = (detuneAmount + 50) / 100;
    double verticalDrop = isInTune ? 60 : 0;

    final screenWidth = constraints.maxWidth;
    final hatSize = screenWidth * 0.5;
    final trackWidth = screenWidth * 0.7;
    final hatX = (screenWidth - trackWidth) / 2 + normalized * (trackWidth - hatSize);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      top: constraints.maxHeight * 0.15 + verticalDrop, // relative to sloth
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
    );
  }
}
