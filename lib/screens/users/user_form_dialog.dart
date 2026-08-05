import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/distributor_controller.dart';
import '../../controllers/user_management_controller.dart';
import '../../models/app_user.dart';
import '../../models/distributor_model.dart';
import '../../models/user_role.dart';

class UserFormDialog extends StatefulWidget {
  const UserFormDialog({
    super.key,
    this.user,
  });

  final AppUser? user;

  bool get isEditing => user != null;

  @override
  State<UserFormDialog> createState() {
    return _UserFormDialogState();
  }
}

class _UserFormDialogState extends State<UserFormDialog> {
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _passwordController;

  late UserRole _selectedRole;

  String? _selectedDistributorId;

  bool _active = true;
  bool _obscurePassword = true;
  bool _isSaving = false;

  String? _errorMessage;

  bool get _isDataEntry {
    return _selectedRole == UserRole.dataEntry;
  }

  @override
  void initState() {
    super.initState();

    _codeController = TextEditingController(
      text: widget.user?.code ?? '',
    );

    _nameController = TextEditingController(
      text: widget.user?.displayName ?? '',
    );

    _passwordController = TextEditingController();

    _selectedRole =
        widget.user?.role ?? UserRole.dataEntry;

    _selectedDistributorId =
        widget.user?.distributorId;

    _active = widget.user?.active ?? true;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  String _roleValue(UserRole role) {
    switch (role) {
      case UserRole.president:
        return 'president';

      case UserRole.manager:
        return 'manager';

      case UserRole.dataEntry:
        return 'data_entry';
    }
  }

  String _roleName(UserRole role) {
    switch (role) {
      case UserRole.president:
        return 'الرئيس';

      case UserRole.manager:
        return 'المدير / المشغل';

      case UserRole.dataEntry:
        return 'مدخل بيانات';
    }
  }

  Distributor? _selectedDistributor(
      DistributorController controller,
      ) {
    final distributorId =
    _selectedDistributorId?.trim();

    if (distributorId == null ||
        distributorId.isEmpty) {
      return null;
    }

    return controller.findById(distributorId);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    final code = _codeController.text.trim();
    final password = _passwordController.text;

    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'اكتب كود الدخول.';
      });

