import 'dart:async';

import 'package:flutter/material.dart';

import '../../settings/views/settings_view.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const AssetImage _heroImage = AssetImage('assets/images/logos.png');

  Timer? _navigationTimer;
  bool _didStartSplash = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didStartSplash) {
        return;
      }

      _didStartSplash = true;
      _prepareSplash();
    });
  }

  Future<void> _prepareSplash() async {
    await precacheImage(_heroImage, context);
    if (!mounted) {
      return;
    }
    _navigationTimer = Timer(const Duration(seconds: 3), _openApp);
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  void _openApp() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => const MainNavigationShell(),
        transitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final heroWidth = width * 0.86;

            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.scale(
                            scale: 0.92 + (0.08 * value),
                            child: child,
                          ),
                        );
                      },
                      child: Image.asset(
                        _heroImage.assetName,
                        width: heroWidth,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const Spacer(flex: 4),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
