import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/constants.dart';
import '../widgets/main_recorder.dart';

class PaywallScreen extends StatefulWidget {
  final bool isFromOnboarding;

  const PaywallScreen({super.key, this.isFromOnboarding = false});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _hasError = false;
  Package? _selectedPackage;
  List<Package> _packages = [];

  late AnimationController _pulseController;
  late AnimationController _shakeController;

  // Countdown timer for urgency
  int _minutesLeft = 14;
  int _secondsLeft = 59;
  Timer? _countdownTimer;

  // Social proof numbers
  final int _todayPurchases = 47 + Random().nextInt(30);
  final int _totalUsers = 1000 + Random().nextInt(100);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _startCountdown();
    _fetchOfferings();

    // Periodic shake for attention
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted)
        _shakeController.forward().then((_) => _shakeController.reset());
    });
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsLeft > 0) {
            _secondsLeft--;
          } else if (_minutesLeft > 0) {
            _minutesLeft--;
            _secondsLeft = 59;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOfferings() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      Offerings offerings = await Purchases.getOfferings();
      if (offerings.current != null &&
          offerings.current!.availablePackages.isNotEmpty) {
        setState(() {
          _packages = offerings.current!.availablePackages;
          _selectedPackage = _packages.firstWhere(
            (p) => p.packageType == PackageType.lifetime,
            orElse: () => _packages.firstWhere(
              (p) => p.packageType == PackageType.annual,
              orElse: () => _packages.first,
            ),
          );
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _purchasePackage(Package? package) async {
    if (package == null) return;
    setState(() => _isLoading = true);
    try {
      CustomerInfo customerInfo = await Purchases.purchasePackage(package);
      if (customerInfo.entitlements.all["echoreverse_pro"]?.isActive == true) {
        _navigateToHome();
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);
    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      if (customerInfo.entitlements.all["echoreverse_pro"]?.isActive == true) {
        _navigateToHome();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No active subscription found.")),
          );
        }
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToHome() {
    if (widget.isFromOnboarding) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainRecorder()),
        (route) => false,
      );
    } else {
      Navigator.pop(context);
    }
  }

  List<Package> _getSortedPackages() {
    const order = {
      PackageType.lifetime: 0,
      PackageType.annual: 1,
      PackageType.monthly: 2,
      PackageType.weekly: 3,
    };
    final sorted = List<Package>.from(_packages);
    sorted.sort((a, b) {
      final orderA = order[a.packageType] ?? 99;
      final orderB = order[b.packageType] ?? 99;
      return orderA.compareTo(orderB);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final w = constraints.maxWidth;
          final scale = (h / 812).clamp(0.55, 1.0);

          return Stack(
            children: [
              // Animated gradient background
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          Color(0xFFD946EF).withValues(
                            alpha: 0.08 + (_pulseController.value * 0.05),
                          ),
                          const Color(0xFF020617),
                          Color(0xFF22D3EE).withValues(
                            alpha: 0.05 + (_pulseController.value * 0.03),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: w * 0.05),
                  child: Column(
                    children: [
                      // === TOP SECTION ===
                      // Header with urgency timer
                      SizedBox(
                        height: 36 * scale,
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: _restorePurchases,
                              child: Text(
                                'Restore',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12 * scale,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10 * scale,
                                vertical: 4 * scale,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12 * scale),
                                border: Border.all(
                                  color: Colors.red.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.timer,
                                    color: Colors.red[300],
                                    size: 14 * scale,
                                  ),
                                  SizedBox(width: 4 * scale),
                                  Text(
                                    '${_minutesLeft.toString().padLeft(2, '0')}:${_secondsLeft.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      color: Colors.red[300],
                                      fontSize: 13 * scale,
                                      fontWeight: FontWeight.bold,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () =>
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => const MainRecorder(),
                                    ),
                                  ),
                              child: Icon(
                                Icons.close,
                                color: Colors.white38,
                                size: 22 * scale,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // LIMITED OFFER Banner
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 5 * scale),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.withValues(alpha: 0.25),
                              Colors.orange.withValues(alpha: 0.25),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(6 * scale),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.bolt,
                              color: Colors.amber,
                              size: 14 * scale,
                            ),
                            SizedBox(width: 4 * scale),
                            Text(
                              'LIMITED TIME: 70% OFF',
                              style: TextStyle(
                                color: Colors.amber,
                                fontSize: 11 * scale,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(flex: 1),

                      // === HERO SECTION ===
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20 * scale),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFD946EF,
                              ).withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20 * scale),
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 80 * scale,
                            height: 80 * scale,
                          ),
                        ),
                      ),
                      SizedBox(height: 10 * scale),
                      Text(
                        "Don't Miss the Fun!",
                        style: TextStyle(
                          fontSize: 24 * scale,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4 * scale),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ...List.generate(
                            5,
                            (i) => Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 14 * scale,
                            ),
                          ),
                          SizedBox(width: 6 * scale),
                          Text(
                            '4.9 (${(_totalUsers / 1000).toStringAsFixed(0)}K+)',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11 * scale,
                            ),
                          ),
                          SizedBox(width: 10 * scale),
                          Container(
                            width: 6 * scale,
                            height: 6 * scale,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 4 * scale),
                          Text(
                            '$_todayPurchases today',
                            style: TextStyle(
                              color: Colors.green[300],
                              fontSize: 11 * scale,
                            ),
                          ),
                        ],
                      ),

                      const Spacer(flex: 1),

                      // === BENEFITS ===
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildCompactBenefit(
                            Icons.all_inclusive,
                            'Unlimited',
                            scale,
                          ),
                          _buildCompactBenefit(
                            Icons.music_note,
                            '8 Effects',
                            scale,
                          ),
                          _buildCompactBenefit(Icons.hd, 'HD Export', scale),
                          _buildCompactBenefit(
                            Icons.emoji_events,
                            'Challenge',
                            scale,
                          ),
                        ],
                      ),

                      const Spacer(flex: 1),

                      // === PACKAGES ===
                      if (_packages.isEmpty && _isLoading)
                        const CircularProgressIndicator(
                          color: Color(0xFFD946EF),
                        )
                      else if (_hasError && _packages.isEmpty)
                        TextButton.icon(
                          onPressed: _fetchOfferings,
                          icon: const Icon(
                            Icons.refresh,
                            color: Color(0xFFD946EF),
                          ),
                          label: const Text(
                            'Retry',
                            style: TextStyle(color: Color(0xFFD946EF)),
                          ),
                        )
                      else
                        ..._getSortedPackages().map((pkg) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: 8 * scale),
                            child: _buildPackageCard(pkg, scale),
                          );
                        }),

                      const Spacer(flex: 1),

                      // === CTA BUTTON ===
                      AnimatedBuilder(
                        animation: Listenable.merge([
                          _pulseController,
                          _shakeController,
                        ]),
                        builder: (context, child) {
                          final shakeOffset =
                              sin(_shakeController.value * pi * 4) * 3;
                          return Transform.translate(
                            offset: Offset(shakeOffset, 0),
                            child: Container(
                              width: double.infinity,
                              height: 52 * scale,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(26 * scale),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFD946EF),
                                    Color(0xFFE879F9),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFD946EF).withValues(
                                      alpha:
                                          0.4 + (_pulseController.value * 0.3),
                                    ),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed:
                                    (_isLoading || _selectedPackage == null)
                                    ? null
                                    : () => _purchasePackage(_selectedPackage),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      26 * scale,
                                    ),
                                  ),
                                ),
                                child: _isLoading && _packages.isNotEmpty
                                    ? SizedBox(
                                        width: 24 * scale,
                                        height: 24 * scale,
                                        child: const CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.celebration,
                                            size: 20 * scale,
                                          ),
                                          SizedBox(width: 8 * scale),
                                          Text(
                                            'START THE FUN',
                                            style: TextStyle(
                                              fontSize: 16 * scale,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          );
                        },
                      ),

                      SizedBox(height: 6 * scale),

                      // === FOOTER ===
                      Text(
                        "⚠️ Offer ends when timer runs out",
                        style: TextStyle(
                          color: Colors.red[300],
                          fontSize: 10 * scale,
                        ),
                      ),
                      SizedBox(height: 4 * scale),
                      Text(
                        'Secure payment • Cancel Anytime',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 10 * scale,
                        ),
                      ),
                      SizedBox(height: 6 * scale),

                      // Terms & Privacy at very bottom
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLegalLink(
                            'Terms of Use',
                            AppConstants.termsUrl,
                            scale,
                          ),
                          Text(
                            '  •  ',
                            style: TextStyle(
                              color: Colors.white24,
                              fontSize: 10 * scale,
                            ),
                          ),
                          _buildLegalLink(
                            'Privacy Policy',
                            AppConstants.privacyUrl,
                            scale,
                          ),
                        ],
                      ),
                      SizedBox(height: 6 * scale),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCompactBenefit(IconData icon, String label, double scale) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8 * scale),
          decoration: BoxDecoration(
            color: const Color(0xFF22D3EE).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10 * scale),
          ),
          child: Icon(icon, color: const Color(0xFF22D3EE), size: 18 * scale),
        ),
        SizedBox(height: 4 * scale),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 10 * scale,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPackageCard(Package pkg, double scale) {
    final isSelected = _selectedPackage == pkg;
    final isLifetime = pkg.packageType == PackageType.lifetime;
    final isAnnual = pkg.packageType == PackageType.annual;

    // ANCHORING: Show fake original price
    String? originalPrice;
    String? savePercent;
    if (isLifetime) {
      final original = pkg.storeProduct.price * 3.3;
      originalPrice =
          '${pkg.storeProduct.currencyCode} ${original.toStringAsFixed(2)}';
      savePercent = '70%';
    } else if (isAnnual) {
      final original = pkg.storeProduct.price * 2;
      originalPrice =
          '${pkg.storeProduct.currencyCode} ${original.toStringAsFixed(2)}';
      savePercent = '50%';
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedPackage = pkg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: 12 * scale,
          vertical: 10 * scale,
        ),
        decoration: BoxDecoration(
          gradient: isSelected && isLifetime
              ? LinearGradient(
                  colors: [
                    const Color(0xFFD946EF).withValues(alpha: 0.3),
                    const Color(0xFF22D3EE).withValues(alpha: 0.2),
                  ],
                )
              : null,
          color: isSelected && !isLifetime
              ? const Color(0xFFD946EF).withValues(alpha: 0.2)
              : !isSelected
              ? Colors.white.withValues(alpha: 0.05)
              : null,
          borderRadius: BorderRadius.circular(14 * scale),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFD946EF)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio
            Container(
              width: 20 * scale,
              height: 20 * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? const Color(0xFFD946EF)
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected ? const Color(0xFFD946EF) : Colors.white30,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(Icons.check, size: 12 * scale, color: Colors.white)
                  : null,
            ),
            SizedBox(width: 10 * scale),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _getTitle(pkg.packageType),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14 * scale,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isLifetime) ...[
                        SizedBox(width: 6 * scale),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6 * scale,
                            vertical: 2 * scale,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(4 * scale),
                          ),
                          child: Text(
                            'POPULAR',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 8 * scale,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    _getSubtitle(pkg),
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11 * scale,
                    ),
                  ),
                ],
              ),
            ),

            // Price with anchoring
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (originalPrice != null)
                  Text(
                    originalPrice,
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11 * scale,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pkg.storeProduct.priceString,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16 * scale,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (savePercent != null) ...[
                      SizedBox(width: 4 * scale),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 4 * scale,
                          vertical: 1 * scale,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4 * scale),
                        ),
                        child: Text(
                          '-$savePercent',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9 * scale,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getTitle(PackageType type) {
    switch (type) {
      case PackageType.lifetime:
        return 'Lifetime';
      case PackageType.annual:
        return 'Yearly';
      case PackageType.monthly:
        return 'Monthly';
      case PackageType.weekly:
        return 'Weekly';
      default:
        return 'Subscribe';
    }
  }

  String _getSubtitle(Package pkg) {
    switch (pkg.packageType) {
      case PackageType.lifetime:
        return 'Pay once, yours forever';
      case PackageType.annual:
        final m = pkg.storeProduct.price / 12;
        return 'Just ${pkg.storeProduct.currencyCode} ${m.toStringAsFixed(2)}/mo';
      case PackageType.weekly:
        return 'Billed every week';
      default:
        return 'Cancel anytime';
    }
  }

  Widget _buildLegalLink(String text, String url, double scale) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Text(
        text,
        style: TextStyle(color: Colors.white30, fontSize: 10 * scale),
      ),
    );
  }
}