      return;
    }

    if (!widget.isEditing &&
        password.length < 6) {
      setState(() {
        _errorMessage =
        'كلمة المرور يجب ألا تقل عن 6 أحرف أو أرقام.';
      });

      return;
    }

    final distributorController =
    context.read<DistributorController>();

    final distributor = _selectedDistributor(
      distributorController,
    );

    if (_isDataEntry && distributor == null) {
      setState(() {
        _errorMessage =
        'اختر الموزع الذي سيتم ربط كود الدخول به.';
      });

      return;
    }

    final String accountName;

    if (_isDataEntry) {
      /*
       * اسم الحساب الداخلي هو اسم الموزع.
       * اسم الشخص الفعلي يُكتب عند تسجيل الأحمال.
       */
      accountName = distributor!.name.trim();
    } else {
      accountName = _nameController.text.trim();

      if (accountName.isEmpty) {
        setState(() {
          _errorMessage = 'اكتب اسم المستخدم.';
        });

        return;
      }
    }

    final role = _roleValue(_selectedRole);

    final distributorId = _isDataEntry
        ? distributor!.id
        : '';

    final distributorName = _isDataEntry
        ? distributor!.name.trim()
        : '';

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final controller =
    context.read<UserManagementController>();

    final bool success;

    if (widget.isEditing) {
      success = await controller.updateUser(
        uid: widget.user!.uid,
        code: code,
        name: accountName,
        role: role,
        active: _active,
        distributorId: distributorId,
        distributorName: distributorName,
      );
    } else {
      success = await controller.createUser(
        code: code,
        name: accountName,
        password: password,
        role: role,
        distributorId: distributorId,
        distributorName: distributorName,
      );
    }

    if (!mounted) {
      return;
    }

    if (success) {
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _isSaving = false;
      _errorMessage =
          controller.errorMessage ??
              'تعذر حفظ بيانات المستخدم.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final distributorController =
    context.watch<DistributorController>();

    final distributors =
        distributorController.activeDistributors;

    return AlertDialog(
      title: Text(
        widget.isEditing
            ? 'تعديل الحساب'
            : 'إنشاء حساب جديد',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<UserRole>(
                initialValue: _selectedRole,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'نوع الحساب',
                  prefixIcon: Icon(
                    Icons.admin_panel_settings_outlined,
                  ),
                  border: OutlineInputBorder(),
                ),
                items: UserRole.values.map(
                      (role) {
                    return DropdownMenuItem<UserRole>(
                      value: role,
                      child: Text(_roleName(role)),
                    );
                  },
                ).toList(),
                onChanged: _isSaving
                    ? null
                    : (role) {
                  if (role == null) {
                    return;
                  }

                  setState(() {
                    _selectedRole = role;
                    _errorMessage = null;

                    if (role != UserRole.dataEntry) {
                      _selectedDistributorId = null;
                    }
                  });
                },
              ),

              const SizedBox(height: 14),

              TextField(
                controller: _codeController,
                enabled: !_isSaving,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'كود الدخول',
                  hintText: 'مثال: 3001',
                  prefixIcon: Icon(Icons.qr_code),
                  border: OutlineInputBorder(),
                ),
              ),

              if (!_isDataEntry) ...[
                const SizedBox(height: 14),

                TextField(
                  controller: _nameController,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                    labelText: 'اسم المستخدم',
                    prefixIcon: Icon(
                      Icons.person_outline,
                    ),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              if (!widget.isEditing) ...[
                const SizedBox(height: 14),

                TextField(
                  controller: _passwordController,
                  enabled: !_isSaving,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                    ),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: _isSaving
                          ? null
                          : () {
                        setState(() {
                          _obscurePassword =
                          !_obscurePassword;
                        });
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                    ),
                  ),
                ),
              ],

              if (_isDataEntry) ...[
                const SizedBox(height: 14),

                DropdownButtonFormField<String>(
                  initialValue:
                  _selectedDistributorId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'الموزع المرتبط بالكود',
                    prefixIcon: Icon(
                      Icons.account_tree,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  items: distributors.map(
                        (distributor) {
                      return DropdownMenuItem<String>(
                        value: distributor.id,
                        child: Text(
                          '${distributor.name} - ${distributor.code}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ).toList(),
                  onChanged: _isSaving
                      ? null
                      : (value) {
                    setState(() {
                      _selectedDistributorId = value;
                      _errorMessage = null;
                    });
                  },
                ),

                const SizedBox(height: 10),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context)
                          .dividerColor,
                    ),
                    borderRadius:
                    BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'سيتم ربط كود الدخول بالموزع المختار. '
                        'اسم الشخص الذي يقوم بالتسجيل سيُكتب '
                        'داخل شاشة إدخال الأحمال عند كل قراءة.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              if (widget.isEditing) ...[
                const SizedBox(height: 12),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('الحساب نشط'),
                  subtitle: Text(
                    _active
                        ? 'يمكن استخدام كود الدخول.'
                        : 'الحساب موقوف ولا يمكن استخدامه.',
                  ),
                  value: _active,
                  onChanged: _isSaving
                      ? null
                      : (value) {
                    setState(() {
                      _active = value;
                    });
                  },
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .errorContainer,
                    borderRadius:
                    BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onErrorContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving
              ? null
              : () {
            Navigator.pop(context, false);
          },
          child: const Text('إلغاء'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          )
              : const Icon(Icons.save),
          label: Text(
            _isSaving
                ? 'جارٍ الحفظ...'
                : widget.isEditing
                ? 'حفظ التعديل'
                : 'إنشاء الحساب',
          ),
        ),
      ],
    );
  }
}