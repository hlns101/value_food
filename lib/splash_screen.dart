
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({
    super.key,
    required this.nextScreen,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Color blue = Color(0xFF206589);
  static const Color green = Color(0xFF7AB84D);

  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Fade in while the header is centered.
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(
        0.0,
        0.32,
        curve: Curves.easeInOut,
      ),
    );

    // After fading in, move the header upwards.
    _slideAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(
        0.32,
        0.88,
        curve: Curves.easeInOutCubic,
      ),
    );

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    await _controller.forward();

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) {
          return widget.nextScreen;
        },
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        transitionsBuilder: (
          context,
          animation,
          secondaryAnimation,
          child,
        ) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final logoHeight = screenHeight / 5;
    final logoWidth = screenWidth / 2;

    // Approximate height of the same header on LandingPage.
    final headerHeight = logoHeight + 20 + 60 + 25;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;

            // Matches LandingPage's initial top spacing.
            final finalTop = screenHeight * 0.03;

            // Starts with the complete header centered.
            final centerTop = (availableHeight - headerHeight) / 2;

            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final currentTop = centerTop +
                    (finalTop - centerTop) * _slideAnimation.value;

                return Stack(
                  children: [
                    Positioned(
                      top: currentTop,
                      left: 0,
                      right: 0,
                      child: Opacity(
                        opacity: _fadeAnimation.value,
                        child: child,
                      ),
                    ),
                  ],
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/new_logo.png',
                    height: logoHeight,
                    width: logoWidth,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),

                  const SizedBox(height: 20),

                  const Text.rich(
                    TextSpan(
                      text: 'Value',
                      style: TextStyle(
                        color: blue,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        fontFamily: 'Poppins-Bold',
                      ),
                      children: [
                        TextSpan(
                          text: 'Food',
                          style: TextStyle(color: green),
                        ),
                      ],
                    ),
                  ),

                  const Text(
                    'Smart Choice. Safe Nutrition. Maximum Value.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
