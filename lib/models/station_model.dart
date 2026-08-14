import 'package:cloud_firestore/cloud_firestore.dart';

class TransformerInputLink {
  const TransformerInputLink({
    required this.id,
    required this.distributorId,
    required this.distributorName,
    required this.cellNumber,
  });

  final String id;
  final String distributorId;
  final String distributorName;
  final int cellNumber;

  factory TransformerInputLink.fromMap(Map<String, dynamic> data) {
    return TransformerInputLink(
      id: (data['id'] ?? '').toString(),
      distributorId: (data['distributorId'] ?? '').toString(),
      distributorName: (data['distributorName'] ?? '').toString(),
      cellNumber: _intFromValue(data['cellNumber']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'distributorId': distributorId.trim(),
      'distributorName': distributorName.trim(),
      'cellNumber': cellNumber,
    };
  }

  String get label => '$distributorName - خلية $cellNumber';

  static int _intFromValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class StationTransformer {
  const StationTransformer({
    required this.id,
    required this.name,
    required this.inputLinks,
  });

  final String id;
  final String name;
  final List<TransformerInputLink> inputLinks;

  factory StationTransformer.fromMap(Map<String, dynamic> data) {
    final rawLinks = data['inputLinks'] as List?;
    final links = <TransformerInputLink>[];

    if (rawLinks != null) {
      links.addAll(
        rawLinks.whereType<Map>().map(
              (item) => TransformerInputLink.fromMap(
                Map<String, dynamic>.from(item),
              ),
            ),
      );
    }

    // توافق مع المحطات التي تم إنشاؤها قبل دعم أكثر من خلية للمحول.
    if (links.isEmpty && data['distributorId'] != null) {
      links.add(
        TransformerInputLink(
          id: 'legacy_${(data['id'] ?? '').toString()}',
          distributorId: (data['distributorId'] ?? '').toString(),
          distributorName: (data['distributorName'] ?? '').toString(),
          cellNumber: TransformerInputLink._intFromValue(data['cellNumber']),
        ),
      );
    }

    return StationTransformer(
      id: (data['id'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      inputLinks: List<TransformerInputLink>.unmodifiable(links),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name.trim(),
      'inputLinks': inputLinks.map((item) => item.toMap()).toList(growable: false),
    };
  }

  StationTransformer copyWith({
    String? id,
    String? name,
    List<TransformerInputLink>? inputLinks,
  }) {
    return StationTransformer(
      id: id ?? this.id,
      name: name ?? this.name,
      inputLinks: inputLinks ?? this.inputLinks,
    );
  }

  String get linksSummary => inputLinks.map((item) => item.label).join(' + ');
}

class Station {
  const Station({
    required this.id,
    required this.name,
    required this.active,
    required this.createdAt,
    required this.transformers,
  });

  final String id;
  final String name;
  final bool active;
  final DateTime createdAt;
  final List<StationTransformer> transformers;

  factory Station.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (data == null) {
      throw StateError('بيانات المحطة غير موجودة: ${document.id}');
    }

    final rawTransformers = data['transformers'] as List? ?? const [];

    return Station(
      id: document.id,
      name: (data['name'] ?? '').toString(),
      active: data['active'] != false,
      createdAt: _dateTimeFromValue(data['createdAt']) ?? DateTime.now(),
      transformers: rawTransformers
          .whereType<Map>()
          .map(
            (item) => StationTransformer.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'name': name.trim(),
      'active': active,
      'createdAt': Timestamp.fromDate(createdAt),
      'transformers': transformers
          .map((transformer) => transformer.toMap())
          .toList(growable: false),
    };
  }

  static DateTime? _dateTimeFromValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
