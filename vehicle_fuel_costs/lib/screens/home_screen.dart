import 'package:flutter/material.dart';

import 'driver_screen.dart';
import 'manager_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('حساب تكاليف استهلاك السيارات')),
    body: Center(child: Padding(padding: const EdgeInsets.all(20), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 700), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Image.asset('assets/company_logo.png', width: 110, height: 110),
      const SizedBox(height: 20),
      const Text('نظام تسجيل التموينات والاستهلاك', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 28),
      Row(children: [
        Expanded(child: SizedBox(height: 120, child: FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverScreen())), icon: const Icon(Icons.person, size: 38), label: const Text('السائق', style: TextStyle(fontSize: 22))))),
        const SizedBox(width: 16),
        Expanded(child: SizedBox(height: 120, child: OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagerScreen())), icon: const Icon(Icons.admin_panel_settings, size: 38), label: const Text('المدير', style: TextStyle(fontSize: 22))))),
      ]),
    ])))),
  );
}
