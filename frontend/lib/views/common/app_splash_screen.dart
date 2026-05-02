import 'package:flutter/material.dart';

import 'bovisense_logo.dart';

class AppSplashScreen extends StatefulWidget {
  const AppSplashScreen({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1700),
  });

  final Widget child;
  final Duration duration;

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen> {
  bool _showApp = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.duration, () {
      if (!mounted) return;
      setState(() => _showApp = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 360),
      child: _showApp ? widget.child : const _SplashView(),
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F1EB),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              BoviSenseLogo(size: 160),
              SizedBox(height: 18),
              Text(
                'BoviSense',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D4228),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Inteligencia aplicada al campo',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF5A7254),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A6741)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
