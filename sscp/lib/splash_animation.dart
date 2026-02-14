import 'package:flutter/material.dart';
import 'dart:math' as math;

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SplashAnimationScreen(next: NextScreen()),
  ));
}

class NextScreen extends StatelessWidget {
  const NextScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text("Home Screen")),
    );
  }
}

class SplashAnimationScreen extends StatefulWidget {
  final Widget next;

  const SplashAnimationScreen({super.key, required this.next});

  @override
  State<SplashAnimationScreen> createState() => _SplashAnimationScreenState();
}

class _SplashAnimationScreenState extends State<SplashAnimationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Animations
  late Animation<double> _doorRotation;
  late Animation<double> _slideOut;
  late Animation<double> _doorFadeOut;
  late Animation<double> _rScaleIn;
  late Animation<double> _textFadeIn;
  late Animation<double> _textSlideUp;
  late Animation<double> _footerFadeIn;

  // COLORS
  final Color _lightBg = const Color(0xFFD9E6F2);
  final Color _brandBlue = const Color(0xFF1F5292);

  // SETTINGS
  final double _finalSpacing = 60.0;
  final double _fontSize = 130.0;
  final double _doorWidthRatio = 0.65;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _doorRotation = Tween<double>(begin: 0.0, end: -math.pi / 2.4).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.30, curve: Curves.easeOutCubic),
      ),
    );

    _slideOut = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.30, 0.60, curve: Curves.easeOutBack),
      ),
    );

    _rScaleIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 1.0, curve: Curves.elasticOut),
      ),
    );

    _doorFadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.10, 0.46, curve: Curves.linear),
      ),
    );

    _textFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.60, 0.85, curve: Curves.easeIn),
      ),
    );

    _textSlideUp = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.60, 0.85, curve: Curves.easeOut),
      ),
    );

    _footerFadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.80, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => widget.next),
            );
          }
        });
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightBg,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- LOGO ANIMATION ---
                // Reduced height from 250 to 140 to tighten spacing
                SizedBox(
                  height: 140, 
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          Transform.translate(
                            offset: Offset(-_finalSpacing * _slideOut.value, 0),
                            child: Opacity(
                              opacity: _slideOut.value.clamp(0.0, 1.0),
                              child: _buildText("s"),
                            ),
                          ),
                          Transform.translate(
                            offset: Offset(_finalSpacing * _slideOut.value, 0),
                            child: Opacity(
                              opacity: _slideOut.value.clamp(0.0, 1.0),
                              child: _buildText("u"),
                            ),
                          ),
                          Transform(
                            alignment: Alignment.centerLeft,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateY(_doorRotation.value),
                            child: Opacity(
                              opacity: _doorFadeOut.value,
                              child: Container(
                                width: _fontSize * _doorWidthRatio,
                                height: _fontSize,
                                decoration: BoxDecoration(
                                  color: _brandBlue,
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 5,
                                      offset: Offset(2, 2),
                                    )
                                  ],
                                ),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 10.0),
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black12,
                                            blurRadius: 1,
                                            offset: Offset(-1, 1),
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Transform.scale(
                            scale: _rScaleIn.value,
                            child: Opacity(
                              opacity: _rScaleIn.value.clamp(0.0, 1.0),
                              child: _buildText("r"),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                
                // Add a small spacer if you want precise control, e.g., 10px
                const SizedBox(height: 10),

                // --- TEXT ANIMATION ---
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _textSlideUp.value),
                      child: Opacity(
                        opacity: _textFadeIn.value,
                        child: Column(
                          children: [
                            Text(
                              "SR UNIVERSITY",
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: _brandBlue,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // --- FOOTER ---
          Positioned(
            bottom:210,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _footerFadeIn.value,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.phone, size: 16, color: _brandBlue),
                      const SizedBox(width: 8),
                      Text(
                        "8331004040",
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _brandBlue,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Icon(Icons.language, size: 16, color: _brandBlue),
                      const SizedBox(width: 8),
                      Text(
                        "www.sru.edu.in",
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _brandBlue,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildText(String char) {
    return Text(
      char,
      style: TextStyle(
        fontFamily: 'Roboto',
        fontSize: _fontSize,
        fontWeight: FontWeight.w900,
        color: _brandBlue,
        height: 1.0,
      ),
    );
  }
}