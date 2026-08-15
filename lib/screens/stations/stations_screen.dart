import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_routes.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/distributor_controller.dart';
import '../../controllers/load_records_controller.dart';
import '../../controllers/station_controller.dart';
import '../../models/distributor_model.dart';
import '../../models/load_record.dart';
import '../../models/station_model.dart';

class StationsScreen extends StatefulWidget {
  const StationsScreen({
    super.key,
  });

  @override
  State<StationsScreen> createState() =>
      _StationsScreenState();
}

class _StationsScreenState
    extends State<StationsScreen> {
  bool _started = false;

  String _searchQuery = '';

  // =========================================================
  // START
  // =========================================================

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_started) {
      return;
    }

    _started = true;

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (!mounted) {
          return;
        }

        final stations =
            context.read<StationController>();

        final distributors =
            context.read<
                DistributorController>();

        final records =
            context.read<
                LoadRecordsController>();

        if (!stations.isListening) {
          stations.startListening();
        }

        if (!distributors.isListening) {
          distributors.startListening();
        }

        /*
         * نحتاج فقط آخر السجلات الحالية.
         * لا نكرر البحث داخل القائمة
         * لكل محطة ولكل محول.
         */
        records.startListeningAll();
      },
    );
  }

  // =========================================================
  // LATEST RECORD INDEX
  // =========================================================

  Map<String, LoadRecord> _latestIndex(
    List<LoadRecord> records,
  ) {
    final result =
        <String, LoadRecord>{};

    for (final record in records) {
      final old =
          result[record.distributorId];

      if (old == null ||
          record.recordedAt.isAfter(
            old.recordedAt,
          )) {
        result[record.distributorId] =
            record;
      }
    }

    return result;
  }

  // =========================================================
  // TRANSFORMER LOAD
  // =========================================================

  double _transformerLoad(
    StationTransformer transformer,
    Map<String, LoadRecord>
        latestRecords,
  ) {
    var total = 0.0;

    for (final link
        in transformer.inputLinks) {
      final record =
          latestRecords[
              link.distributorId];

      if (record == null) {
        continue;
      }

      total +=
          record.cellValues[
                  link.cellNumber] ??
              0;
    }

    return total;
  }

  // =========================================================
  // TRANSFORMER COMPLETE
  // =========================================================

  bool _transformerHasReading(
    StationTransformer transformer,
    Map<String, LoadRecord>
        latestRecords,
  ) {
    if (transformer.inputLinks.isEmpty) {
      return false;
    }

    for (final link
        in transformer.inputLinks) {
      if (!latestRecords.containsKey(
        link.distributorId,
      )) {
        return false;
      }
    }

    return true;
  }

  // =========================================================
  // STATION LOAD
  // =========================================================

  double _stationLoad(
    Station station,
    Map<String, LoadRecord>
        latestRecords,
  ) {
    var total = 0.0;

    for (final transformer
        in station.transformers) {
      total += _transformerLoad(
        transformer,
        latestRecords,
      );
    }

    return total;
  }

  // =========================================================
  // SEARCH
  // =========================================================

  bool _matchesSearch(
    Station station,
  ) {
    final query =
        _searchQuery
            .trim()
            .toLowerCase();

    if (query.isEmpty) {
      return true;
    }

    if (station.name
        .toLowerCase()
        .contains(query)) {
      return true;
    }

    for (final transformer
        in station.transformers) {
      if (transformer.name
          .toLowerCase()
          .contains(query)) {
        return true;
      }

      for (final link
          in transformer.inputLinks) {
        if (link.distributorName
                .toLowerCase()
                .contains(query) ||
            link.cellNumber.toString() ==
                query) {
          return true;
        }
      }
    }

    return false;
  }

  // =========================================================
  // REFRESH
  // =========================================================

  Future<void> _refresh() async {
    final stations =
        context.read<StationController>();

    final distributors =
        context.read<
            DistributorController>();

    final records =
        context.read<
            LoadRecordsController>();

    await stations.stopListening();

    await distributors.stopListening();

    await records.stopListening();

    await stations.startListening();

    await distributors.startListening();

    records.startListeningAll();
  }

  // =========================================================
  // OPEN FORM
  // =========================================================

  Future<void> _openForm({
    Station? station,
  }) async {
    final distributors = context
        .read<DistributorController>()
        .activeDistributors;

    if (distributors.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'لا توجد موزعات نشطة لربط المحولات بها.',
          ),
        ),
      );

      return;
    }

    final result =
        await showDialog<
            _StationFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _StationFormDialog(
        station: station,
        distributors: distributors,
      ),
    );

    if (result == null ||
        !mounted) {
      return;
    }

    final controller =
        context.read<StationController>();

    final success =
        station == null
            ? await controller
                .createStation(
                name: result.name,
                transformers:
                    result.transformers,
              )
            : await controller
                .updateStation(
                station: station,
                name: result.name,
                active: result.active,
                transformers:
                    result.transformers,
              );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          success
              ? station == null
                  ? 'تم إنشاء المحطة.'
                  : 'تم تحديث المحطة.'
              : controller.errorMessage ??
                  'تعذر الحفظ.',
        ),
      ),
    );
  }

  // =========================================================
  // DELETE
  // =========================================================

  Future<void> _deleteStation(
    Station station,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title:
              const Text(
            'حذف المحطة',
          ),
          content: Text(
            'هل تريد حذف محطة '
            '${station.name}؟',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                false,
              ),
              child:
                  const Text(
                'إلغاء',
              ),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(
                dialogContext,
                true,
              ),
              child:
                  const Text(
                'حذف',
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

    final controller =
        context.read<StationController>();

    final success =
        await controller.deleteStation(
      station.id,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'تم حذف المحطة.'
              : controller.errorMessage ??
                  'تعذر الحذف.',
        ),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final stationController =
        context.watch<
            StationController>();

    final distributorController =
        context.watch<
            DistributorController>();

    final recordsController =
        context.watch<
            LoadRecordsController>();

    final authController =
        context.watch<AuthController>();

    final isPresident =
        authController
                .currentUser
                ?.isPresident ==
            true;

    final latestRecords =
        _latestIndex(
      recordsController.records,
    );

    final filteredStations =
        stationController.stations
            .where(
              _matchesSearch,
            )
            .toList();

    final totalTransformers =
        stationController.stations
            .fold<int>(
      0,
      (
        total,
        station,
      ) =>
          total +
          station.transformers.length,
    );

    final loading =
        stationController.isLoading ||
        distributorController.isLoading ||
        recordsController.isLoading;

    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'أحمال المحطات',
        ),
        actions: [
          IconButton(
            tooltip:
                'تقارير أحمال المحطات',
            onPressed: () {
              Navigator.pushNamed(
                context,
                AppRoutes.stationReports,
              );
            },
            icon:
                const Icon(
              Icons
                  .assessment_outlined,
            ),
          ),
        ],
      ),

      floatingActionButton:
          isPresident
              ? FloatingActionButton
                  .extended(
                  onPressed:
                      loading
                          ? null
                          : () =>
                              _openForm(),
                  icon:
                      const Icon(
                    Icons.add,
                  ),
                  label:
                      const Text(
                    'إنشاء محطة',
                  ),
                )
              : null,

      body: RefreshIndicator(
        onRefresh:
            _refresh,
        child: CustomScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets
                        .fromLTRB(
                  12,
                  12,
                  12,
                  6,
                ),
                child: TextField(
                  onChanged:
                      (value) {
                    setState(() {
                      _searchQuery =
                          value;
                    });
                  },
                  decoration:
                      InputDecoration(
                    labelText:
                        'بحث في المحطات والمحولات والموزعات',
                    hintText:
                        'اسم محطة، محول، موزع أو رقم خلية',
                    prefixIcon:
                        const Icon(
                      Icons.search,
                    ),
                    suffixIcon:
                        _searchQuery
                                .isEmpty
                            ? null
                            : IconButton(
                                tooltip:
                                    'مسح البحث',
                                onPressed:
                                    () {
                                  setState(
                                    () {
                                      _searchQuery =
                                          '';
                                    },
                                  );
                                },
                                icon:
                                    const Icon(
                                  Icons.clear,
                                ),
                              ),
                    border:
                        const OutlineInputBorder(),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Text(
                  'المحطات: '
                  '${stationController.stations.length}'
                  '  •  '
                  'المحولات: '
                  '$totalTransformers',
                ),
              ),
            ),

            if (stationController
                        .errorMessage !=
                    null ||
                recordsController
                        .errorMessage !=
                    null)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets
                          .all(
                    12,
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
                          const EdgeInsets
                              .all(
                        12,
                      ),
                      child: Text(
                        stationController
                                .errorMessage ??
                            recordsController
                                .errorMessage ??
                            '',
                      ),
                    ),
                  ),
                ),
              ),

            if (loading &&
                stationController
                    .stations.isEmpty)
              const SliverFillRemaining(
                hasScrollBody:
                    false,
                child: Center(
                  child:
                      CircularProgressIndicator(),
                ),
              )
            else if (stationController
                .stations.isEmpty)
              const SliverFillRemaining(
                hasScrollBody:
                    false,
                child: Center(
                  child: Text(
                    'لم يتم إنشاء محطات محولات بعد.',
                  ),
                ),
              )
            else if (filteredStations
                .isEmpty)
              const SliverFillRemaining(
                hasScrollBody:
                    false,
                child: Center(
                  child: Text(
                    'لا توجد نتائج مطابقة للبحث.',
                  ),
                ),
              )
            else
              SliverPadding(
                padding:
                    const EdgeInsets
                        .fromLTRB(
                  12,
                  6,
                  12,
                  90,
                ),
                sliver:
                    SliverList.separated(
                  itemCount:
                      filteredStations
                          .length,
                  separatorBuilder:
                      (_, __) =>
                          const SizedBox(
                    height: 10,
                  ),
                  itemBuilder:
                      (
                    context,
                    index,
                  ) {
                    final station =
                        filteredStations[
                            index];

                    final totalLoad =
                        _stationLoad(
                      station,
                      latestRecords,
                    );

                    return Card(
                      child:
                          ExpansionTile(
                        leading:
                            const CircleAvatar(
                          child:
                              Icon(
                            Icons
                                .electrical_services_outlined,
                          ),
                        ),

                        title:
                            Text(
                          station.name,
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        subtitle:
                            Text(
                          'إجمالي الحمل الحالي: '
                          '${totalLoad.toStringAsFixed(1)} A\n'
                          'عدد المحولات: '
                          '${station.transformers.length}',
                        ),

                        trailing:
                            isPresident
                                ? PopupMenuButton<
                                    String>(
                                    onSelected:
                                        (value) {
                                      if (value ==
                                          'edit') {
                                        _openForm(
                                          station:
                                              station,
                                        );
                                      }

                                      if (value ==
                                          'delete') {
                                        _deleteStation(
                                          station,
                                        );
                                      }
                                    },
                                    itemBuilder:
                                        (_) =>
                                            const [
                                      PopupMenuItem(
                                        value:
                                            'edit',
                                        child:
                                            Text(
                                          'تعديل',
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value:
                                            'delete',
                                        child:
                                            Text(
                                          'حذف',
                                        ),
                                      ),
                                    ],
                                  )
                                : null,

                        children:
                            station
                                .transformers
                                .map(
                          (
                            transformer,
                          ) {
                            final load =
                                _transformerLoad(
                              transformer,
                              latestRecords,
                            );

                            final complete =
                                _transformerHasReading(
                              transformer,
                              latestRecords,
                            );

                            return ListTile(
                              leading:
                                  const Icon(
                                Icons
                                    .transform_outlined,
                              ),
                              title:
                                  Text(
                                transformer.name,
                              ),
                              subtitle:
                                  Text(
                                '${transformer.linksSummary}\n'
                                '${complete ? 'عدد خلايا الدخول: ${transformer.inputLinks.length}' : 'لا توجد قراءة كاملة لكل الموزعات المرتبطة'}',
                              ),
                              trailing:
                                  Text(
                                '${load.toStringAsFixed(1)} A',
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ).toList(),
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

// ===========================================================
// STATION FORM RESULT
// ===========================================================

class _StationFormResult {
  const _StationFormResult({
    required this.name,
    required this.active,
    required this.transformers,
  });

  final String name;
  final bool active;

  final List<StationTransformer>
      transformers;
}

// ===========================================================
// STATION FORM
// ===========================================================

class _StationFormDialog
    extends StatefulWidget {
  const _StationFormDialog({
    required this.station,
    required this.distributors,
  });

  final Station? station;

  final List<Distributor>
      distributors;

  @override
  State<_StationFormDialog>
      createState() =>
          _StationFormDialogState();
}

class _StationFormDialogState
    extends State<_StationFormDialog> {
  late final TextEditingController
      _nameController;

  late bool _active;

  late List<StationTransformer>
      _transformers;

  static const List<int>
      _allowedCells = <int>[
    5,
    6,
    9,
    10,
  ];

  @override
  void initState() {
    super.initState();

    _nameController =
        TextEditingController(
      text:
          widget.station?.name ??
              '',
    );

    _active =
        widget.station?.active ??
            true;

    _transformers =
        List<StationTransformer>.from(
      widget.station?.transformers ??
          const [],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();

    super.dispose();
  }

  // =========================================================
  // ADD TRANSFORMER
  // =========================================================

  Future<void> _addTransformer({
    StationTransformer? existing,
    int? index,
  }) async {
    final result =
        await showDialog<
            StationTransformer>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _TransformerDialog(
        existing: existing,
        distributors:
            widget.distributors,
        allowedCells:
            _allowedCells,
      ),
    );

    if (result == null) {
      return;
    }

    setState(() {
      if (index == null) {
        _transformers.add(
          result,
        );
      } else {
        _transformers[index] =
            result;
      }
    });
  }

  // =========================================================
  // SAVE
  // =========================================================

  void _save() {
    final name =
        _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text(
            'أدخل اسم المحطة.',
          ),
        ),
      );

      return;
    }

    if (_transformers.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text(
            'أضف محولًا واحدًا على الأقل.',
          ),
        ),
      );

      return;
    }

    if (_transformers.any(
      (item) =>
          item.inputLinks.isEmpty,
    )) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'كل محول يجب أن يحتوي على خلية دخول واحدة على الأقل.',
          ),
        ),
      );

      return;
    }

    Navigator.pop(
      context,
      _StationFormResult(
        name: name,
        active: _active,
        transformers:
            List<StationTransformer>
                .unmodifiable(
          _transformers,
        ),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return AlertDialog(
      title:
          Text(
        widget.station == null
            ? 'إنشاء محطة محولات'
            : 'تعديل محطة المحولات',
      ),
      content: SizedBox(
        width: 650,
        child:
            SingleChildScrollView(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              TextField(
                controller:
                    _nameController,
                decoration:
                    const InputDecoration(
                  labelText:
                      'اسم المحطة',
                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              SwitchListTile(
                value:
                    _active,
                onChanged:
                    (value) {
                  setState(() {
                    _active =
                        value;
                  });
                },
                title:
                    const Text(
                  'المحطة نشطة',
                ),
              ),

              const Divider(),

              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'المحولات',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed:
                        () =>
                            _addTransformer(),
                    icon:
                        const Icon(
                      Icons.add,
                    ),
                    label:
                        const Text(
                      'إضافة محول',
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 8,
              ),

              ...List.generate(
                _transformers.length,
                (
                  index,
                ) {
                  final item =
                      _transformers[
                          index];

                  return Card(
                    child:
                        ListTile(
                      title:
                          Text(
                        item.name,
                      ),
                      subtitle:
                          Text(
                        '${item.linksSummary}\n'
                        'عدد خلايا الدخول: '
                        '${item.inputLinks.length}',
                      ),
                      trailing:
                          Wrap(
                        spacing:
                            4,
                        children: [
                          IconButton(
                            tooltip:
                                'تعديل',
                            onPressed:
                                () =>
                                    _addTransformer(
                              existing:
                                  item,
                              index:
                                  index,
                            ),
                            icon:
                                const Icon(
                              Icons
                                  .edit_outlined,
                            ),
                          ),
                          IconButton(
                            tooltip:
                                'حذف',
                            onPressed:
                                () {
                              setState(
                                () {
                                  _transformers
                                      .removeAt(
                                    index,
                                  );
                                },
                              );
                            },
                            icon:
                                const Icon(
                              Icons
                                  .delete_outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),

      actions: [
        TextButton(
          onPressed:
              () =>
                  Navigator.pop(
            context,
          ),
          child:
              const Text(
            'إلغاء',
          ),
        ),
        FilledButton(
          onPressed:
              _save,
          child:
              const Text(
            'حفظ',
          ),
        ),
      ],
    );
  }
}

// ===========================================================
// TRANSFORMER DIALOG
// ===========================================================

class _TransformerDialog
    extends StatefulWidget {
  const _TransformerDialog({
    required this.existing,
    required this.distributors,
    required this.allowedCells,
  });

  final StationTransformer?
      existing;

  final List<Distributor>
      distributors;

  final List<int> allowedCells;

  @override
  State<_TransformerDialog>
      createState() =>
          _TransformerDialogState();
}

class _TransformerDialogState
    extends State<_TransformerDialog> {
  late final TextEditingController
      _nameController;

  late List<TransformerInputLink>
      _links;

  @override
  void initState() {
    super.initState();

    _nameController =
        TextEditingController(
      text:
          widget.existing?.name ??
              '',
    );

    _links =
        List<TransformerInputLink>.from(
      widget.existing?.inputLinks ??
          const [],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();

    super.dispose();
  }

  // =========================================================
  // ADD LINK
  // =========================================================

  Future<void> _addLink({
    TransformerInputLink? existing,
    int? index,
  }) async {
    final result =
        await showDialog<
            TransformerInputLink>(
      context: context,
      builder: (_) =>
          _InputLinkDialog(
        existing: existing,
        distributors:
            widget.distributors,
        allowedCells:
            widget.allowedCells,
      ),
    );

    if (result == null) {
      return;
    }

    final duplicate =
        _links.asMap().entries.any(
      (entry) {
        if (index != null &&
            entry.key == index) {
          return false;
        }

        return entry.value
                    .distributorId ==
                result.distributorId &&
            entry.value.cellNumber ==
                result.cellNumber;
      },
    );

    if (duplicate) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text(
            'هذه الخلية مضافة للمحول بالفعل.',
          ),
        ),
      );

      return;
    }

    setState(() {
      if (index == null) {
        _links.add(
          result,
        );
      } else {
        _links[index] =
            result;
      }
    });
  }

  // =========================================================
  // SAVE
  // =========================================================

  void _save() {
    final name =
        _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text(
            'أدخل مسمى المحول.',
          ),
        ),
      );

      return;
    }

    if (_links.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'أضف خلية دخول واحدة على الأقل للمحول.',
          ),
        ),
      );

      return;
    }

    Navigator.pop(
      context,
      StationTransformer(
        id:
            widget.existing?.id ??
                DateTime.now()
                    .microsecondsSinceEpoch
                    .toString(),
        name:
            name,
        inputLinks:
            List<TransformerInputLink>
                .unmodifiable(
          _links,
        ),
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return AlertDialog(
      title:
          Text(
        widget.existing == null
            ? 'إضافة محول'
            : 'تعديل المحول',
      ),
      content: SizedBox(
        width:
            560,
        child:
            SingleChildScrollView(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              TextField(
                controller:
                    _nameController,
                decoration:
                    const InputDecoration(
                  labelText:
                      'مسمى المحول',
                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(
                height: 14,
              ),

              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'خلايا الدخول المرتبطة بالمحول',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed:
                        () =>
                            _addLink(),
                    icon:
                        const Icon(
                      Icons.add_link,
                    ),
                    label:
                        const Text(
                      'إضافة خلية',
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 8,
              ),

              if (_links.isEmpty)
                const Padding(
                  padding:
                      EdgeInsets.all(
                    12,
                  ),
                  child: Text(
                    'لم تتم إضافة خلايا دخول بعد.',
                  ),
                ),

              ...List.generate(
                _links.length,
                (
                  index,
                ) {
                  final link =
                      _links[index];

                  return Card(
                    child:
                        ListTile(
                      title:
                          Text(
                        link.distributorName,
                      ),
                      subtitle:
                          Text(
                        'خلية '
                        '${link.cellNumber}',
                      ),
                      trailing:
                          Wrap(
                        spacing:
                            2,
                        children: [
                          IconButton(
                            tooltip:
                                'تعديل الربط',
                            onPressed:
                                () =>
                                    _addLink(
                              existing:
                                  link,
                              index:
                                  index,
                            ),
                            icon:
                                const Icon(
                              Icons
                                  .edit_outlined,
                            ),
                          ),
                          IconButton(
                            tooltip:
                                'حذف الربط',
                            onPressed:
                                () {
                              setState(
                                () {
                                  _links
                                      .removeAt(
                                    index,
                                  );
                                },
                              );
                            },
                            icon:
                                const Icon(
                              Icons
                                  .delete_outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),

      actions: [
        TextButton(
          onPressed:
              () =>
                  Navigator.pop(
            context,
          ),
          child:
              const Text(
            'إلغاء',
          ),
        ),
        FilledButton(
          onPressed:
              _save,
          child:
              const Text(
            'حفظ المحول',
          ),
        ),
      ],
    );
  }
}

// ===========================================================
// INPUT LINK DIALOG
// ===========================================================

class _InputLinkDialog
    extends StatefulWidget {
  const _InputLinkDialog({
    required this.existing,
    required this.distributors,
    required this.allowedCells,
  });

  final TransformerInputLink?
      existing;

  final List<Distributor>
      distributors;

  final List<int> allowedCells;

  @override
  State<_InputLinkDialog>
      createState() =>
          _InputLinkDialogState();
}

class _InputLinkDialogState
    extends State<_InputLinkDialog> {
  late String _distributorId;

  late int _cellNumber;

  @override
  void initState() {
    super.initState();

    final existingDistributorId =
        widget.existing
            ?.distributorId;

    final distributorExists =
        widget.distributors.any(
      (item) =>
          item.id ==
          existingDistributorId,
    );

    _distributorId =
        distributorExists
            ? existingDistributorId!
            : widget
                .distributors
                .first
                .id;

    _cellNumber =
        widget.allowedCells.contains(
          widget.existing
              ?.cellNumber,
        )
            ? widget.existing!
                .cellNumber
            : widget
                .allowedCells
                .first;
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return AlertDialog(
      title:
          Text(
        widget.existing == null
            ? 'إضافة خلية دخول'
            : 'تعديل خلية الدخول',
      ),
      content: SizedBox(
        width:
            430,
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            DropdownButtonFormField<
                String>(
              initialValue:
                  _distributorId,
              isExpanded:
                  true,
              decoration:
                  const InputDecoration(
                labelText:
                    'الموزع المرتبط',
                border:
                    OutlineInputBorder(),
              ),
              items:
                  widget.distributors
                      .map(
                (item) {
                  return DropdownMenuItem<
                      String>(
                    value:
                        item.id,
                    child:
                        Text(
                      item.name,
                    ),
                  );
                },
              ).toList(),
              onChanged:
                  (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _distributorId =
                      value;
                });
              },
            ),

            const SizedBox(
              height: 12,
            ),

            DropdownButtonFormField<
                int>(
              initialValue:
                  _cellNumber,
              decoration:
                  const InputDecoration(
                labelText:
                    'خلية الدخول',
                border:
                    OutlineInputBorder(),
              ),
              items:
                  widget.allowedCells
                      .map(
                (cell) {
                  return DropdownMenuItem<
                      int>(
                    value:
                        cell,
                    child:
                        Text(
                      'خلية $cell',
                    ),
                  );
                },
              ).toList(),
              onChanged:
                  (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _cellNumber =
                      value;
                });
              },
            ),
          ],
        ),
      ),

      actions: [
        TextButton(
          onPressed:
              () =>
                  Navigator.pop(
            context,
          ),
          child:
              const Text(
            'إلغاء',
          ),
        ),

        FilledButton(
          onPressed:
              () {
            final distributor =
                widget.distributors
                    .firstWhere(
              (item) =>
                  item.id ==
                  _distributorId,
            );

            Navigator.pop(
              context,
              TransformerInputLink(
                id:
                    widget.existing?.id ??
                        DateTime.now()
                            .microsecondsSinceEpoch
                            .toString(),
                distributorId:
                    distributor.id,
                distributorName:
                    distributor.name,
                cellNumber:
                    _cellNumber,
              ),
            );
          },
          child:
              Text(
            widget.existing == null
                ? 'إضافة'
                : 'حفظ',
          ),
        ),
      ],
    );
  }
}
