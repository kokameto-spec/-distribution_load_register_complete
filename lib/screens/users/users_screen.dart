import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/distributor_controller.dart';
import '../../controllers/user_management_controller.dart';
import '../../models/app_user.dart';
import '../../models/user_role.dart';
import 'user_form_dialog.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() =>
      _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final TextEditingController _searchController =
  TextEditingController();

  String _searchText = '';
  UserRole? _roleFilter;
  bool _showActiveOnly = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final users =
      context.read<UserManagementController>();

      final distributors =
      context.read<DistributorController>();

      if (!users.isListening) {
        users.startListening();
      }

      if (!distributors.isListening) {
        distributors.startListening();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _roleName(UserRole role) {
    switch (role) {
      case UserRole.president:
        return 'الرئيس';

      case UserRole.manager:
        return 'مدير / مشغل';

      case UserRole.dataEntry:
        return 'مدخل بيانات';
    }
  }

  List<AppUser> _filteredUsers(
      List<AppUser> users,
      ) {
    final search = _searchText.trim().toLowerCase();

    return users.where((user) {
      if (_showActiveOnly && !user.active) {
        return false;
      }

      if (_roleFilter != null &&
          user.role != _roleFilter) {
        return false;
      }

      if (search.isEmpty) {
        return true;
      }

      return user.displayName
          .toLowerCase()
          .contains(search) ||
          user.code.toLowerCase().contains(search) ||
          (user.distributorName ?? '')
              .toLowerCase()
              .contains(search);
    }).toList(growable: false);
  }

  Future<void> _openCreateDialog() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const UserFormDialog();
      },
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم إنشاء المستخدم بنجاح.',
          ),
        ),
      );
    }
  }

  Future<void> _openEditDialog(
      AppUser user,
      ) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return UserFormDialog(
          user: user,
        );
      },
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم تعديل المستخدم بنجاح.',
          ),
        ),
      );
    }
  }

  Future<void> _changePassword(
      AppUser user,
      ) async {
    final passwordController =
    TextEditingController();

    bool obscure = true;
    String? errorMessage;
    bool saving = false;

    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> savePassword() async {
              final password =
                  passwordController.text;

              if (password.length < 6) {
                setDialogState(() {
                  errorMessage =
                  'كلمة المرور يجب ألا تقل عن 6 أحرف أو أرقام.';
                });
                return;
              }

              setDialogState(() {
                saving = true;
                errorMessage = null;
              });

              final success = await context
                  .read<UserManagementController>()
                  .changePassword(
                uid: user.uid,
                password: password,
              );

              if (!dialogContext.mounted) {
                return;
              }

              if (success) {
                Navigator.pop(dialogContext, true);
                return;
              }

              setDialogState(() {
                saving = false;
                errorMessage = context
                    .read<UserManagementController>()
                    .errorMessage ??
                    'تعذر تغيير كلمة المرور.';
              });
            }

            return AlertDialog(
              title: const Text(
                'تغيير كلمة المرور',
              ),
              content: SizedBox(
                width: 430,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'المستخدم: ${user.displayName}',
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller: passwordController,
                      obscureText: obscure,
                      enabled: !saving,
                      decoration: InputDecoration(
                        labelText:
                        'كلمة المرور الجديدة',
                        prefixIcon:
                        const Icon(Icons.lock_outline),
                        border:
                        const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: saving
                              ? null
                              : () {
                            setDialogState(() {
                              obscure = !obscure;
                            });
                          },
                          icon: Icon(
                            obscure
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),

                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                    Navigator.pop(
                      dialogContext,
                      false,
                    );
                  },
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed:
                  saving ? null : savePassword,
                  child: saving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : const Text('تغيير'),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();

    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم تغيير كلمة المرور بنجاح.',
          ),
        ),
      );
    }
  }

  Future<void> _deleteUser(
      AppUser user,
      ) async {
    final currentUid = context
        .read<AuthController>()
        .currentUser
        ?.uid;

    if (currentUid == user.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لا يمكنك حذف حسابك الحالي.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('حذف المستخدم'),
          content: Text(
            'هل تريد حذف المستخدم '
                '"${user.displayName}"؟\n\n'
                'سيتم حذف حساب الدخول وبياناته نهائيًا.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor:
                Theme.of(context).colorScheme.error,
                foregroundColor:
                Theme.of(context).colorScheme.onError,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              icon: const Icon(Icons.delete_forever),
              label: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final controller =
    context.read<UserManagementController>();

    final success =
    await controller.deleteUser(user.uid);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'تم حذف المستخدم.'
              : controller.errorMessage ??
              'تعذر حذف المستخدم.',
        ),
      ),
    );
  }

  Future<void> _setActive(
      AppUser user,
      bool active,
      ) async {
    final currentUid = context
        .read<AuthController>()
        .currentUser
        ?.uid;

    if (currentUid == user.uid && !active) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لا يمكنك إيقاف حسابك الحالي.',
          ),
        ),
      );
      return;
    }

    final controller =
    context.read<UserManagementController>();

    final success = await controller.setActive(
      uid: user.uid,
      active: active,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            controller.errorMessage ??
                'تعذر تغيير حالة المستخدم.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller =
    context.watch<UserManagementController>();

    final filteredUsers =
    _filteredUsers(controller.users);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المستخدمين'),
        actions: [
          IconButton(
            tooltip: 'إضافة مستخدم',
            onPressed: controller.isLoading
                ? null
                : _openCreateDialog,
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      floatingActionButton:
      FloatingActionButton.extended(
        onPressed: controller.isLoading
            ? null
            : _openCreateDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('إضافة مستخدم'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await controller.stopListening();
          await controller.startListening();
        },
        child: CustomScrollView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 1100,
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller:
                          _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchText = value;
                            });
                          },
                          decoration: InputDecoration(
                            labelText:
                            'البحث بالاسم أو الكود أو الموزع',
                            prefixIcon:
                            const Icon(Icons.search),
                            border:
                            const OutlineInputBorder(),
                            suffixIcon:
                            _searchText.isEmpty
                                ? null
                                : IconButton(
                              onPressed: () {
                                _searchController
                                    .clear();

                                setState(() {
                                  _searchText = '';
                                });
                              },
                              icon: const Icon(
                                Icons.clear,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        DropdownButtonFormField<UserRole?>(
                          initialValue: _roleFilter,
                          decoration: const InputDecoration(
                            labelText: 'تصفية حسب الصلاحية',
                            prefixIcon: Icon(
                              Icons.filter_alt_outlined,
                            ),
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<UserRole?>(
                              value: null,
                              child: Text(
                                'جميع الصلاحيات',
                              ),
                            ),
                            ...UserRole.values.map(
                                  (role) {
                                return DropdownMenuItem<
                                    UserRole?>(
                                  value: role,
                                  child: Text(
                                    _roleName(role),
                                  ),
                                );
                              },
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _roleFilter = value;
                            });
                          },
                        ),

                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'عرض الحسابات النشطة فقط',
                          ),
                          value: _showActiveOnly,
                          onChanged: (value) {
                            setState(() {
                              _showActiveOnly =
                                  value ?? false;
                            });
                          },
                        ),

                        if (controller.errorMessage != null)
                          Container(
                            width: double.infinity,
                            padding:
                            const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .errorContainer,
                              borderRadius:
                              BorderRadius.circular(8),
                            ),
                            child: Text(
                              controller.errorMessage!,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            if (controller.isLoading &&
                controller.users.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (filteredUsers.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.people_outline,
                          size: 72,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          controller.users.isEmpty
                              ? 'لا يوجد مستخدمون.'
                              : 'لا توجد نتائج مطابقة.',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  100,
                ),
                sliver: SliverList.separated(
                  itemCount: filteredUsers.length,
                  separatorBuilder: (_, __) {
                    return const SizedBox(height: 10);
                  },
                  itemBuilder: (context, index) {
                    final user =
                    filteredUsers[index];

                    return Center(
                      child: ConstrainedBox(
                        constraints:
                        const BoxConstraints(
                          maxWidth: 1100,
                        ),
                        child: _UserCard(
                          user: user,
                          roleName:
                          _roleName(user.role),
                          onEdit: () {
                            _openEditDialog(user);
                          },
                          onChangePassword: () {
                            _changePassword(user);
                          },
                          onDelete: () {
                            _deleteUser(user);
                          },
                          onActiveChanged: (value) {
                            _setActive(
                              user,
                              value,
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.roleName,
    required this.onEdit,
    required this.onChangePassword,
    required this.onDelete,
    required this.onActiveChanged,
  });

  final AppUser user;
  final String roleName;
  final VoidCallback onEdit;
  final VoidCallback onChangePassword;
  final VoidCallback onDelete;
  final ValueChanged<bool> onActiveChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Icon(
                    user.isPresident
                        ? Icons.admin_panel_settings
                        : user.isManager
                        ? Icons.supervisor_account
                        : Icons.person,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'الكود: ${user.code}',
                      ),
                    ],
                  ),
                ),

                Chip(
                  label: Text(roleName),
                ),

                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit();
                        break;

                      case 'password':
                        onChangePassword();
                        break;

                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (_) {
                    return const [
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('تعديل'),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'password',
                        child: ListTile(
                          leading: Icon(
                            Icons.password,
                          ),
                          title: Text(
                            'تغيير كلمة المرور',
                          ),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(
                            Icons.delete_outline,
                          ),
                          title: Text('حذف'),
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),

            const Divider(height: 24),

            if (user.isDataEntry)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                const Icon(Icons.account_tree),
                title: const Text(
                  'الموزع المرتبط',
                ),
                subtitle: Text(
                  user.distributorName?.trim().isNotEmpty ==
                      true
                      ? user.distributorName!
                      : 'غير مرتبط بموزع',
                ),
              ),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                user.active
                    ? 'الحساب نشط'
                    : 'الحساب موقوف',
              ),
              subtitle: Text(
                user.active
                    ? 'يمكن للمستخدم تسجيل الدخول.'
                    : 'لا يمكن للمستخدم تسجيل الدخول.',
              ),
              value: user.active,
              onChanged: onActiveChanged,
            ),
          ],
        ),
      ),
    );
  }
}