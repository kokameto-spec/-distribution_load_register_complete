import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_routes.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/distributor_controller.dart';
import '../../models/distributor_model.dart';

class ManagerDashboardScreen extends StatefulWidget {
  const ManagerDashboardScreen({
    super.key,
  });

  @override
  State<ManagerDashboardScreen> createState() =>
      _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState
    extends State<ManagerDashboardScreen> {
  bool _startedListening = false;

  // =========================================================
  // START
  // =========================================================

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_startedListening) {
      return;
    }

    _startedListening = true;

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!mounted) {
          return;
        }

        final distributorController =
            context.read<DistributorController>();

        if (!distributorController.isListening) {
          distributorController.startListening();
        }
      },
    );
  }

  // =========================================================
  // REFRESH
  // =========================================================

  Future<void> _refresh() async {
    final controller =
        context.read<DistributorController>();

    await controller.stopListening();

    await controller.startListening();
  }

  // =========================================================
  // LOGOUT
  // =========================================================

  Future<void> _logout() async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'تسجيل الخروج',
          ),
          content: const Text(
            'هل تريد تسجيل الخروج من البرنامج؟',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'إلغاء',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'تسجيل الخروج',
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

    await context
        .read<DistributorController>()
        .stopListening();

    if (!mounted) {
      return;
    }

    await context
        .read<AuthController>()
        .logout();

    if (!mounted) {
      return;
    }

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  // =========================================================
  // NAVIGATION
  // =========================================================

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

  void _openStations() {
    Navigator.pushNamed(
      context,
      AppRoutes.stations,
    );
  }

  // =========================================================
  // MISSING DISTRIBUTORS
  // =========================================================

  List<Distributor> _missingDistributors(
    List<Distributor> distributors,
  ) {
    final now = DateTime.now();

    final result = distributors.where(
      (distributor) {
        if (!distributor.active) {
          return false;
        }

        final lastRecordAt =
            distributor.lastRecordAt;

        if (lastRecordAt == null) {
          return true;
        }

        return now.difference(
              lastRecordAt,
            ) >=
            const Duration(
              hours: 1,
            );
      },
    ).toList();

    result.sort(
      (a, b) {
        final aDate =
            a.lastRecordAt;

        final bDate =
            b.lastRecordAt;

        if (aDate == null &&
            bDate == null) {
          return a.name.compareTo(
            b.name,
          );
        }

        if (aDate == null) {
          return -1;
        }

        if (bDate == null) {
          return 1;
        }

        return aDate.compareTo(
          bDate,
        );
      },
    );

    return result;
  }

  // =========================================================
  // RECENT DISTRIBUTORS
  // =========================================================

  List<Distributor> _recentDistributors(
    List<Distributor> distributors,
  ) {
    final result = distributors
        .where(
          (item) =>
              item.lastRecordAt != null,
        )
        .toList();

    result.sort(
      (a, b) {
        return b.lastRecordAt!.compareTo(
          a.lastRecordAt!,
        );
      },
    );

    if (result.length > 10) {
      return result
          .take(10)
          .toList();
    }

    return result;
  }

  // =========================================================
  // FORMAT
  // =========================================================

  String _formatLastRecord(
    DateTime? date,
  ) {
    if (date == null) {
      return 'لم يسجل من قبل';
    }

    final day =
        date.day
            .toString()
            .padLeft(
              2,
              '0',
            );

    final month =
        date.month
            .toString()
            .padLeft(
              2,
              '0',
            );

    final year =
        date.year.toString();

    final hour =
        date.hour
            .toString()
            .padLeft(
              2,
              '0',
            );

    final minute =
        date.minute
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '$year/$month/$day - $hour:$minute';
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final authController =
        context.watch<AuthController>();

    final distributorController =
        context.watch<
            DistributorController>();

    final currentUser =
        authController.currentUser;

    final displayName =
        currentUser?.displayName.trim();

    final userName =
        displayName != null &&
                displayName.isNotEmpty
            ? displayName
            : 'المدير';

    final distributors =
        distributorController
            .distributors;

    final activeDistributors =
        distributors
            .where(
              (item) => item.active,
            )
            .toList(
              growable: false,
            );

    final missingDistributors =
        _missingDistributors(
      distributors,
    );

    final recentDistributors =
        _recentDistributors(
      distributors,
    );

    final registeredCount =
        distributors
            .where(
              (item) =>
                  item.lastRecordAt !=
                  null,
            )
            .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'لوحة المدير / المشغل',
        ),
        actions: [
          Padding(
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 8,
            ),
            child: Center(
              child: Text(
                userName,
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
          ),

          IconButton(
            tooltip:
                'تسجيل الخروج',
            onPressed:
                _logout,
            icon:
                const Icon(
              Icons.logout,
            ),
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh:
            _refresh,
        child:
            SingleChildScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding:
              const EdgeInsets.all(
            16,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 1200,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .stretch,
                children: [
                  _buildWelcomeCard(
                    userName,
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  if (distributorController
                          .isLoading &&
                      distributors
                          .isEmpty)
                    const Center(
                      child: Padding(
                        padding:
                            EdgeInsets.all(
                          35,
                        ),
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

                    _buildStatisticsSection(
                      totalDistributors:
                          distributors.length,
                      activeDistributors:
                          activeDistributors.length,
                      registeredCount:
                          registeredCount,
                      missingCount:
                          missingDistributors.length,
                    ),

                    const SizedBox(
                      height: 24,
                    ),

                    _buildActionsSection(),

                    const SizedBox(
                      height: 24,
                    ),

                    _buildMissingDistributorsSection(
                      missingDistributors,
                    ),

                    const SizedBox(
                      height: 24,
                    ),

                    _buildLatestRecordsSection(
                      recentDistributors,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // WELCOME
  // =========================================================

  Widget _buildWelcomeCard(
    String userName,
  ) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(
          18,
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 28,
              child: Icon(
                Icons
                    .supervisor_account,
                size: 30,
              ),
            ),

            const SizedBox(
              width: 14,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    'مرحبًا، $userName',
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
                    height: 4,
                  ),

                  const Text(
                    'يمكنك متابعة الأحمال، '
                    'البحث في التقارير ومعرفة '
                    'الموزعات المتأخرة.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // STATISTICS
  // =========================================================

  Widget _buildStatisticsSection({
    required int totalDistributors,
    required int activeDistributors,
    required int registeredCount,
    required int missingCount,
  }) {
    return LayoutBuilder(
      builder:
          (
        context,
        constraints,
      ) {
        final width =
            _statisticsCardWidth(
          constraints.maxWidth,
        );

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: width,
              child:
                  _StatisticsCard(
                title:
                    'إجمالي الموزعات',
                value:
                    '$totalDistributors',
                icon:
                    Icons
                        .account_tree_outlined,
              ),
            ),

            SizedBox(
              width: width,
              child:
                  _StatisticsCard(
                title:
                    'الموزعات النشطة',
                value:
                    '$activeDistributors',
                icon:
                    Icons.power,
              ),
            ),

            SizedBox(
              width: width,
              child:
                  _StatisticsCard(
                title:
                    'موزعات سجلت أحمال',
                value:
                    '$registeredCount',
                icon:
                    Icons
                        .check_circle_outline,
              ),
            ),

            SizedBox(
              width: width,
              child:
                  _StatisticsCard(
                title:
                    'لم تسجل خلال ساعة',
                value:
                    '$missingCount',
                icon:
                    Icons
                        .warning_amber_rounded,
              ),
            ),
          ],
        );
      },
    );
  }

  // =========================================================
  // ACTIONS
  // =========================================================

  Widget _buildActionsSection() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment
              .stretch,
      children: [
        Text(
          'العمليات المتاحة',
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
          height: 12,
        ),

        LayoutBuilder(
          builder:
              (
            context,
            constraints,
          ) {
            final width =
                constraints.maxWidth >=
                        900
                    ? (constraints
                                .maxWidth -
                            24) /
                        3
                    : constraints.maxWidth >=
                            600
                        ? (constraints
                                    .maxWidth -
                                12) /
                            2
                        : constraints
                            .maxWidth;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width,
                  child:
                      _ActionButton(
                    title:
                        'التقارير والبحث',
                    subtitle:
                        'البحث بالتاريخ والساعة والموزع',
                    icon:
                        Icons
                            .assessment_outlined,
                    onPressed:
                        _openReports,
                  ),
                ),

                SizedBox(
                  width: width,
                  child:
                      _ActionButton(
                    title:
                        'إدخال الأحمال',
                    subtitle:
                        'إضافة سجل أحمال لموزع',
                    icon:
                        Icons.edit_note,
                    onPressed:
                        _openDataEntry,
                  ),
                ),

                SizedBox(
                  width: width,
                  child:
                      _ActionButton(
                    title:
                        'أحمال المحطات',
                    subtitle:
                        'متابعة المحطات والمحولات',
                    icon:
                        Icons
                            .electrical_services_outlined,
                    onPressed:
                        _openStations,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // =========================================================
  // MISSING
  // =========================================================

  Widget _buildMissingDistributorsSection(
    List<Distributor> distributors,
  ) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded:
            distributors.isNotEmpty,
        leading:
            const Icon(
          Icons
              .notification_important_outlined,
        ),
        title: Text(
          'الموزعات التي لم تسجل خلال ساعة '
          '(${distributors.length})',
          style:
              const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        subtitle:
            Text(
          distributors.isEmpty
              ? 'جميع الموزعات ملتزمة بالتسجيل.'
              : 'اضغط لعرض الموزعات المتأخرة.',
        ),
        children:
            distributors.map(
          (distributor) {
            return ListTile(
              leading:
                  const CircleAvatar(
                child: Icon(
                  Icons
                      .electrical_services,
                ),
              ),
              title:
                  Text(
                distributor.name,
              ),
              subtitle:
                  Text(
                'الكود: ${distributor.code}\n'
                'آخر تسجيل: '
                '${_formatLastRecord(distributor.lastRecordAt)}',
              ),
              isThreeLine:
                  true,
              trailing:
                  const Chip(
                label:
                    Text(
                  'متأخر',
                ),
              ),
            );
          },
        ).toList(),
      ),
    );
  }

  // =========================================================
  // LAST RECORDS
  // =========================================================

  Widget _buildLatestRecordsSection(
    List<Distributor> distributors,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment
              .stretch,
      children: [
        Text(
          'آخر تسجيلات الموزعات',
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
          height: 12,
        ),

        if (distributors.isEmpty)
          const Card(
            child: Padding(
              padding:
                  EdgeInsets.all(
                28,
              ),
              child: Center(
                child: Text(
                  'لا توجد تسجيلات أحمال حتى الآن.',
                ),
              ),
            ),
          )
        else
          ...distributors.map(
            (distributor) {
              return Padding(
                padding:
                    const EdgeInsets
                        .only(
                  bottom: 10,
                ),
                child: Card(
                  child: ListTile(
                    leading:
                        const CircleAvatar(
                      child:
                          Icon(
                        Icons.bolt,
                      ),
                    ),
                    title:
                        Text(
                      distributor.name,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    subtitle:
                        Text(
                      'الكود: ${distributor.code}\n'
                      '${_formatLastRecord(distributor.lastRecordAt)}',
                    ),
                    isThreeLine:
                        true,
                    trailing:
                        Text(
                      distributor.lastTotalLoad ==
                              null
                          ? '—'
                          : '${distributor.lastTotalLoad!.toStringAsFixed(2)} A',
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                    onTap:
                        _openReports,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // =========================================================
  // ERROR
  // =========================================================

  Widget _buildErrorCard(
    String message,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child: Card(
        color:
            Theme.of(
          context,
        )
                .colorScheme
                .errorContainer,
        child: Padding(
          padding:
              const EdgeInsets.all(
            14,
          ),
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                color:
                    Theme.of(
                  context,
                )
                        .colorScheme
                        .onErrorContainer,
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child: Text(
                  message,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // WIDTH
  // =========================================================

  double _statisticsCardWidth(
    double maxWidth,
  ) {
    if (maxWidth >= 1000) {
      return (maxWidth - 36) /
          4;
    }

    if (maxWidth >= 600) {
      return (maxWidth - 12) /
          2;
    }

    return maxWidth;
  }
}

// ===========================================================
// STATISTICS CARD
// ===========================================================

class _StatisticsCard
    extends StatelessWidget {
  const _StatisticsCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(
          18,
        ),
        child: Row(
          children: [
            CircleAvatar(
              child:
                  Icon(
                icon,
              ),
            ),

            const SizedBox(
              width: 14,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    value,
                    style:
                        Theme.of(
                      context,
                    )
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

                  Text(
                    title,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// ACTION BUTTON
// ===========================================================

class _ActionButton
    extends StatelessWidget {
  const _ActionButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      clipBehavior:
          Clip.antiAlias,
      child: InkWell(
        onTap:
            onPressed,
        child: Padding(
          padding:
              const EdgeInsets.all(
            18,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                child:
                    Icon(
                  icon,
                ),
              ),

              const SizedBox(
                width: 14,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      title,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      subtitle,
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons
                    .arrow_back_ios_new,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
