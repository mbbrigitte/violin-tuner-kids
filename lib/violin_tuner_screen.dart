import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'dart:math';

class ViolinTunerScreen extends StatefulWidget {
  const ViolinTunerScreen({super.key});

  @override
  State<ViolinTunerScreen> createState() => _ViolinTunerScreenState();
}

class _ViolinTunerScreenState extends State<ViolinTunerScreen>
    with TickerProviderStateMixin {
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
  late AnimationController needleController;

  // Reference tone playback
  String? playingReferenceString;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    needleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
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
      print('Error starting native audio: $e');
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

    needleController.animateTo(
      (detuneAmount + 50) / 100,
      duration: const Duration(milliseconds: 100),
    );
  }

  double _getHalfDistanceToNextString(String stringName) {
    final order = ['G', 'D', 'A', 'E'];
    int index = order.indexOf(stringName);
    if (index < 0 || index >= order.length - 1) return 50;

    double current = violinStrings[stringName]!;
    double next = violinStrings[order[index + 1]]!;
    return (next - current) / 2;
  }

  Future<void> _playReferenceString(String stringName) async {
    // Don't allow tapping while already playing
    if (playingReferenceString != null) return;
    setState(() => playingReferenceString = stringName);
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setAsset('assets/violin_$stringName.mp3');
      await _audioPlayer.play();
      // Wait for playback to finish (or up to 5 seconds)
      await _audioPlayer.playerStateStream
          .firstWhere((s) => s.processingState == ProcessingState.completed)
          .timeout(const Duration(seconds: 5), onTimeout: () {
        _audioPlayer.stop();
        return _audioPlayer.playerState;
      });
    } catch (e) {
      print('Error playing reference tone: $e');
    } finally {
      if (mounted) setState(() => playingReferenceString = null);
    }
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
    needleController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6DD5B0),
              Color(0xFF4CAF93),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top label: String name ──────────────────────────────────
              Padding(
                padding: EdgeInsets.only(
                    top: screenHeight * 0.02, bottom: screenHeight * 0.005),
                child: Text(
                  currentString.isNotEmpty
                      ? 'String: $currentString'
                      : 'Play one string',
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

              // ── Error banner ────────────────────────────────────────────
              if (hasError)
                Container(
                  margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Audio system failed – Restart app',
                    style: TextStyle(color: Colors.white),
                  ),
                ),

              // ── Needle gauge ────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.only(
                    left: screenWidth * 0.1,
                    right: screenWidth * 0.1,
                    top: screenHeight * 0.09,    // push gauge much lower
                    bottom: screenHeight * 0.01),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double gaugeSize = constraints.maxWidth;
                    return SizedBox(
                      width: gaugeSize,
                      height: gaugeSize * 0.5,
                      child: _buildNeedleGauge(gaugeSize),
                    );
                  },
                ),
              ),

              // ── Sloth + hat ─────────────────────────────────────────────
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Sloth image – edge-to-edge, anchored to bottom
                        Positioned(
                          top: constraints.maxHeight * 0.05, // show full sloth incl head
                          left: -screenWidth * 0.05,        // bleed off sides
                          right: -screenWidth * 0.05,
                          bottom: 0,
                          child: Image.asset(
                            "assets/sloth_tuner_picture.webp",
                            fit: BoxFit.cover,
                            alignment: Alignment.bottomCenter,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(Icons.pets,
                                    size: 100, color: Colors.white),
                              );
                            },
                          ),
                        ),

                        // Hat – positioned above sloth, moves across full width
                        _buildHatIndicator(constraints),
                      ],
                    );
                  },
                ),
              ),

              // ── "In tune!" message ──────────────────────────────────────
              SizedBox(
                height: screenHeight * 0.08,
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

              // ── Reference tone buttons ──────────────────────────────────
              Padding(
                padding: EdgeInsets.only(
                    left: screenWidth * 0.06,
                    right: screenWidth * 0.06,
                    bottom: screenHeight * 0.025),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['G', 'D', 'A', 'E'].map((s) {
                    final bool isPlaying = playingReferenceString == s;
                    final double btnSize = screenWidth * 0.11;
                    return GestureDetector(
                      onTap: () => _playReferenceString(s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: btnSize,
                        height: btnSize,
                        decoration: BoxDecoration(
                          color: isPlaying
                              ? Colors.white
                              : Colors.white.withOpacity(0.25),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: isPlaying ? 2.5 : 1.5,
                          ),
                          boxShadow: isPlaying
                              ? [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.5),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  )
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Text(
                            s,
                            style: TextStyle(
                              fontSize: screenWidth * 0.045,
                              fontWeight: FontWeight.bold,
                              color: isPlaying
                                  ? const Color(0xFF4CAF93)
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Needle gauge (from violin_tuner.dart) ──────────────────────────────────
  Widget _buildNeedleGauge(double size) {
    final double centerPinSize = size * 0.07;
    final double needleThickness = size * 0.018;

    return ClipPath(
      clipper: HalfCircleClipper(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withOpacity(0.5), width: size * 0.018),
            ),
            child: CustomPaint(
              painter: GaugePainter(),
            ),
          ),

          // Center reference line (green = in-tune target)
          Container(
            width: needleThickness,
            height: size * 0.45,
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 117, 184, 9),
              borderRadius: BorderRadius.circular(1),
            ),
          ),

          // Rotating needle
          AnimatedBuilder(
            animation: needleController,
            builder: (context, child) {
              return Transform.rotate(
                angle: (needleController.value - 0.5) * pi,
                child: Container(
                  width: needleThickness * 1.93,
                  height: size * 0.45,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            },
          ),

          // Center pin
          Container(
            width: centerPinSize,
            height: centerPinSize,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white70, width: centerPinSize * 0.2),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hat indicator with full-width movement ────────────────────────────────
  Widget _buildHatIndicator(BoxConstraints constraints) {
    // normalized goes 0.0 (far left) → 1.0 (far right) based on -50..+50 cents
    double normalized = (detuneAmount + 50) / 100;
    double verticalDrop = isInTune ? 50 : 0;

    final double screenWidth = constraints.maxWidth;
    // Hat takes 30% of screen width; it can travel from x=0 to x=(width - hatSize)
    final double hatSize = screenWidth * 0.42;   // bigger hat
    final double travelWidth = screenWidth - hatSize;
    final double hatX = normalized * travelWidth;

    // Hat floats above the sloth's head
    final double hatTop = constraints.maxHeight * 0.0 + verticalDrop;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      top: hatTop,
      left: hatX,
      child: Image.asset(
        "assets/Hat.webp",
        width: hatSize,
        height: hatSize,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.star, size: hatSize, color: Colors.yellow);
        },
      ),
    );
  }
}

// ── Supporting painters / clippers ───────────────────────────────────────────

class GaugePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.012;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - (size.width * 0.05);

    // Green arc in the centre (in-tune zone)
    paint.color = Colors.greenAccent.withOpacity(0.8);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi + pi / 3,
      pi / 3,
      false,
      paint,
    );

    // Top tick mark
    final linePaint = Paint()
      ..color = Colors.white70
      ..strokeWidth = size.width * 0.01;
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy - radius + (size.width * 0.05)),
      linePaint,
    );

    // LOW / HIGH labels
    final double fontSize = size.width * 0.06;
    final textStyle = TextStyle(fontSize: fontSize, color: Colors.white70);

    TextPainter(
      text: TextSpan(text: 'LOW', style: textStyle),
      textDirection: TextDirection.ltr,
    )
      ..layout()
      ..paint(canvas,
          Offset(center.dx - (size.width * 0.42), center.dy - (size.height * 0.32)));

    TextPainter(
      text: TextSpan(text: 'HIGH', style: textStyle),
      textDirection: TextDirection.ltr,
    )
      ..layout()
      ..paint(canvas,
          Offset(center.dx + (size.width * 0.28), center.dy - (size.height * 0.32)));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class HalfCircleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.addRect(Rect.fromLTWH(0, 0, size.width, size.height / 2));
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}