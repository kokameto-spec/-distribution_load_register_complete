import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/distributor_controller.dart';
import '../../controllers/load_records_controller.dart';
import '../../core/services/load_calculation_engine.dart';
import '../../models/distributor_model.dart';
import '../../models/load_calculation_result.dart';
import '../../models/load_record.dart';
import '../../models/user_role.dart';

class DataEntryScreen extends StatefulWidget {
  const DataEntryScreen({super.key});

  @override
  State<DataEntryScreen> createState() => _DataEntryScreenState();
}

class _DataEntryScreenState extends State<DataEntryScreen> {
  static const List<int> _inputCellNumbers = <int>[
    0,
    1,
    2,
    3,
    4,
    11,
    12,
    13,
    14,
    15,
  ];

  final TextEditingController _operatorNameController =
  TextEditingController();

  final Map<int, TextEditingController> _cellControllers =
  <int, TextEditingController>{};

  String? _selectedDistributorId;

  bool _cell5Running = true;
  bool _cell6Running = true;
  bool _cell9Running = true;
  bool _cell10Running = true;

  bool _isSaving = false;
  String? _errorMessage;
  LoadCalculationResult? _calculationResult;

  @override
  void initState() {
    super.initState();

    for (final cellNumber in _inputCellNumbers) {
      final controller = TextEditingController();

      controller.addListener(_calculate);

      _cellControllers[cellNumber] = controller;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final authController = context.read<AuthController>();
      final distributorController =
      context.read<DistributorController>();

      if (!distributorController.isListening) {
        distributorController.startListening();
      }

      final currentUser = authController.currentUser;

      if (currentUser?.role == UserRole.dataEntry) {
        setState(() {
          _selectedDistributorId = currentUser?.distributorId;
        });
      }

      _calculate();
    });
  }

  @override
  void dispose() {
    _operatorNameController.dispose();

    for (final controller in _cellControllers.values) {
      controller
        ..removeListener(_calculate)
        ..dispose();
    }

    super.dispose();
  }

  Map<int, double?> _readInputValues() {
    final values = <int, double?>{};

    for (final cellNumber in _inputCellNumbers) {
      final controller = _cellControllers[cellNumber];

      if (controller == null) {
        values[cellNumber] = 0;
        continue;
      }

      final text = controller.text.trim();

      if (text.isEmpty) {
        values[cellNumber] = 0;
        continue;
      }

      values[cellNumber] = double.tryParse(
        text.replaceAll(',', '.'),
      );
    }

    return values;
  }

  void _calculate() {
    try {
      final result = LoadCalculationEngine.calculate(
        inputValues: _readInputValues(),
        cell5Running: _cell5Running,
        cell6Running: _cell6Running,
        cell9Running: _cell9Running,
        cell10Running: _cell10Running,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _calculationResult = result;
        _errorMessage = result.errorMessage;
      });
    } on ArgumentError catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _calculationResult = null;
        _errorMessage = error.message?.toString();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _calculationResult = null;
        _errorMessage = 'تعذر حساب قيم الأحمال.';
      });
    }
  }

  Distributor? _selectedDistributor(
      DistributorController controller,
      ) {
    final distributorId = _selectedDistributorId;

    if (distributorId == null || distributorId.trim().isEmpty) {
      return null;
    }

    return controller.findById(distributorId);
  }

  Future<void> _saveAndExit() async {
    FocusScope.of(context).unfocus();

    final authController = context.read<AuthController>();
    final distributorController =
    context.read<DistributorController>();
    final recordsController =
    context.read<LoadRecordsController>();

    final currentUser = authController.currentUser;

    final distributor = _selectedDistributor(
      distributorController,
    );

    final operatorName = _operatorNameController.text.trim();

    if (currentUser == null) {
      setState(() {
        _errorMessage = 'جلسة المستخدم غير متاحة.';
      });
      return;
    }

    if (distributor == null) {
      setState(() {
        _errorMessage = 'اختر الموزع أولًا.';
      });
      return;
    }

    if (!distributor.active) {
      setState(() {
        _errorMessage =
        'هذا الموزع موقوف ولا يمكن تسجيل أحماله.';
      });
      return;
    }

    if (operatorName.isEmpty) {
      setState(() {
        _errorMessage = 'اكتب اسم مدخل البيانات.';
      });
      return;
    }

    _calculate();

    final calculationResult = _calculationResult;

    if (calculationResult == null ||
        !calculationResult.isValid) {
      setState(() {
        _errorMessage = calculationResult?.errorMessage ??
            'بيانات الأحمال غير صحيحة.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final remainingDuration =
      await recordsController.getRemainingTime(
        distributor.id,
      );

      if (!mounted) {
        return;
      }

      if (remainingDuration != null) {
        final totalSeconds = remainingDuration.inSeconds;

        final hours = totalSeconds ~/ 3600;
        final minutes = (totalSeconds % 3600) ~/ 60;
        final seconds = totalSeconds % 60;

        final remainingText = hours > 0
            ? '$hours ساعة و$minutes دقيقة'
            : minutes > 0
            ? '$minutes دقيقة و$seconds ثانية'
            : '$seconds ثانية';

        setState(() {
          _isSaving = false;
          _errorMessage =
          'تم تسجيل أحمال هذا الموزع بالفعل. '
              'يمكن التسجيل مرة أخرى بعد $remainingText.';
        });

        return;
      }

      final inputValues = _readInputValues();

      final allCellValues = <int, double>{
        0: inputValues[0] ?? 0,
        1: inputValues[1] ?? 0,
        2: inputValues[2] ?? 0,
        3: inputValues[3] ?? 0,
        4: inputValues[4] ?? 0,
        5: calculationResult.cell5,
        6: calculationResult.cell6,
        9: calculationResult.cell9,
        10: calculationResult.cell10,
        11: inputValues[11] ?? 0,
        12: inputValues[12] ?? 0,
        13: inputValues[13] ?? 0,
        14: inputValues[14] ?? 0,
        15: inputValues[15] ?? 0,
      };

      final record = LoadRecord(
        id: '',
        distributorId: distributor.id,
        distributorName: distributor.name,
        operatorName: operatorName,
        createdByUid: currentUser.uid,
        createdByCode: currentUser.code,
        recordedAt: DateTime.now(),
        totalLoad: calculationResult.totalInputLoad,
        cellValues: allCellValues,
        cellRunningStates: <int, bool>{
          5: _cell5Running,
          6: _cell6Running,
          9: _cell9Running,
          10: _cell10Running,
        },
      );

      final success = await recordsController.saveRecord(
        record,
      );

      if (!mounted) {
        return;
      }

      if (!success) {
        setState(() {
          _isSaving = false;
          _errorMessage = recordsController.errorMessage ??
              'تعذر حفظ البيانات.';
        });
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم حفظ الأحمال بنجاح.',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
        _errorMessage =
        'تعذر حفظ البيانات. تحقق من اتصال الإنترنت.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();

    final distributorController =
    context.watch<DistributorController>();

    final currentUser = authController.currentUser;

    final isDataEntry =
        currentUser?.role == UserRole.dataEntry;

    final activeDistributors =
        distributorController.activeDistributors;

    final selectedDistributor = _selectedDistributor(
      distributorController,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل الأحمال'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 900,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (distributorController.isLoading &&
                    distributorController.distributors.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (isDataEntry)
                  _buildFixedDistributorCard(
                    selectedDistributor,
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: _selectedDistributorId,
                    decoration: const InputDecoration(
                      labelText: 'اختيار الموزع',
                      prefixIcon: Icon(
                        Icons.account_tree,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    items: activeDistributors.map(
                          (distributor) {
                        return DropdownMenuItem<String>(
                          value: distributor.id,
                          child: Text(
                            '${distributor.name} - '
                                '${distributor.code}',
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

                if (distributorController.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  _buildErrorMessage(
                    distributorController.errorMessage!,
                  ),
                ],

                const SizedBox(height: 16),

                TextField(
                  controller: _operatorNameController,
                  enabled: !_isSaving,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'اسم مدخل البيانات',
                    hintText: 'اكتب الاسم الثلاثي',
                    prefixIcon: Icon(
                      Icons.person_outline,
                    ),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'الخلايا الرقمية',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  'أي خلية تُترك فارغة يتم احتساب قيمتها صفرًا.',
                ),

                const SizedBox(height: 12),

                _buildInputCells(),

                const SizedBox(height: 24),

                Text(
                  'حالة خلايا الربط',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  'ضع علامة داخل المربع إذا كانت الخلية في حالة تشغيل.',
                ),

                const SizedBox(height: 12),

                _buildSwitchCells(),

                const SizedBox(height: 24),

                _buildCalculatedResults(),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _buildErrorMessage(
                    _errorMessage!,
                  ),
                ],

                const SizedBox(height: 24),

                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed:
                    _isSaving ? null : _saveAndExit,
                    icon: _isSaving
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(
                      Icons.save_alt,
                    ),
                    label: Text(
                      _isSaving
                          ? 'جارٍ الحفظ...'
                          : 'حفظ وخروج',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFixedDistributorCard(
      Distributor? distributor,
      ) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(
            Icons.account_tree,
          ),
        ),
        title: Text(
          distributor?.name ??
              'لم يتم ربط الحساب بموزع',
        ),
        subtitle: distributor == null
            ? const Text(
          'راجع الرئيس لربط الحساب بالموزع.',
        )
            : Text(
          'كود الموزع: ${distributor.code}',
        ),
        trailing: distributor == null
            ? const Icon(
          Icons.error_outline,
        )
            : const Icon(
          Icons.lock_outline,
        ),
      ),
    );
  }

  Widget _buildInputCells() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double itemWidth;

        if (constraints.maxWidth >= 700) {
          itemWidth = (constraints.maxWidth - 24) / 3;
        } else if (constraints.maxWidth >= 450) {
          itemWidth = (constraints.maxWidth - 12) / 2;
        } else {
          itemWidth = constraints.maxWidth;
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _inputCellNumbers.map(
                (cellNumber) {
              return SizedBox(
                width: itemWidth,
                child: TextField(
                  controller:
                  _cellControllers[cellNumber],
                  enabled: !_isSaving,
                  keyboardType:
                  const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*[\.,]?\d*$'),
                    ),
                  ],
                  decoration: InputDecoration(
                    labelText: 'خلية $cellNumber',
                    hintText: '0',
                    suffixText: 'أمبير',
                    prefixIcon: const Icon(
                      Icons.electric_meter_outlined,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              );
            },
          ).toList(),
        );
      },
    );
  }

  Widget _buildSwitchCells() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double itemWidth;

        if (constraints.maxWidth >= 700) {
          itemWidth = (constraints.maxWidth - 36) / 4;
        } else if (constraints.maxWidth >= 450) {
          itemWidth = (constraints.maxWidth - 12) / 2;
        } else {
          itemWidth = constraints.maxWidth;
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildSwitchCell(
              width: itemWidth,
              cellNumber: 5,
              value: _cell5Running,
              onChanged: (value) {
                setState(() {
                  _cell5Running = value;
                });

                _calculate();
              },
            ),
            _buildSwitchCell(
              width: itemWidth,
              cellNumber: 6,
              value: _cell6Running,
              onChanged: (value) {
                setState(() {
                  _cell6Running = value;
                });

                _calculate();
              },
            ),
            _buildSwitchCell(
              width: itemWidth,
              cellNumber: 9,
              value: _cell9Running,
              onChanged: (value) {
                setState(() {
                  _cell9Running = value;
                });

                _calculate();
              },
            ),
            _buildSwitchCell(
              width: itemWidth,
              cellNumber: 10,
              value: _cell10Running,
              onChanged: (value) {
                setState(() {
                  _cell10Running = value;
                });

                _calculate();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSwitchCell({
    required double width,
    required int cellNumber,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SizedBox(
      width: width,
      child: Card(
        child: CheckboxListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          title: Text(
            'خلية $cellNumber',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            value ? 'تشغيل' : 'فصل',
          ),
          value: value,
          onChanged: _isSaving
              ? null
              : (newValue) {
            onChanged(newValue ?? false);
          },
          secondary: Icon(
            value
                ? Icons.power
                : Icons.power_off,
          ),
        ),
      ),
    );
  }

  Widget _buildCalculatedResults() {
    final result = _calculationResult;

    if (result == null) {
      return const SizedBox.shrink();
    }

    return Card(
      color: result.isValid
          ? null
          : Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'النتائج المحسوبة',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            _buildGroupSummary(
              title: 'مجموع الخلايا من 0 إلى 4',
              value: result.groupA,
            ),

            const SizedBox(height: 8),

            _buildGroupSummary(
              title: 'مجموع الخلايا من 11 إلى 15',
              value: result.groupB,
            ),

            const Divider(height: 24),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _resultChip(
                  title: 'خلية 5',
                  value: result.cell5,
                  running: _cell5Running,
                ),
                _resultChip(
                  title: 'خلية 6',
                  value: result.cell6,
                  running: _cell6Running,
                ),
                _resultChip(
                  title: 'خلية 9',
                  value: result.cell9,
                  running: _cell9Running,
                ),
                _resultChip(
                  title: 'خلية 10',
                  value: result.cell10,
                  running: _cell10Running,
                ),
              ],
            ),

            const Divider(height: 24),

            Row(
              children: [
                const Icon(
                  Icons.functions,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'إجمالي الحمل',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${result.totalInputLoad.toStringAsFixed(2)} أمبير',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupSummary({
    required String title,
    required double value,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(title),
        ),
        Text(
          '${value.toStringAsFixed(2)} أمبير',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _resultChip({
    required String title,
    required double value,
    required bool running,
  }) {
    return Chip(
      avatar: Icon(
        running
            ? Icons.bolt
            : Icons.power_off,
        size: 18,
      ),
      label: Text(
        '$title: ${value.toStringAsFixed(2)} أمبير',
      ),
    );
  }

  Widget _buildErrorMessage(
      String message,
      ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
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
    );
  }
}