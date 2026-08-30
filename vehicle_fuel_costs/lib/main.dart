import 'package:firebase_core/firebase_core.dart' as fb;
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
      await fb.Firebase.initializeApp(options: AppConfig.firebaseOptions);
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
    const silver = Color(0xFFE3E5E8);
    const silverDark = Color(0xFF8A8F96);
    const gold = Color(0xFFD4AF37);
    const goldDark = Color(0xFF8A6A10);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'حساب تكاليف استهلاك السيارات',
      locale: const Locale('ar'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: gold, brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFF1F2F4),
        appBarTheme: const AppBarTheme(
          backgroundColor: silver,
          foregroundColor: Color(0xFF222222),
          centerTitle: true,
          elevation: 7,
          shadowColor: silverDark,
          surfaceTintColor: silver,
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: Color(0xFF2B2B2B),
          unselectedLabelColor: Color(0xFF5F6368),
          indicatorColor: gold,
          dividerColor: silverDark,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: ButtonStyle(
            backgroundColor: const WidgetStatePropertyAll(gold),
            foregroundColor: const WidgetStatePropertyAll(Color(0xFF241C08)),
            elevation: const WidgetStatePropertyAll(7),
            shadowColor: const WidgetStatePropertyAll(goldDark),
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: const WidgetStatePropertyAll(gold),
            foregroundColor: const WidgetStatePropertyAll(Color(0xFF241C08)),
            elevation: const WidgetStatePropertyAll(7),
            shadowColor: const WidgetStatePropertyAll(goldDark),
            shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: ButtonStyle(
            backgroundColor: const WidgetStatePropertyAll(Color(0xFFE8C85B)),
            foregroundColor: const WidgetStatePropertyAll(Color(0xFF2A230E)),
            shadowColor: const WidgetStatePropertyAll(goldDark),
            shape: const WidgetStatePropertyAll(CircleBorder()),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: .86),
          border: const OutlineInputBorder(),
          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: gold, width: 2)),
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
