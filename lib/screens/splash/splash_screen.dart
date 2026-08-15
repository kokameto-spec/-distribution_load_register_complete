import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer(
      const Duration(seconds: 10),
      () {
        if (!mounted) {
          return;
        }

        Navigator.of(context).pushReplacementNamed(
          AppRoutes.login,
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE9F7FF),
              Color(0xFFC6E9FF),
              Color(0xFF8CCAF2),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/company_logo.png',
                    width: 230,
                    height: 200,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(height: 22),

                  const Text(
                    'شركة جنوب القاهرة لتوزيع الكهرباء',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF073B75),
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 14),

                  const Text(
                    'قطاع التحكمات والوقاية',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFE84A13),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'تحكم 26 يوليو',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF073B75),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 30),

                  Container(
                    width: 110,
                    height: 2,
                    color: const Color(0xFF6DAED8),
                  ),

                  const SizedBox(height: 25),

                  const Text(
                    'تحت اشراف مدير عام تحكم26',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFE84A13),
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'المهندس وائل على شحاته',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF073B75),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 28),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF073B75),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      ' الإصدار 3.6.6',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  const CircularProgressIndicator(
                    color: Color(0xFF073B75),
                    strokeWidth: 3,
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'جاري التحميل...',
                    style: TextStyle(
                      color: Color(0xFF073B75),
                      fontSize: 14,
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
