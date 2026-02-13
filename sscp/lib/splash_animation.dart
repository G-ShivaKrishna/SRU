import 'package:flutter/material.dart';
import 'dart:math' as math;

/// A reusable splash animation that shows the SRU sequence
/// and then navigates to [next] when finished.
class SplashAnimationScreen extends StatefulWidget {
  final Widget next;

  const SplashAnimationScreen({super.key, required this.next});

  @override
  State<SplashAnimationScreen> createState() => _SplashAnimationScreenState();
}

class _SplashAnimationScreenState extends State<SplashAnimationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  late Animation<double> _doorRotation;
  late Animation<double> _slideOut;
  late Animation<double> _doorFadeOut;
  late Animation<double> _rScaleIn;

  // BRAND COLORS
  final Color _brandBlue = const Color(0xFF1F5292);

  // SETTINGS
  final double _finalSpacing = 55.0;
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

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => widget.next),
        );
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
      backgroundColor: _brandBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 250,
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
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 5,
                                    offset: Offset(2, 2),
                                  )
                                ]),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 10.0),
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: _brandBlue,
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

            // replay button removed
          ],
        ),
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
        color: Colors.white,
        height: 1.0,
      ),
    );
  }
}
