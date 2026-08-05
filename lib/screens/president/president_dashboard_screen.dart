import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_routes.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/distributor_controller.dart';
import '../../models/distributor_model.dart';

class PresidentDashboardScreen extends StatefulWidget {
  const PresidentDashboardScreen({super.key});

  @override
  State<PresidentDashboardScreen> createState() =>
      _PresidentDashboardScreenState();
}

class _PresidentDashboardScreenState
    extends State<PresidentDashboardScreen> {
  bool _startedListening = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_startedListening) {
      return;
    }

    _startedListening = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final distributorController =
      context.read<DistributorController>();

      if (!distributorController.isListening) {
        distributorController.startListening();
      }
    });
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('تسجيل الخروج'),
          content: const Text(
            'هل تريد تسجيل الخروج من البرنامج؟',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('تسجيل الخروج'),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !mounted) {
      return;
    }

    await context
        .read<DistributorController>()
        .stopListening();

    if (!mounted) {
      return;
    }

    await context.read<AuthController>().logout();

    if (!mounted) {
      return;
    }

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
          (route) => false,
    );
  }

  void _openDistributors() {
    Navigator.pushNamed(
      context,
      AppRoutes.distributors,
    );
  }

  void _openUsers() {
    Navigator.pushNamed(
      context,
      AppRoutes.users,
    );
  }

  void _openReports() {
    Navigator.pushNamed(
      context,
      AppRoutes.reports,
    );
  }

  void _openDataEntry() {
    Navigator.pushNamed(
      context,
      AppRoutes.dataEntry,
    );
  }

  void _showComingSoon(String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'سيتم استكمال شاشة $featureName في الخطوة التالية.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authController =
    context.watch<AuthController>();

    final distributorController =
    context.watch<DistributorController>();

    final user = authController.currentUser;

    final distributors =
        distributorController.distributors;

    final activeDistributors = distributors
        .where(
          (distributor) => distributor.active,
    )
        .toList(growable: false);

    final recordedDistributors = distributors
        .where(
          (distributor) =>
      distributor.lastRecordAt != null,
    )
        .toList(growable: false);

    final notRecordedDistributors = distributors
        .where(
          (distributor) =>
      distributor.lastRecordAt == null,
    )
        .toList(growable: false);

    final maximumLoadDistributor =
    _findMaximumLoadDistributor(
      distributors,
    );

    final minimumLoadDistributor =
    _findMinimumLoadDistributor(
      distributors,
    );

    final userName =
    user?.displayName.trim().isNotEmpty == true
        ? user!.displayName
        : 'الرئيس';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'سجل أحمال الموزعات',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
            ),
            child: Center(
              child: Text(
                userName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: _logout,
            icon: const Icon(
              Icons.logout,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await distributorController
              .stopListening();

          await distributorController
              .startListening();
        },
        child: SingleChildScrollView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 1200,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.stretch,
                children: [
                  _buildWelcomeCard(
                    userName: userName,
                  ),
                  const SizedBox(height: 16),

                  if (distributorController.isLoading &&
                      distributors.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child:
                        CircularProgressIndicator(),
                      ),
                    )
                  else ...[
                    if (distributorController
                        .errorMessage !=
                        null)
                      _buildErrorCard(
                        distributorController
                            .errorMessage!,
                      ),

                    LayoutBuilder(
                      builder: (
                          context,
                          constraints,
                          ) {
                        final cardWidth =
                        _calculateCardWidth(
                          constraints.maxWidth,
                        );

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: cardWidth,
                              child: _StatisticsCard(
                                title:
                                'إجمالي الموزعات',
                                value: distributors
                                    .length
                                    .toString(),
                                icon: Icons
                                    .account_tree_outlined,
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _StatisticsCard(
                                title:
                                'الموزعات النشطة',
                                value:
                                activeDistributors
                                    .length
                                    .toString(),
                                icon: Icons.power,
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _StatisticsCard(
                                title:
                                'موزعات سجلت الأحمال',
                                value:
                                recordedDistributors
                                    .length
                                    .toString(),
                                icon: Icons
                                    .check_circle_outline,
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _StatisticsCard(
                                title:
                                'موزعات لم تسجل',
                                value:
                                notRecordedDistributors
                                    .length
                                    .toString(),
                                icon: Icons
                                    .warning_amber_rounded,
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'ملخص الأحمال',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    LayoutBuilder(
                      builder: (
                          context,
                          constraints,
                          ) {
                        final cardWidth =
                        constraints.maxWidth >= 700
                            ? (constraints.maxWidth -
                            12) /
                            2
                            : constraints.maxWidth;

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: cardWidth,
                              child: _LoadSummaryCard(
                                title: 'أقصى حمل',
                                distributor:
                                maximumLoadDistributor,
                                emptyMessage:
                                'لا توجد أحمال مسجلة حتى الآن.',
                                icon:
                                Icons.trending_up,
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _LoadSummaryCard(
                                title: 'أقل حمل',
                                distributor:
                                minimumLoadDistributor,
                                emptyMessage:
                                'لا توجد أحمال مسجلة حتى الآن.',
                                icon:
                                Icons.trending_down,
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'إدارة النظام',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    LayoutBuilder(
                      builder: (
                          context,
                          constraints,
                          ) {
                        final buttonWidth =
                        _calculateActionWidth(
                          constraints.maxWidth,
                        );

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            SizedBox(
                              width: buttonWidth,
                              child:
                              _DashboardActionButton(
                                title:
                                'إدارة الموزعات',
                                icon:
                                Icons.account_tree,
                                onPressed:
                                _openDistributors,
                              ),
                            ),
                            SizedBox(
                              width: buttonWidth,
                              child:
                              _DashboardActionButton(
                                title:
                                'إدارة المستخدمين',
                                icon: Icons
                                    .manage_accounts,
                                onPressed: _openUsers,
                              ),
                            ),
                            SizedBox(
                              width: buttonWidth,
                              child:
                              _DashboardActionButton(
                                title:
                                'إدخال الأحمال',
                                icon:
                                Icons.edit_note,
                                onPressed:
                                _openDataEntry,
                              ),
                            ),
                            SizedBox(
                              width: buttonWidth,
                              child:
                              _DashboardActionButton(
                                title: 'التقارير',
                                icon: Icons
                                    .assessment_outlined,
                                onPressed:
                                _openReports,
                              ),
                            ),
                            SizedBox(
                              width: buttonWidth,
                              child:
                              _DashboardActionButton(
                                title:
                                'سجل العمليات',
                                icon: Icons.history,
                                onPressed: () {
                                  _showComingSoon(
                                    'سجل العمليات',
                                  );
                                },
                              ),
                            ),
                            SizedBox(
                              width: buttonWidth,
                              child:
                              _DashboardActionButton(
                                title: 'الإعدادات',
                                icon:
                                Icons.settings,
                                onPressed: () {
                                  _showComingSoon(
                                    'الإعدادات',
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    if (notRecordedDistributors
                        .isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildNotRecordedSection(
                        context,
                        notRecordedDistributors,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard({
    required String userName,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 28,
              child: Icon(
                Icons.admin_panel_settings,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    'مرحبًا، $userName',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'يمكنك متابعة الموزعات والأحمال وإدارة النظام.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(
      String message,
      ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 16,
      ),
      child: Card(
        color: Theme.of(context)
            .colorScheme
            .errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context)
                    .colorScheme
                    .onErrorContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
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
    );
  }

  Widget _buildNotRecordedSection(
      BuildContext context,
      List<Distributor> distributors,
      ) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(
          Icons.notification_important_outlined,
        ),
        title: Text(
          'الموزعات التي لم تسجل الأحمال '
              '(${distributors.length})',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        children: distributors.map(
              (distributor) {
            return ListTile(
              leading: const CircleAvatar(
                child: Icon(
                  Icons.electrical_services,
                ),
              ),
              title: Text(
                distributor.name,
              ),
              subtitle: Text(
                'الكود: ${distributor.code}',
              ),
              trailing: const Chip(
                label: Text(
                  'لم يسجل',
                ),
              ),
            );
          },
        ).toList(),
      ),
    );
  }

  double _calculateCardWidth(
      double maximumWidth,
      ) {
    if (maximumWidth >= 1000) {
      return (maximumWidth - 36) / 4;
    }

    if (maximumWidth >= 600) {
      return (maximumWidth - 12) / 2;
    }

    return maximumWidth;
  }

  double _calculateActionWidth(
      double maximumWidth,
      ) {
    if (maximumWidth >= 900) {
      return (maximumWidth - 24) / 3;
    }

    if (maximumWidth >= 550) {
      return (maximumWidth - 12) / 2;
    }

    return maximumWidth;
  }

  Distributor? _findMaximumLoadDistributor(
      List<Distributor> distributors,
      ) {
    final recorded = distributors
        .where(
          (item) =>
      item.lastTotalLoad != null,
    )
        .toList();

    if (recorded.isEmpty) {
      return null;
    }

    recorded.sort(
          (first, second) =>
          second.lastTotalLoad!.compareTo(
            first.lastTotalLoad!,
          ),
    );

    return recorded.first;
  }

  Distributor? _findMinimumLoadDistributor(
      List<Distributor> distributors,
      ) {
    final recorded = distributors
        .where(
          (item) =>
      item.lastTotalLoad != null,
    )
        .toList();

    if (recorded.isEmpty) {
      return null;
    }

    recorded.sort(
          (first, second) =>
          first.lastTotalLoad!.compareTo(
            second.lastTotalLoad!,
          ),
    );

    return recorded.first;
  }
}

class _StatisticsCard extends StatelessWidget {
  const _StatisticsCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              child: Icon(icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(title),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadSummaryCard
    extends StatelessWidget {
  const _LoadSummaryCard({
    required this.title,
    required this.distributor,
    required this.emptyMessage,
    required this.icon,
  });

  final String title;
  final Distributor? distributor;
  final String emptyMessage;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final item = distributor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              child: Icon(icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: item == null
                  ? Text(emptyMessage)
                  : Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  Text(
                    '${item.lastTotalLoad?.toStringAsFixed(2) ?? '0'} أمبير',
                    style:
                    Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(item.name),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardActionButton
    extends StatelessWidget {
  const _DashboardActionButton({
    required this.title,
    required this.icon,
    required this.onPressed,
  });

  final String title;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 20,
          ),
          child: Row(
            children: [
              CircleAvatar(
                child: Icon(icon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_back_ios_new,
              ),
            ],
          ),
        ),
      ),
    );
  }
}