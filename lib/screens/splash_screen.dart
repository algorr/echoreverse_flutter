import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../config/constants.dart';
import '../widgets/main_recorder.dart';
import 'onboarding_screen.dart';
import 'paywall_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // Background blobs animations
  late AnimationController _blobController;

  @override
  void initState() {
    super.initState();

    // Main logo animations
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    // Continuous background movement
    _blobController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _controller.forward();

    // Navigate to next screen
    Timer(const Duration(seconds: 3), () async {
      await _initRevenueCat();
      final isSubscribed = await _checkSubscription();

      final prefs = await SharedPreferences.getInstance();
      final onBoardingCompleted =
          prefs.getBool('onboarding_completed') ?? false;

      if (mounted) {
        Widget targetScreen;

        if (!onBoardingCompleted) {
          // New User: Onboarding -> Paywall -> Main
          targetScreen = const OnboardingScreen();
        } else if (!isSubscribed) {
          // Returning User (No Sub): Paywall -> Main
          targetScreen = const PaywallScreen();
        } else {
          // Subscribed User: Main
          targetScreen = const MainRecorder();
        }

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => targetScreen,
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  Future<void> _initRevenueCat() async {
    debugPrint('═══════════════════════════════════════════');
    debugPrint('🚀 REVENUECAT INITIALIZATION');
    debugPrint('═══════════════════════════════════════════');
    try {
      await Purchases.setLogLevel(LogLevel.debug);
      PurchasesConfiguration configuration = PurchasesConfiguration(
        AppConstants.revenueCatSdkKey,
      );
      await Purchases.configure(configuration);
      debugPrint('✅ RevenueCat SDK configured');
      debugPrint('   API Key: ${AppConstants.revenueCatSdkKey.substring(0, 10)}...');

      // Pre-fetch offerings
      debugPrint('───────────────────────────────────────────');
      debugPrint('🔄 Pre-fetching offerings...');
      try {
        final offerings = await Purchases.getOfferings();
        debugPrint('📋 Total offerings: ${offerings.all.length}');
        debugPrint('📋 Current offering: ${offerings.current?.identifier ?? "NONE"}');

        if (offerings.current != null) {
          debugPrint('✅ Current offering has ${offerings.current!.availablePackages.length} packages');
          for (var pkg in offerings.current!.availablePackages) {
            debugPrint('   📦 ${pkg.identifier}');
            debugPrint('      product_id: ${pkg.storeProduct.identifier}');
            debugPrint('      price: ${pkg.storeProduct.priceString}');
          }
        } else {
          debugPrint('⚠️ NO CURRENT OFFERING!');
          debugPrint('   Available offerings: ${offerings.all.keys.toList()}');
        }
      } catch (e) {
        debugPrint('⚠️ Pre-fetch error: $e');
      }
      debugPrint('═══════════════════════════════════════════');
    } catch (e) {
      debugPrint('❌ RevenueCat init error: $e');
    }
  }

  Future<bool> _checkSubscription() async {
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      return customerInfo
              .entitlements
              .all[AppConstants.entitlementId]
              ?.isActive ??
          false;
    } catch (e) {
      return false; // Assume not subscribed on error
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _blobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617), // Deep dark app background
      body: Stack(
        children: [
          // Background Glows (Animated)
          _buildBackgroundBlobs(),

          // Center Content
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF22D3EE).withValues(alpha: 0.3),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                          BoxShadow(
                            color: const Color(0xFFD946EF).withValues(alpha: 0.2),
                            blurRadius: 40,
                            spreadRadius: -10,
                            offset: const Offset(10, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 120,
                          height: 120,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // App Title
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF22D3EE), Color(0xFFD946EF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: const Text(
                        'REVERSO',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8,
                          color: Colors.white,
                          fontFamily:
                              'Roboto', // Using default font matching app
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Tagline
                    Text(
                      'AUDIO TIME MACHINE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 4,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Loading Indicator at bottom
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color(0xFF22D3EE).withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundBlobs() {
    return AnimatedBuilder(
      animation: _blobController,
      builder: (context, child) {
        return Stack(
          children: [
            // Blob 1 (Top Left - Cyan)
            Positioned(
              top: -100 + (_blobController.value * 20),
              left: -100 - (_blobController.value * 20),
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF22D3EE).withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Blob 2 (Bottom Right - Magenta)
            Positioned(
              bottom: -100 - (_blobController.value * 30),
              right: -100 + (_blobController.value * 20),
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFD946EF).withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
