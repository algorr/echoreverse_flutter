import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'paywall_screen.dart';
import 'dart:math' as math;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _pages = [
    OnboardingData(
      title: 'Record & Reverse',
      description:
          'Record any sound and play it backwards instantly with one tap.',
      icon: Icons.mic,
    ),
    OnboardingData(
      title: 'Challenge Mode',
      description:
          'Test your skills! Try to speak words in reverse and see if you can nail the pronunciation.',
      icon: Icons.compare_arrows,
    ),
    OnboardingData(
      title: 'Audio Filters',
      description:
          'Apply hilarious filters to your recordings and transform your voice in seconds.',
      icon: Icons.graphic_eq,
    ),
    OnboardingData(
      title: 'Visual Fun!',
      description:
          'Turn your voice into wacky waveforms and share the art with friends.',
      icon: Icons.waves,
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const PaywallScreen(isFromOnboarding: true),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: SafeArea(
        child: Column(
          children: [
            // Skip Button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            // Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPageContent(_pages[index], index);
                },
              ),
            ),

            // Bottom Controls
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 6,
                        width: _currentPage == index ? 24 : 6,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? const Color(0xFF22D3EE)
                              : Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage == _pages.length - 1) {
                          _completeOnboarding();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF22D3EE),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 8,
                        shadowColor: const Color(
                          0xFF22D3EE,
                        ).withValues(alpha: 0.4),
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1
                            ? 'Get Started'
                            : 'Next',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent(OnboardingData data, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Graphic Area
          SizedBox(height: 320, child: Center(child: _buildGraphic(index))),
          const SizedBox(height: 40),

          // Title
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphic(int index) {
    switch (index) {
      case 0: // Record & Reverse
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulse rings
            ...List.generate(3, (i) => _PulseRing(delay: i * 0.5)),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2563EB),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 48),
            ),
            // Side waves similar to screenshot
            Positioned(
              left: 10,
              child: _SimpleWave(
                height: 60,
                color: Colors.blue.withValues(alpha: 0.3),
              ),
            ),
            Positioned(
              right: 10,
              child: _SimpleWave(
                height: 60,
                color: Colors.blue.withValues(alpha: 0.3),
              ),
            ),
          ],
        );

      case 1: // Challenge
        return Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SAY THIS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'HELLO',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Icon(
                Icons.swap_vert,
                size: 30,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 20),
              Text(
                'LIKE THIS',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF22D3EE), Color(0xFF06B6D4)],
                ).createShader(bounds),
                child: const Text(
                  'OLLEH',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );

      case 2: // Filters
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _FilterIcon(
              icon: Icons.smart_toy,
              label: 'Robot',
              color: Colors.grey,
            ),
            const SizedBox(width: 20),
            Transform.translate(
              offset: const Offset(0, -20),
              child: _FilterIcon(
                icon: Icons.pest_control_rodent, // Chipmunk-ish
                label: 'Chipmunk',
                color: const Color(0xFF2563EB),
                isActive: true,
              ),
            ),
            const SizedBox(width: 20),
            _FilterIcon(
              icon: Icons.spatial_audio_off,
              label: 'Echo',
              color: Colors.grey,
            ),
          ],
        );

      case 3: // Visual Fun (Weird Shape)
        return Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFD946EF).withValues(alpha: 0.3),
            ),
          ),
          child: CustomPaint(painter: _OnboardingShapePainter()),
        );

      default:
        return const SizedBox();
    }
  }
}

class OnboardingData {
  final String title;
  final String description;
  final IconData icon;

  OnboardingData({
    required this.title,
    required this.description,
    required this.icon,
  });
}

class _PulseRing extends StatefulWidget {
  final double delay;
  const _PulseRing({required this.delay});

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    Future.delayed(Duration(milliseconds: (widget.delay * 1000).toInt()), () {
      if (mounted) _controller.repeat();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 100 + (_controller.value * 200),
          height: 100 + (_controller.value * 200),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(
                0xFF2563EB,
              ).withValues(alpha: 1 - _controller.value),
              width: 1,
            ),
          ),
        );
      },
    );
  }
}

class _FilterIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isActive;

  const _FilterIcon({
    required this.icon,
    required this.label,
    required this.color,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isActive ? color : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Icon(icon, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            color: isActive ? color : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _OnboardingShapePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Draw a simple neon spiral/mesh for demo
    for (int i = 0; i < 20; i++) {
      final hue = (i / 20) * 360;
      paint.color = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();
      canvas.drawLine(
        Offset(centerX - 40 + (i * 4), centerY + math.sin(i.toDouble()) * 20),
        Offset(centerX - 40 + (i * 4), centerY - math.sin(i.toDouble()) * 20),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SimpleWave extends StatelessWidget {
  final double height;
  final Color color;
  const _SimpleWave({required this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
