import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/distributor_controller.dart';
import '../../models/distributor_model.dart';
import 'distributor_form_dialog.dart';

class DistributorsScreen extends StatefulWidget {
  const DistributorsScreen({super.key});

  @override
  State<DistributorsScreen> createState() =>
      _DistributorsScreenState();
}

class _DistributorsScreenState extends State<DistributorsScreen> {
  final TextEditingController _searchController =
  TextEditingController();

  String _searchText = '';
  bool _showActiveOnly = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final controller = context.read<DistributorController>();

      if (!controller.isListening) {
        controller.startListening();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openCreateDialog() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const DistributorFormDialog();
      },
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمت إضافة الموزع بنجاح.'),
        ),
      );
    }
  }

  Future<void> _openEditDialog(
      Distributor distributor,
      ) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return DistributorFormDialog(
          distributor: distributor,
        );
      },
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تعديل بيانات الموزع بنجاح.'),
        ),
      );
    }
  }

  Future<void> _deleteDistributor(
      Distributor distributor,
      ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('حذف الموزع'),
          content: Text(
            'هل تريد حذف الموزع "${distributor.name}"؟\n\n'
                'لا يمكن التراجع عن هذه العملية.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
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
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.delete_forever),
              label: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    final controller =
    context.read<DistributorController>();

    final success = await controller.delete(
      distributor.id,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حذف الموزع.'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            controller.errorMessage ??
                'تعذر حذف الموزع.',
          ),
        ),
      );
    }
  }

  Future<void> _changeActiveState(
      Distributor distributor,
      bool value,
      ) async {
    final controller =
    context.read<DistributorController>();

    final success = await controller.update(
      id: distributor.id,
      code: distributor.code,
      name: distributor.name,
      type: distributor.type,
      active: value,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            controller.errorMessage ??
                'تعذر تغيير حالة الموزع.',
          ),
        ),
      );
    }
  }

  List<Distributor> _filterDistributors(
      List<Distributor> distributors,
      ) {
    final search = _searchText.trim().toLowerCase();

    return distributors.where((distributor) {
      if (_showActiveOnly && !distributor.active) {
        return false;
      }

      if (search.isEmpty) {
        return true;
      }

      return distributor.name
          .toLowerCase()
          .contains(search) ||
          distributor.code
              .toLowerCase()
              .contains(search) ||
          distributor.type
              .toLowerCase()
              .contains(search);
    }).toList(growable: false);
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'لم يسجل حتى الآن';
    }

    return DateFormat(
      'yyyy/MM/dd - hh:mm a',
      'ar',
    ).format(date);
  }

  @override
  Widget build(BuildContext context) {
    final controller =
    context.watch<DistributorController>();

    final filteredDistributors = _filterDistributors(
      controller.distributors,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الموزعات'),
        actions: [
          IconButton(
            tooltip: 'إضافة موزع',
            onPressed:
            controller.isLoading ? null : _openCreateDialog,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
        controller.isLoading ? null : _openCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('إضافة موزع'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await controller.stopListening();
          await controller.startListening();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchText = value;
                            });
                          },
                          decoration: InputDecoration(
                            labelText:
                            'البحث باسم أو كود أو نوع الموزع',
                            prefixIcon:
                            const Icon(Icons.search),
                            suffixIcon:
                            _searchText.isEmpty
                                ? null
                                : IconButton(
                              tooltip:
                              'مسح البحث',
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
                            border:
                            const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'عرض الموزعات النشطة فقط',
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
                            margin:
                            const EdgeInsets.only(top: 8),
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
                controller.distributors.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (filteredDistributors.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyDistributorsView(
                  hasSearch: _searchText.isNotEmpty ||
                      _showActiveOnly,
                  onAdd: _openCreateDialog,
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
                  itemCount: filteredDistributors.length,
                  separatorBuilder: (_, __) {
                    return const SizedBox(height: 10);
                  },
                  itemBuilder: (context, index) {
                    final distributor =
                    filteredDistributors[index];

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 1100,
                        ),
                        child: _DistributorCard(
                          distributor: distributor,
                          formattedLastRecord:
                          _formatDate(
                            distributor.lastRecordAt,
                          ),
                          onEdit: () {
                            _openEditDialog(distributor);
                          },
                          onDelete: () {
                            _deleteDistributor(distributor);
                          },
                          onActiveChanged: (value) {
                            _changeActiveState(
                              distributor,
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

class _DistributorCard extends StatelessWidget {
  const _DistributorCard({
    required this.distributor,
    required this.formattedLastRecord,
    required this.onEdit,
    required this.onDelete,
    required this.onActiveChanged,
  });

  final Distributor distributor;
  final String formattedLastRecord;
  final VoidCallback onEdit;
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
                  backgroundColor: distributor.active
                      ? Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      : Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  child: Icon(
                    distributor.active
                        ? Icons.electrical_services
                        : Icons.power_off,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        distributor.name,
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
                        'الكود: ${distributor.code}',
                      ),
                      const SizedBox(height: 2),
                      Text(
                        distributor.type.trim().isEmpty
                            ? 'النوع: غير محدد'
                            : 'النوع: ${distributor.type}',
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit();
                        break;

                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (_) {
                    return const [
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('تعديل'),
                        ),
                      ),
                      PopupMenuItem(
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
            Row(
              children: [
                Expanded(
                  child: _DistributorInformation(
                    icon: Icons.schedule,
                    title: 'آخر تسجيل',
                    value: formattedLastRecord,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DistributorInformation(
                    icon: Icons.bolt,
                    title: 'آخر حمل',
                    value: distributor.lastTotalLoad ==
                        null
                        ? 'لا توجد قراءة'
                        : '${distributor.lastTotalLoad!.toStringAsFixed(2)} أمبير',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                distributor.active
                    ? 'الموزع نشط'
                    : 'الموزع موقوف',
              ),
              value: distributor.active,
              onChanged: onActiveChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _DistributorInformation extends StatelessWidget {
  const _DistributorInformation({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
        ),
        const SizedBox(width: 8),
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
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyDistributorsView extends StatelessWidget {
  const _EmptyDistributorsView({
    required this.hasSearch,
    required this.onAdd,
  });

  final bool hasSearch;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasSearch
                  ? Icons.search_off
                  : Icons.account_tree_outlined,
              size: 70,
              color: Theme.of(context)
                  .colorScheme
                  .primary,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'لا توجد موزعات مطابقة للبحث.'
                  : 'لا توجد موزعات حتى الآن.',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
              textAlign: TextAlign.center,
            ),
            if (!hasSearch) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('إضافة أول موزع'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}