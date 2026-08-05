import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/distributor_controller.dart';
import '../../models/distributor_model.dart';

class DistributorFormDialog extends StatefulWidget {
  const DistributorFormDialog({
    super.key,
    this.distributor,
  });

  final Distributor? distributor;

  bool get isEditing => distributor != null;

  @override
  State<DistributorFormDialog> createState() =>
      _DistributorFormDialogState();
}

class _DistributorFormDialogState
    extends State<DistributorFormDialog> {
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;

  late bool _active;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _codeController = TextEditingController(
      text: widget.distributor?.code ?? '',
    );

    _nameController = TextEditingController(
      text: widget.distributor?.name ?? '',
    );

    _active = widget.distributor?.active ?? true;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    final code = _codeController.text.trim();
    final name = _nameController.text.trim();

    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'اكتب كود الموزع.';
      });
      return;
    }

    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'اكتب اسم الموزع.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final controller = context.read<DistributorController>();

    final bool success;

    if (widget.isEditing) {
      success = await controller.update(
        id: widget.distributor!.id,
        code: code,
        name: name,
        active: _active,
      );
    } else {
      success = await controller.create(
        code: code,
        name: name,
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
          controller.errorMessage ?? 'تعذر حفظ بيانات الموزع.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.isEditing
            ? 'تعديل بيانات الموزع'
            : 'إضافة موزع جديد',
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _codeController,
                enabled: !_isSaving,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'كود الموزع',
                  hintText: 'مثال: D001',
                  prefixIcon: Icon(Icons.qr_code),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  labelText: 'اسم الموزع',
                  hintText: 'مثال: موزع 26 يوليو',
                  prefixIcon: Icon(Icons.account_tree),
                  border: OutlineInputBorder(),
                ),
              ),
              if (widget.isEditing) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('الموزع نشط'),
                  subtitle: Text(
                    _active
                        ? 'يمكن استخدام الموزع وتسجيل أحماله.'
                        : 'الموزع موقوف ولا يمكن تسجيل أحماله.',
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onErrorContainer,
                    ),
                    textAlign: TextAlign.center,
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
                ? 'حفظ التعديلات'
                : 'إضافة الموزع',
          ),
        ),
      ],
    );
  }
}