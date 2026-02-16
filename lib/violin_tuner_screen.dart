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
    return Scaffold(
      backgroundColor: const Color(0xFF87CEEB), // Sky blue
      appBar: AppBar(
        title: const Text(
          '🎻 Violin Tuner 🎻',
          style: TextStyle(fontSize: 26),
        ),
        backgroundColor: const Color(0xFF4B0082), // Indigo
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                if (hasError)
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.red,
                    child: const Text(
                      'Audio system failed - Restart app',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  currentString.isNotEmpty
                      ? 'String: $currentString'
                      : 'Waiting...',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4B0082),
                    fontFamily: 'Georgia',
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  currentPitch > 0
                      ? '${currentPitch.toStringAsFixed(1)} Hz'
                      : '-- Hz',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Color(0xFF4B0082),
                  ),
                ),
                const SizedBox(height: 40),
                _buildHatIndicator(),
                const SizedBox(height: 40),
                SizedBox(
                  height: 36,
                  child: Opacity(
                    opacity: isInTune ? 1.0 : 0.0,
                    child: const Text(
                      'In tune! 🎉',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF32CD32),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                if (!hasError && currentAmplitude < 0.005)
                  const Column(
                    children: [
                      CircularProgressIndicator(
                        color: Color(0xFF4B0082),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Ready to detect violin...',
                        style: TextStyle(color: Color(0xFF4B0082)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildHatIndicator() {
    double normalized = (detuneAmount + 50) / 100;
    double verticalDrop = isInTune ? 25 : 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        final double slothHeight = maxWidth * 0.6;
        final double hatSize = maxWidth * 0.2;
        final double hatX = 20 + normalized * (maxWidth - 40 - hatSize);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: maxWidth,
              height: slothHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      "assets/sloth_tuner_picture.webp",
                      width: maxWidth,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(Icons.pets, size: 100, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),

                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    top: verticalDrop - 30,
                    left: hatX,
                    child: Image.asset(
                      "assets/Hat.webp",
                      width: hatSize,
                      height: hatSize,
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
            ),
          ],
        );
      },
    );
  }
}