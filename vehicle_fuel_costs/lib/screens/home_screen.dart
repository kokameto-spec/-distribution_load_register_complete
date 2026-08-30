import 'package:flutter/material.dart';

import '../services/app_auth_service.dart';
import 'driver_screen.dart';
import 'manager_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      _msg('أدخل اسم المستخدم وكلمة المرور.');
      return;
    }
    setState(() => _busy = true);
    try {
      final user = await AppAuthService.instance.login(_username.text, _password.text);
      if (user == null) {
        _msg('بيانات الدخول غير صحيحة أو الحساب غير مفعل.');
        return;
      }
      if (!mounted) return;
      if (user.isManager) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => ManagerScreen(user: user)));
      } else {
        if (user.vehicleCode.isEmpty) {
          _msg('حساب السائق غير مربوط بسيارة. راجع المدير.');
          return;
        }
        await Navigator.push(context, MaterialPageRoute(builder: (_) => DriverScreen(user: user)));
      }
      _password.clear();
    } catch (e) {
      _msg('تعذر تسجيل الدخول: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('تسجيل الدخول')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    Image.asset('assets/company_logo.png', width: 105, height: 105),
                    const SizedBox(height: 12),
                    const Text('تحكم ٢٦ — وسائل النقل', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('نظام تسجيل تموين واستهلاك السيارات', style: TextStyle(color: Colors.black54)),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _username,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'اسم المستخدم', prefixIcon: Icon(Icons.person_outline)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      onSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _login,
                        icon: _busy
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.login),
                        label: const Text('دخول'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('الحساب الأول للمدير: admin / 2600\nبعد الدخول يمكن إنشاء حسابات السائقين وربطها بالسيارات.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}
