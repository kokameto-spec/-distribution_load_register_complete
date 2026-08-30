import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../models/fueling_record.dart';

class FuelingReportPage extends StatelessWidget {
  final FuelingRecord record;
  const FuelingReportPage({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final labels = const ['مؤشر الوقود قبل التموين', 'مضخة الوقود', 'مؤشر الوقود بعد التموين', 'إيصال المحطة'];
    return AspectRatio(
      aspectRatio: 210 / 297,
      child: Material(
        color: Colors.white,
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Row(children: [
              Image.asset('assets/company_logo.png', width: 54, height: 54),
              Expanded(
                child: Column(children: [
                  Text(AppConfig.companyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(AppConfig.departmentName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0B4A8B))),
                  const Text(AppConfig.reportTitle),
                ]),
              ),
              const SizedBox(width: 54),
            ]),
            const SizedBox(height: 8),
            Table(
              border: TableBorder.all(color: Colors.black26),
              children: [
                TableRow(children: [_cell('التاريخ', DateFormat('yyyy/MM/dd  HH:mm').format(record.createdAt)), _cell('رقم السيارة', record.vehicleNumber)]),
                TableRow(children: [_cell('نوع الوقود', record.fuelType), _cell('موديل السيارة', record.vehicleModel)]),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: .95),
                itemCount: 4,
                itemBuilder: (_, i) => Container(
                  decoration: BoxDecoration(border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.all(5),
                  child: Column(children: [
                    Text(labels[i], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    Expanded(
                      child: i < record.imageUrls.length
                          ? Image.network(record.imageUrls[i], width: double.infinity, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)))
                          : const Center(child: Icon(Icons.image_not_supported_outlined)),
                    ),
                  ]),
                ),
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('السائق: ${record.driverName}'),
              Text('العداد: ${NumberFormat.decimalPattern().format(record.odometer)} كم'),
              const Text('الاعتماد: ....................'),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _cell(String label, String value) => Padding(
        padding: const EdgeInsets.all(7),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.bold)), Flexible(child: Text(value))]),
      );
}
