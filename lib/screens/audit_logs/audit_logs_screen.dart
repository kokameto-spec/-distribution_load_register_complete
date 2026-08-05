import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/audit_log_controller.dart';
import '../../models/audit_log.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() =>
      _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final TextEditingController _codeController =
  TextEditingController();

  String? _selectedAction;
  DateTime? _fromDate;
  DateTime? _toDate;

  static const Map<String, String> _actionNames =
  <String, String>{
    'create_user': 'إنشاء مستخدم',
    'update_user': 'تعديل مستخدم',
    'change_user_password': 'تغيير كلمة المرور',
    'activate_user': 'تفعيل مستخدم',
    'deactivate_user': 'إيقاف مستخدم',
    'delete_user': 'حذف مستخدم',
  };

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final controller =
      context.read<AuditLogController>();

      if (!controller.isListening) {
        controller.startListening();
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _selectFromDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _fromDate = DateTime(
        selected.year,
        selected.month,
        selected.day,
      );
    });
  }

  Future<void> _selectToDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: _fromDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _toDate = DateTime(
        selected.year,
        selected.month,
        selected.day,
        23,
        59,
        59,
        999,
      );
    });
  }

  Future<void> _search() async {
    if (_fromDate != null &&
        _toDate != null &&
        _fromDate!.isAfter(_toDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تاريخ البداية يجب أن يسبق تاريخ النهاية.',
          ),
        ),
      );
      return;
    }

    await context.read<AuditLogController>().search(
      action: _selectedAction,
      targetCode: _codeController.text,
      fromDate: _fromDate,
      toDate: _toDate,
    );
  }

  Future<void> _clearSearch() async {
    _codeController.clear();

    setState(() {
      _selectedAction = null;
      _fromDate = null;
      _toDate = null;
    });

    await context
        .read<AuditLogController>()
        .startListening();
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return 'غير محدد';
    }

    return DateFormat(
      'yyyy/MM/dd',
      'ar',
    ).format(value);
  }

  String _formatDateTime(DateTime value) {
    return DateFormat(
      'yyyy/MM/dd - hh:mm:ss a',
      'ar',
    ).format(value);
  }

  @override
  Widget build(BuildContext context) {
    final controller =
    context.watch<AuditLogController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل العمليات'),
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
                    child: _buildSearchCard(
                      controller,
                    ),
                  ),
                ),
              ),
            ),
            if (controller.isLoading &&
                controller.logs.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (controller.logs.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 72,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'لا توجد عمليات مسجلة.',
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
                  30,
                ),
                sliver: SliverList.separated(
                  itemCount: controller.logs.length,
                  separatorBuilder: (_, __) {
                    return const SizedBox(height: 10);
                  },
                  itemBuilder: (context, index) {
                    final log =
                    controller.logs[index];

                    return Center(
                      child: ConstrainedBox(
                        constraints:
                        const BoxConstraints(
                          maxWidth: 1100,
                        ),
                        child: _AuditLogCard(
                          log: log,
                          formattedDate:
                          _formatDateTime(
                            log.createdAt,
                          ),
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

  Widget _buildSearchCard(
      AuditLogController controller,
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.stretch,
          children: [
            Text(
              'البحث في سجل العمليات',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText:
                'كود المستخدم المستهدف',
                prefixIcon: Icon(Icons.qr_code),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _selectedAction,
              decoration: const InputDecoration(
                labelText: 'نوع العملية',
                prefixIcon:
                Icon(Icons.filter_alt),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text(
                    'جميع العمليات',
                  ),
                ),
                ..._actionNames.entries.map(
                      (entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  },
                ),
              ],
              onChanged: controller.isLoading
                  ? null
                  : (value) {
                setState(() {
                  _selectedAction = value;
                });
              },
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final width =
                constraints.maxWidth >= 600
                    ? (constraints.maxWidth -
                    12) /
                    2
                    : constraints.maxWidth;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: width,
                      child: _DateButton(
                        title: 'من تاريخ',
                        value:
                        _formatDate(_fromDate),
                        onPressed:
                        _selectFromDate,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _DateButton(
                        title: 'إلى تاريخ',
                        value:
                        _formatDate(_toDate),
                        onPressed: _selectToDate,
                      ),
                    ),
                  ],
                );
              },
            ),
            if (controller.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
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
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: controller.isLoading
                      ? null
                      : _clearSearch,
                  icon: const Icon(Icons.clear),
                  label:
                  const Text('مسح البحث'),
                ),
                FilledButton.icon(
                  onPressed: controller.isLoading
                      ? null
                      : _search,
                  icon:
                  const Icon(Icons.search),
                  label: const Text('بحث'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditLogCard extends StatelessWidget {
  const _AuditLogCard({
    required this.log,
    required this.formattedDate,
  });

  final AuditLog log;
  final String formattedDate;

  @override
  Widget build(BuildContext context) {
    final name =
    (log.details['name'] ?? '').toString();

    final role =
    (log.details['role'] ?? '').toString();

    final distributorName =
    (log.details['distributorName'] ?? '')
        .toString();

    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          child: Icon(
            _iconForAction(log.action),
          ),
        ),
        title: Text(
          log.actionName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'الكود: '
              '${log.targetCode.isEmpty ? 'غير متوفر' : log.targetCode}'
              '\n$formattedDate',
        ),
        childrenPadding:
        const EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16,
        ),
        children: [
          _InformationRow(
            title: 'معرف منفذ العملية',
            value: log.performedByUid,
          ),
          _InformationRow(
            title: 'معرف المستخدم',
            value: log.targetUid,
          ),
          if (name.isNotEmpty)
            _InformationRow(
              title: 'اسم المستخدم',
              value: name,
            ),
          if (role.isNotEmpty)
            _InformationRow(
              title: 'الصلاحية',
              value: role,
            ),
          if (distributorName.isNotEmpty)
            _InformationRow(
              title: 'الموزع',
              value: distributorName,
            ),
          _InformationRow(
            title: 'التاريخ والوقت',
            value: formattedDate,
          ),
        ],
      ),
    );
  }

  IconData _iconForAction(String action) {
    switch (action) {
      case 'create_user':
        return Icons.person_add;

      case 'update_user':
        return Icons.edit;

      case 'change_user_password':
        return Icons.password;

      case 'activate_user':
        return Icons.person_add_alt_1;

      case 'deactivate_user':
        return Icons.person_off;

      case 'delete_user':
        return Icons.delete_forever;

      default:
        return Icons.history;
    }
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.title,
    required this.value,
    required this.onPressed,
  });

  final String title;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.centerRight,
      ),
      child: Row(
        children: [
          const Icon(Icons.date_range),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall,
                ),
                const SizedBox(height: 3),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value.isEmpty
                  ? 'غير متوفر'
                  : value,
            ),
          ),
        ],
      ),
    );
  }
}