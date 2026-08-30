import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../models/fueling_record.dart';
import '../services/firebase_service.dart';

class FuelingReportPage extends StatelessWidget {
  final FuelingRecord record;
  const FuelingReportPage({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Uint8List>>(
      future: FirebaseService.instance.fuelingImages(record.id),
      builder: (context, snapshot) {
        final images = snapshot.data ?? const <Uint8List>[];
        return AspectRatio(
          aspectRatio: 210 / 297,
          child: Material(
            color: Colors.white,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Column(
                children: [
                  Row(
                    textDirection: TextDirection.ltr,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset('assets/company_logo.png', width: 58, height: 58, fit: BoxFit.contain),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: const [
                          Text(AppConfig.ministryName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                          Text(AppConfig.companyName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                          Text(AppConfig.controlName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                          Text(AppConfig.departmentName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0B4A8B))),
                        ],
                      ),
                    ],
                  ),
                  const Text(AppConfig.reportTitle, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  Table(
                    border: TableBorder.all(color: Colors.black38, width: .6),
                    children: [
                      TableRow(children: [
                        _cell('التاريخ', DateFormat('yyyy/MM/dd HH:mm').format(record.createdAt)),
                        _cell('رقم السيارة', record.vehicleNumber),
                      ]),
                      TableRow(children: [
                        _cell('نوع الوقود', record.fuelType),
                        _cell('الموديل', record.vehicleModel),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Expanded(
                    child: snapshot.connectionState == ConnectionState.waiting
                        ? const Center(child: CircularProgressIndicator())
                        : GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 5,
                              mainAxisSpacing: 5,
                              childAspectRatio: .92,
                            ),
                            itemCount: 4,
                            itemBuilder: (_, i) => ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: Container(
                                decoration: BoxDecoration(border: Border.all(color: Colors.black45, width: .7)),
                                child: i < images.length
                                    ? Image.memory(images[i], width: double.infinity, height: double.infinity, fit: BoxFit.cover)
                                    : const Center(child: Icon(Icons.image_not_supported_outlined)),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(child: Text('السائق: ${record.driverName}', style: const TextStyle(fontSize: 8))),
                      Expanded(child: Text('العداد: ${NumberFormat.decimalPattern().format(record.odometer)} كم', textAlign: TextAlign.center, style: const TextStyle(fontSize: 8))),
                    ],
                  ),
                  const SizedBox(height: 9),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _Signature(AppConfig.driverSignature),
                      _Signature(AppConfig.transportHeadSignature),
                      _Signature(AppConfig.generalManagerSignature),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _cell(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 8.5)),
            Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8.5))),
          ],
        ),
      );
}

class _Signature extends StatelessWidget {
  final String text;
  const _Signature(this.text);
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 95,
        child: Column(
          children: [
            Text(text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 8)),
            const SizedBox(height: 9),
            const Text('........................', style: TextStyle(fontSize: 8)),
          ],
        ),
      );
}
