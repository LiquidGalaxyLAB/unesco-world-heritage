import 'dart:async';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';

import '../../settings/views/settings_view.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const AssetImage _topImage = AssetImage('assets/images/project logos/unesco_image.png');

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
    await precacheImage(_topImage, context);
    if (!mounted) {
      return;
    }
    _navigationTimer = Timer(const Duration(milliseconds: 1800), _openApp);
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
    final height = MediaQuery.sizeOf(context).height;
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: width * 0.95,
                  child: Image.asset('assets/images/project logos/unesco_image.png'),
                ),
                SizedBox(height: height * 0.03),
                SizedBox(
                  width: width * 0.7,
                  child: Text(
                    'UNESCO World Heritage',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontSize: height * 0.03,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: height * 0.05),
                SizedBox(
                  height: height * 0.075,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Image.asset('assets/images/project logos/lg.png'),
                      Image.asset('assets/images/project logos/gsoc.png'),
                    ],
                  ),
                ),
                SizedBox(height: height * 0.05),
                SizedBox(
                  height: height * 0.0325,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: height * 0.005),
                        child: Image.asset('assets/images/project logos/lg_eu.png'),
                      ),
                      Image.asset('assets/images/project logos/lg_lab.png'),
                      Image.asset('assets/images/project logos/gdg_lleida_logo.png'),
                      Image.asset('assets/images/project logos/Flutter_leida.png'),
                      Image.asset('assets/images/project logos/Tic.png'),
                      Image.asset('assets/images/project logos/Parc_AgrobioTech_Lleida-removebg-preview.png'),
                    ],
                  ),
                ),
                SizedBox(height: height * 0.05),
                SizedBox(
                  height: height * 0.0375,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Image.asset('assets/images/project logos/Build_with_ai.png'),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: height * 0.005),
                        child: Image.asset('assets/images/project logos/gemini_logo.png'),
                      ),
                      Image.asset('assets/images/project logos/LiquidGalaxyAI.png'),
                      Image.asset('assets/images/project logos/college.png'),
                      Image.asset('assets/images/project logos/Android_robot.png'),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: height * 0.005),
                        child: Image.asset('assets/images/project logos/flutter.png'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
