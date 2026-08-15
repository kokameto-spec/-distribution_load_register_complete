import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/audit_log_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../models/audit_log.dart';
import '../../models/user_role.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({
    super.key,
  });

  @override
  State<AuditLogsScreen> createState() =>
      _AuditLogsScreenState();
}

class _AuditLogsScreenState
    extends State<AuditLogsScreen> {
  final TextEditingController
      _codeController =
      TextEditingController();

  String? _selectedAction;
  DateTime? _fromDate;
  DateTime? _toDate;

  static const Map<String, String>
      _actionNames =
      <String, String>{
    'create_user':
        'إنشاء مستخدم',
    'update_user':
        'تعديل مستخدم',
    'change_user_password':
        'تغيير كلمة المرور',
    'activate_user':
        'تفعيل مستخدم',
    'deactivate_user':
        'إيقاف مستخدم',
    'delete_user':
        'حذف مستخدم',
    'save_report':
        'حفظ تقرير',
    'update_report':
        'تعديل تقرير',
    'delete_report':
        'حذف تقرير',
    'print_report':
        'طباعة تقرير',
    'share_report':
        'مشاركة تقرير',
    'export_excel':
        'تصدير Excel',
    'create_distributor':
        'إنشاء موزع',
    'update_distributor':
        'تعديل موزع',
    'delete_distributor':
        'حذف موزع',
    'activate_distributor':
        'تفعيل موزع',
    'deactivate_distributor':
        'إيقاف موزع',
    'create_station':
        'إنشاء محطة',
    'update_station':
        'تعديل محطة',
    'delete_station':
        'حذف محطة',
    'create_load_record':
        'تسجيل أحمال',
    'save_load_record':
        'تسجيل أحمال',
    'update_load_record':
        'تعديل سجل أحمال',
    'delete_load_record':
        'حذف سجل أحمال',
    'login':
        'تسجيل دخول',
    'logout':
        'تسجيل خروج',
  };

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (!mounted) {
          return;
        }

        final controller =
            context.read<
                AuditLogController>();

        if (!controller.isListening &&
            !controller.isSearchMode) {
          controller.startListening();
        }
      },
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  bool get _isPresident {
    final user =
        context
            .read<AuthController>()
            .currentUser;

    return user?.role ==
        UserRole.president;
  }

  // =========================================================
  // DATES
  // =========================================================

  Future<void>
      _selectFromDate() async {
    final selected =
        await showDatePicker(
      context: context,
      initialDate:
          _fromDate ??
          DateTime.now(),
      firstDate:
          DateTime(2020),
      lastDate:
          DateTime.now(),
    );

    if (selected == null ||
        !mounted) {
      return;
    }

    setState(() {
      _fromDate =
          DateTime(
        selected.year,
        selected.month,
        selected.day,
      );

      if (_toDate != null &&
          _fromDate!.isAfter(
            _toDate!,
          )) {
        _toDate =
            DateTime(
          selected.year,
          selected.month,
          selected.day,
          23,
          59,
          59,
          999,
        );
      }
    });
  }

  Future<void>
      _selectToDate() async {
    final selected =
        await showDatePicker(
      context: context,
      initialDate:
          _toDate ??
          _fromDate ??
          DateTime.now(),
      firstDate:
          _fromDate ??
          DateTime(2020),
      lastDate:
          DateTime.now(),
    );

    if (selected == null ||
        !mounted) {
      return;
    }

    setState(() {
      _toDate =
          DateTime(
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

  // =========================================================
  // SEARCH
  // =========================================================

  Future<void> _search() async {
    if (_fromDate != null &&
        _toDate != null &&
        _fromDate!.isAfter(
          _toDate!,
        )) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'تاريخ البداية يجب أن يسبق تاريخ النهاية.',
          ),
        ),
      );

      return;
    }

    await context
        .read<AuditLogController>()
        .search(
          action:
              _selectedAction,
          targetCode:
              _codeController.text,
          fromDate:
              _fromDate,
          toDate:
              _toDate,
        );
  }

  Future<void>
      _clearSearch() async {
    _codeController.clear();

    setState(() {
      _selectedAction = null;
      _fromDate = null;
      _toDate = null;
    });

    await context
        .read<AuditLogController>()
        .clearSearch();
  }

  Future<void> _refresh() async {
    final controller =
        context.read<
            AuditLogController>();

    if (controller.isSearchMode) {
      await controller.search(
        action:
            _selectedAction,
        targetCode:
            _codeController.text,
        fromDate:
            _fromDate,
        toDate:
            _toDate,
      );
    } else {
      await controller.refresh();
    }
  }

  // =========================================================
  // EDIT
  // =========================================================

  Future<void> _editLog(
    AuditLog log,
  ) async {
    if (!_isPresident) {
      return;
    }

    var action =
        log.action;

    final codeController =
        TextEditingController(
      text: log.targetCode,
    );

    final noteController =
        TextEditingController(
      text:
          (log.details[
                      'manualNote'] ??
                  log.details[
                      'note'] ??
                  '')
              .toString(),
    );

    final result =
        await showDialog<
            _AuditEditResult>(
      context: context,
      barrierDismissible:
          false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder:
              (
            context,
            setDialogState,
          ) {
            return AlertDialog(
              title:
                  const Text(
                'تعديل سجل العملية',
              ),
              content:
                  SizedBox(
                width: 520,
                child:
                    SingleChildScrollView(
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<
                          String>(
                        value:
                            _actionNames
                                    .containsKey(
                                      action,
                                    )
                                ? action
                                : null,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'نوع العملية',
                          border:
                              OutlineInputBorder(),
                        ),
                        items:
                            _actionNames
                                .entries
                                .map(
                          (
                            entry,
                          ) {
                            return DropdownMenuItem<
                                String>(
                              value:
                                  entry.key,
                              child:
                                  Text(
                                entry.value,
                              ),
                            );
                          },
                        ).toList(),
                        onChanged:
                            (
                          value,
                        ) {
                          if (value ==
                              null) {
                            return;
                          }

                          setDialogState(
                            () {
                              action =
                                  value;
                            },
                          );
                        },
                      ),
                      const SizedBox(
                        height: 14,
                      ),
                      TextField(
                        controller:
                            codeController,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'كود المستخدم المستهدف',
                          border:
                              OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(
                        height: 14,
                      ),
                      TextField(
                        controller:
                            noteController,
                        minLines: 3,
                        maxLines: 6,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'ملاحظة / وصف',
                          border:
                              OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Text(
                        'تاريخ العملية الأصلي لن يتم تغييره.',
                        style:
                            Theme.of(
                          context,
                        )
                                .textTheme
                                .bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child:
                      const Text(
                    'إلغاء',
                  ),
                ),
                FilledButton.icon(
                  onPressed:
                      () {
                    Navigator.pop(
                      dialogContext,
                      _AuditEditResult(
                        action:
                            action,
                        targetCode:
                            codeController
                                .text
                                .trim(),
                        note:
                            noteController
                                .text
                                .trim(),
                      ),
                    );
                  },
                  icon:
                      const Icon(
                    Icons.save,
                  ),
                  label:
                      const Text(
                    'حفظ التعديل',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    codeController.dispose();
    noteController.dispose();

    if (result == null ||
        !mounted) {
      return;
    }

    final details =
        Map<String, dynamic>.from(
      log.details,
    );

    details['manualNote'] =
        result.note;

    details['editedManually'] =
        true;

    details['editedAt'] =
        DateTime.now()
            .toIso8601String();

    final success =
        await context
            .read<
                AuditLogController>()
            .updateLog(
              original: log,
              action:
                  result.action,
              targetCode:
                  result.targetCode,
              details:
                  details,
            );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'تم تعديل سجل العملية.'
              : context
                      .read<
                          AuditLogController>()
                      .errorMessage ??
                  'تعذر تعديل السجل.',
        ),
      ),
    );
  }

  // =========================================================
  // DELETE
  // =========================================================

  Future<void> _deleteLog(
    AuditLog log,
  ) async {
    if (!_isPresident) {
      return;
    }

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (
        dialogContext,
      ) {
        return AlertDialog(
          title:
              const Text(
            'حذف سجل العملية',
          ),
          content:
              Text(
            'هل تريد حذف العملية '
            '«${log.actionName}» نهائيًا؟\n\n'
            'لا يمكن التراجع بعد الحذف.',
          ),
          actions: [
            TextButton(
              onPressed:
                  () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child:
                  const Text(
                'إلغاء',
              ),
            ),
            FilledButton.icon(
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    Theme.of(
                  context,
                )
                        .colorScheme
                        .error,
              ),
              onPressed:
                  () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              icon:
                  const Icon(
                Icons.delete_forever,
              ),
              label:
                  const Text(
                'حذف نهائي',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !mounted) {
      return;
    }

    final success =
        await context
            .read<
                AuditLogController>()
            .deleteLog(
              log,
            );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'تم حذف سجل العملية.'
              : context
                      .read<
                          AuditLogController>()
                      .errorMessage ??
                  'تعذر حذف السجل.',
        ),
      ),
    );
  }

  // =========================================================
  // FORMAT
  // =========================================================

  String _formatDate(
    DateTime? value,
  ) {
    if (value == null) {
      return 'غير محدد';
    }

    return DateFormat(
      'yyyy/MM/dd',
      'ar',
    ).format(value);
  }

  String _formatDateTime(
    DateTime value,
  ) {
    return DateFormat(
      'yyyy/MM/dd - HH:mm:ss',
      'ar',
    ).format(value);
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final controller =
        context.watch<
            AuditLogController>();

    final user =
        context.watch<
            AuthController>()
            .currentUser;

    final canManage =
        user?.role ==
        UserRole.president;

    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'سجل العمليات',
        ),
      ),
      body: RefreshIndicator(
        onRefresh:
            _refresh,
        child:
            CustomScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  16,
                ),
                child:
                    Center(
                  child:
                      ConstrainedBox(
                    constraints:
                        const BoxConstraints(
                      maxWidth:
                          1100,
                    ),
                    child:
                        _buildSearchCard(
                      controller,
                    ),
                  ),
                ),
              ),
            ),

            if (controller.isLoading &&
                controller.logs.isEmpty)
              const SliverFillRemaining(
                hasScrollBody:
                    false,
                child:
                    Center(
                  child:
                      CircularProgressIndicator(),
                ),
              )
            else if (controller.logs.isEmpty)
              const SliverFillRemaining(
                hasScrollBody:
                    false,
                child:
                    Center(
                  child:
                      Text(
                    'لا توجد عمليات مسجلة.',
                  ),
                ),
              )
            else
              SliverPadding(
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  30,
                ),
                sliver:
                    SliverList.separated(
                  itemCount:
                      controller.logs.length,
                  separatorBuilder:
                      (
                    _,
                    __,
                  ) =>
                          const SizedBox(
                    height: 10,
                  ),
                  itemBuilder:
                      (
                    context,
                    index,
                  ) {
                    final log =
                        controller.logs[
                            index];

                    return Center(
                      child:
                          ConstrainedBox(
                        constraints:
                            const BoxConstraints(
                          maxWidth:
                              1100,
                        ),
                        child:
                            _AuditLogCard(
                          log:
                              log,
                          formattedDate:
                              _formatDateTime(
                            log.createdAt,
                          ),
                          canManage:
                              canManage,
                          onEdit:
                              () =>
                                  _editLog(
                            log,
                          ),
                          onDelete:
                              () =>
                                  _deleteLog(
                            log,
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
        padding:
            const EdgeInsets.all(
          16,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            Text(
              'البحث في سجل العمليات',
              style:
                  Theme.of(
                context,
              )
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight:
                            FontWeight.bold,
                      ),
            ),
            const SizedBox(
              height: 16,
            ),
            TextField(
              controller:
                  _codeController,
              enabled:
                  !controller.isLoading,
              decoration:
                  const InputDecoration(
                labelText:
                    'كود المستخدم المستهدف',
                prefixIcon:
                    Icon(
                  Icons.qr_code,
                ),
                border:
                    OutlineInputBorder(),
              ),
            ),
            const SizedBox(
              height: 14,
            ),
            DropdownButtonFormField<
                String>(
              value:
                  _selectedAction,
              decoration:
                  const InputDecoration(
                labelText:
                    'نوع العملية',
                prefixIcon:
                    Icon(
                  Icons.filter_alt,
                ),
                border:
                    OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<
                    String>(
                  value: null,
                  child:
                      Text(
                    'جميع العمليات',
                  ),
                ),
                ..._actionNames.entries
                    .map(
                  (
                    entry,
                  ) {
                    return DropdownMenuItem<
                        String>(
                      value:
                          entry.key,
                      child:
                          Text(
                        entry.value,
                      ),
                    );
                  },
                ),
              ],
              onChanged:
                  controller.isLoading
                      ? null
                      : (
                        value,
                      ) {
                          setState(
                            () {
                              _selectedAction =
                                  value;
                            },
                          );
                        },
            ),
            const SizedBox(
              height: 14,
            ),
            LayoutBuilder(
              builder:
                  (
                context,
                constraints,
              ) {
                final width =
                    constraints.maxWidth >=
                            600
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
                      child:
                          _DateButton(
                        title:
                            'من تاريخ',
                        value:
                            _formatDate(
                          _fromDate,
                        ),
                        onPressed:
                            controller.isLoading
                                ? null
                                : _selectFromDate,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child:
                          _DateButton(
                        title:
                            'إلى تاريخ',
                        value:
                            _formatDate(
                          _toDate,
                        ),
                        onPressed:
                            controller.isLoading
                                ? null
                                : _selectToDate,
                      ),
                    ),
                  ],
                );
              },
            ),
            if (controller.errorMessage !=
                null) ...[
              const SizedBox(
                height: 12,
              ),
              Text(
                controller.errorMessage!,
                style:
                    TextStyle(
                  color:
                      Theme.of(
                    context,
                  ).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(
              height: 16,
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment:
                  WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      controller.isLoading
                          ? null
                          : _clearSearch,
                  icon:
                      const Icon(
                    Icons.clear,
                  ),
                  label:
                      const Text(
                    'مسح البحث',
                  ),
                ),
                FilledButton.icon(
                  onPressed:
                      controller.isLoading
                          ? null
                          : _search,
                  icon:
                      const Icon(
                    Icons.search,
                  ),
                  label:
                      const Text(
                    'بحث',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// CARD
// ===========================================================

class _AuditLogCard
    extends StatelessWidget {
  const _AuditLogCard({
    required this.log,
    required this.formattedDate,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  final AuditLog log;
  final String formattedDate;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      child: ExpansionTile(
        leading:
            const CircleAvatar(
          child:
              Icon(
            Icons.history,
          ),
        ),
        title:
            Text(
          log.actionName,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        subtitle:
            Text(
          '$formattedDate'
          '${log.targetCode.trim().isEmpty ? '' : '  |  ${log.targetCode}'}',
        ),
        trailing:
            canManage
                ? Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip:
                            'تعديل',
                        onPressed:
                            onEdit,
                        icon:
                            const Icon(
                          Icons.edit,
                        ),
                      ),
                      IconButton(
                        tooltip:
                            'حذف',
                        onPressed:
                            onDelete,
                        icon:
                            const Icon(
                          Icons.delete_outline,
                        ),
                      ),
                    ],
                  )
                : null,
        childrenPadding:
            const EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16,
        ),
        children: [
          _InfoRow(
            title:
                'نوع العملية',
            value:
                log.actionName,
          ),
          _InfoRow(
            title:
                'كود المستهدف',
            value:
                log.targetCode
                        .trim()
                        .isEmpty
                    ? '—'
                    : log.targetCode,
          ),
          _InfoRow(
            title:
                'وقت العملية',
            value:
                formattedDate,
          ),
          _InfoRow(
            title:
                'UID المنفذ',
            value:
                log.performedByUid
                        .trim()
                        .isEmpty
                    ? '—'
                    : log.performedByUid,
          ),
          if (log.details.isNotEmpty) ...[
            const Divider(),
            Align(
              alignment:
                  Alignment.centerRight,
              child:
                  Text(
                'التفاصيل',
                style:
                    Theme.of(
                  context,
                )
                        .textTheme
                        .titleSmall
                        ?.copyWith(
                          fontWeight:
                              FontWeight.bold,
                        ),
              ),
            ),
            const SizedBox(
              height: 6,
            ),
            for (final entry
                in log.details.entries)
              _InfoRow(
                title:
                    entry.key,
                value:
                    entry.value
                        .toString(),
              ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow
    extends StatelessWidget {
  const _InfoRow({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 3,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              title,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateButton
    extends StatelessWidget {
  const _DateButton({
    required this.title,
    required this.value,
    required this.onPressed,
  });

  final String title;
  final String value;
  final VoidCallback? onPressed;

  @override
  Widget build(
    BuildContext context,
  ) {
    return OutlinedButton.icon(
      onPressed:
          onPressed,
      icon:
          const Icon(
        Icons.calendar_month,
      ),
      label: Padding(
        padding:
            const EdgeInsets.symmetric(
          vertical: 12,
        ),
        child: Column(
          children: [
            Text(
              title,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 2,
            ),
            Text(value),
          ],
        ),
      ),
    );
  }
}

class _AuditEditResult {
  const _AuditEditResult({
    required this.action,
    required this.targetCode,
    required this.note,
  });

  final String action;
  final String targetCode;
  final String note;
}
