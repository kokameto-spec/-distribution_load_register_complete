import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../config/app_config.dart';

class IntroSequence extends StatefulWidget {
  final Widget next;
  const IntroSequence({super.key, required this.next});

  @override
  State<IntroSequence> createState() => _IntroSequenceState();
}

class _IntroSequenceState extends State<IntroSequence> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 450),
          pageBuilder: (_, __, ___) => DedicationScreen(next: widget.next),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF0B4A8B);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/company_logo.png', width: 155, height: 155, fit: BoxFit.contain),
                const SizedBox(height: 24),
                const Text(
                  AppConfig.companyName,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: blue, fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 24),
                const Text('تحكم ٢٦', style: TextStyle(color: blue, fontSize: 34, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                const Text('وسائل النقل', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DedicationScreen extends StatefulWidget {
  final Widget next;
  const DedicationScreen({super.key, required this.next});

  @override
  State<DedicationScreen> createState() => _DedicationScreenState();
}

class _DedicationScreenState extends State<DedicationScreen> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _visible = true);
    });
    _timer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 450),
          pageBuilder: (_, __, ___) => widget.next,
          transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF0B4A8B);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 700),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 36),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset('assets/fueling_car.svg', width: 210, height: 210),
                  const SizedBox(height: 28),
                  const Text(
                    'إهداء إلى أحمد فهمى',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: blue, fontSize: 30, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'مع أطيب التمنيات بالنجاح',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 23, height: 1.5, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
