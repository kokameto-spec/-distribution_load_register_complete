import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_routes.dart';
import '../../controllers/auth_controller.dart';
import '../../models/user_role.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _hidePassword = true;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final auth = context.read<AuthController>();

    final success = await auth.login(
      code: _codeController.text,
      password: _passwordController.text,
    );

    if (!success || !mounted) {
      return;
    }

    final route = switch (auth.currentUser!.role) {
      UserRole.dataEntry => AppRoutes.dataEntry,
      UserRole.manager => AppRoutes.manager,
      UserRole.president => AppRoutes.president,
    };

    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      backgroundColor: const Color(0xFFBFEAFF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 430,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 28,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDF5FF),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: const Color(0xFF64B5F6),
                    width: 1.4,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'تحت رعاية',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF063D77),
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'السيد المهندس حسن محمود الفرجانى',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF073B75),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      const Text(
                        'رئيس قطاع تحكمات جنوب',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF073B75),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 34),

                      const Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: Color(0xFF5BA6D9),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 14,
                            ),
                            child: Text(
                              'تسجيل الدخول',
                              style: TextStyle(
                                color: Color(0xFF063D77),
                                fontSize: 23,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: Color(0xFF5BA6D9),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      TextFormField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'كود الدخول',
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            color: Color(0xFF0D67B5),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFB2D4E8),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF0878D1),
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'أدخل كود الدخول.';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _passwordController,
                        obscureText: _hidePassword,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: Color(0xFF0D67B5),
                          ),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _hidePassword = !_hidePassword;
                              });
                            },
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: const Color(0xFF0D67B5),
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFB2D4E8),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF0878D1),
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.isEmpty) {
                            return 'أدخل كلمة المرور.';
                          }

                          return null;
                        },
                        onFieldSubmitted: (_) {
                          _login();
                        },
                      ),

                      if (auth.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          auth.errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],

                      const SizedBox(height: 22),

                      SizedBox(
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed:
                              auth.isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF0878D1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(14),
                            ),
                          ),
                          icon: auth.isLoading
                              ? const SizedBox(
                                  width: 21,
                                  height: 21,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.login),
                          label: const Text(
                            'دخول',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      const Divider(
                        color: Color(0xFF8BC5E8),
                      ),

                      const SizedBox(height: 15),

                      const Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: Color(0xFF075BA8),
                            size: 23,
                          ),
                          SizedBox(width: 9),
                          Flexible(
                            child: Text(
                              'فكرة السيد المهندس إبراهيم عبد الحي',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF063D77),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      const Divider(
                        color: Color(0xFF8BC5E8),
                      ),

                      const SizedBox(height: 14),

                      const Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.code_rounded,
                            color: Color(0xFF075BA8),
                            size: 24,
                          ),
                          SizedBox(width: 9),
                          Flexible(
                            child: Text(
                              'تصميم وبرمجة  محمد سامي ',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF063D77),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}