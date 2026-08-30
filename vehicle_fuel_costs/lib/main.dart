import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'config/app_config.dart';
import 'screens/home_screen.dart';
import 'screens/intro_screen.dart';
import 'services/firebase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');

  Object? firebaseError;
  if (AppConfig.firebaseConfigured) {
    try {
      await Firebase.initializeApp(options: AppConfig.firebaseOptions);
      await FirebaseService.instance.ensureAnonymousAuth();
    } catch (e) {
      firebaseError = e;
    }
  } else {
    firebaseError = 'بيانات Firebase غير مضافة بعد.';
  }

  runApp(FuelCostsApp(firebaseError: firebaseError));
}

class FuelCostsApp extends StatelessWidget {
  final Object? firebaseError;
  const FuelCostsApp({super.key, this.firebaseError});

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF0B4A8B);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'حساب تكاليف استهلاك السيارات',
      locale: const Locale('ar'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: blue),
        scaffoldBackgroundColor: const Color(0xFFF5F8FC),
        appBarTheme: const AppBarTheme(
          backgroundColor: blue,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: IntroSequence(
        next: firebaseError == null
            ? const HomeScreen()
            : _SetupScreen(error: firebaseError!),
      ),
    );
  }
}

class _SetupScreen extends StatelessWidget {
  final Object error;
  const _SetupScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعداد الاتصال')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off,
                      size: 70,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'المشروع جاهز، ويتبقى ربط Firebase',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'أضف إعدادات Firebase الخاصة بالمشروع ثم أعد بناء التطبيق.',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$error',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
