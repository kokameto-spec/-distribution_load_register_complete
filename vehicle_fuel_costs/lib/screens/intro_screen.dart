import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_config.dart';

class IntroSequence extends StatefulWidget {
  final Widget next;

  const IntroSequence({super.key, required this.next});

  @override
  State<IntroSequence> createState() => _IntroSequenceState();
}

class _IntroSequenceState extends State<IntroSequence> {
  int _stage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1300), (timer) {
      if (!mounted) return;
      if (_stage < 2) {
        setState(() => _stage++);
      } else {
        timer.cancel();
        Future<void>.delayed(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 500),
              pageBuilder: (_, __, ___) => DedicationScreen(next: widget.next),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          );
        });
      }
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
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutBack,
                  scale: _stage >= 0 ? 1 : .86,
                  child: Image.asset(
                    'assets/company_logo.png',
                    width: 150,
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  AppConfig.companyName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: blue,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 28),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 550),
                  opacity: _stage >= 1 ? 1 : 0,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 550),
                    offset: _stage >= 1 ? Offset.zero : const Offset(0, .25),
                    child: const Text(
                      'تحكم ٢٦',
                      style: TextStyle(
                        color: blue,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 550),
                  opacity: _stage >= 2 ? 1 : 0,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 550),
                    offset: _stage >= 2 ? Offset.zero : const Offset(0, .25),
                    child: const Text(
                      'وسائل النقل',
                      style: TextStyle(
                        color: Color(0xFF333333),
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, __, ___) => widget.next,
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
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
            duration: const Duration(milliseconds: 900),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 42),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.favorite_rounded, color: blue, size: 54),
                  const SizedBox(height: 26),
                  const Text(
                    'إهداء',
                    style: TextStyle(
                      color: blue,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'إلى الأخ والصديق\nأحمد محمد فهمى',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 27,
                      height: 1.6,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: 80,
                    height: 2,
                    color: blue.withOpacity(.35),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'مع خالص التمنيات بالتوفيق والنجاح',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF444444),
                      fontSize: 21,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
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
