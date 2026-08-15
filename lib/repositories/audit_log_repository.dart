import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/services/firebase_rest_service.dart';
import '../models/audit_log.dart';

class AuditLogRepository {
  AuditLogRepository({
    FirebaseFirestore? firestore,
  }) {
    /*
     * Windows لا ينشئ FirebaseFirestore Native.
     */
    if (!_windows) {
      _firestore =
          firestore ?? FirebaseFirestore.instance;
    }
  }

  FirebaseFirestore? _firestore;

  static const int _defaultLimit = 200;
  static const int _searchLimit = 500;

  // =========================================================
  // PLATFORM
  // =========================================================

  bool get _windows {
    return !kIsWeb &&
        defaultTargetPlatform ==
            TargetPlatform.windows;
  }

  // =========================================================
  // FIRESTORE NATIVE
  // =========================================================

  FirebaseFirestore get _nativeFirestore {
    final firestore =
        _firestore;

    if (firestore == null) {
      throw StateError(
        'Firebase Native غير مستخدم على Windows.',
      );
    }

    return firestore;
  }

  CollectionReference<Map<String, dynamic>>
      get _collection {
    return _nativeFirestore.collection(
      'audit_logs',
    );
  }

  // =========================================================
  // WATCH LATEST
  // =========================================================

  Stream<List<AuditLog>> watchAll() {
    if (_windows) {
      /*
       * Windows لا يدعم snapshots
       * من Firestore Native في نسختنا.
       *
       * تحديث خفيف كل 30 ثانية.
       */
      return Stream<List<AuditLog>>.periodic(
        const Duration(
          seconds: 30,
        ),
      ).asyncMap(
        (_) => latest(),
      ).startWith(
        latest(),
      );
    }

    return _collection
        .orderBy(
          'createdAt',
          descending: true,
        )
        .limit(
          _defaultLimit,
        )
        .snapshots()
        .map(
          (snapshot) {
            return snapshot.docs
                .map(
                  AuditLog.fromFirestore,
                )
                .toList(
                  growable: false,
                );
          },
        );
  }

  // =========================================================
  // LATEST
  // =========================================================

  Future<List<AuditLog>> latest() async {
    if (_windows) {
      return _queryWindows(
        limit: _defaultLimit,
      );
    }

    final snapshot =
        await _collection
            .orderBy(
              'createdAt',
              descending: true,
            )
            .limit(
              _defaultLimit,
            )
            .get();

    return snapshot.docs
        .map(
          AuditLog.fromFirestore,
        )
        .toList(
          growable: false,
        );
  }

  // =========================================================
  // SEARCH
  // =========================================================

  Future<List<AuditLog>> search({
    String? action,
    String? targetCode,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final normalizedAction =
        action?.trim() ?? '';

    final normalizedCode =
        targetCode
                ?.trim()
                .toLowerCase() ??
            '';

    if (_windows) {
      /*
       * التاريخ تتم تصفيته في Firestore نفسه.
       *
       * action و targetCode يتم تصفيتهما
       * محليًا بعد تنزيل مجموعة محدودة فقط.
       */
      final logs =
          await _queryWindows(
        fromDate:
            fromDate,
        toDate:
            toDate,
        limit:
            _searchLimit,
      );

      return _filterLocal(
        logs,
        action:
            normalizedAction,
        targetCode:
            normalizedCode,
      );
    }

    Query<Map<String, dynamic>>
        query = _collection;

    if (fromDate != null) {
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo:
            Timestamp.fromDate(
          fromDate,
        ),
      );
    }

    if (toDate != null) {
      query = query.where(
        'createdAt',
        isLessThanOrEqualTo:
            Timestamp.fromDate(
          toDate,
        ),
      );
    }

    query = query.orderBy(
      'createdAt',
      descending: true,
    );

    final snapshot =
        await query
            .limit(
              _searchLimit,
            )
            .get();

    final logs =
        snapshot.docs
            .map(
              AuditLog.fromFirestore,
            )
            .toList();

    return _filterLocal(
      logs,
      action:
          normalizedAction,
      targetCode:
          normalizedCode,
    );
  }

  // =========================================================
  // WINDOWS QUERY
  // =========================================================

  Future<List<AuditLog>> _queryWindows({
    DateTime? fromDate,
    DateTime? toDate,
    int limit = _searchLimit,
  }) async {
    final filters =
        <Map<String, dynamic>>[];

    if (fromDate != null) {
      filters.add(
        <String, dynamic>{
          'fieldFilter':
              <String, dynamic>{
            'field':
                <String, dynamic>{
              'fieldPath':
                  'createdAt',
            },
            'op':
                'GREATER_THAN_OR_EQUAL',
            'value':
                <String, dynamic>{
              'timestampValue':
                  fromDate
                      .toUtc()
                      .toIso8601String(),
            },
          },
        },
      );
    }

    if (toDate != null) {
      filters.add(
        <String, dynamic>{
          'fieldFilter':
              <String, dynamic>{
            'field':
                <String, dynamic>{
              'fieldPath':
                  'createdAt',
            },
            'op':
                'LESS_THAN_OR_EQUAL',
            'value':
                <String, dynamic>{
              'timestampValue':
                  toDate
                      .toUtc()
                      .toIso8601String(),
            },
          },
        },
      );
    }

    Map<String, dynamic>? where;

    if (filters.length == 1) {
      where =
          filters.first;
    } else if (filters.length > 1) {
      where =
          <String, dynamic>{
        'compositeFilter':
            <String, dynamic>{
          'op':
              'AND',
          'filters':
              filters,
        },
      };
    }

    final structuredQuery =
        <String, dynamic>{
      'from':
          <Map<String, dynamic>>[
        <String, dynamic>{
          'collectionId':
              'audit_logs',
        },
      ],

      if (where != null)
        'where':
            where,

      'orderBy':
          <Map<String, dynamic>>[
        <String, dynamic>{
          'field':
              <String, dynamic>{
            'fieldPath':
                'createdAt',
          },
          'direction':
              'DESCENDING',
        },
      ],

      'limit':
          limit,
    };

    final uri =
        Uri.parse(
      'https://firestore.googleapis.com/v1/'
      'projects/${FirebaseRestService.projectId}/'
      'databases/(default)/documents:runQuery',
    );

    /*
     * نستخدم getValidAuthHeaders()
     * بدل authHeaders القديم.
     *
     * كده التوكن يتجدد قبل الطلب
     * عند الحاجة.
     */
    var headers =
        await FirebaseRestService
            .getValidAuthHeaders();

    var response =
        await http
            .post(
              uri,
              headers:
                  headers,
              body:
                  jsonEncode(
                <String, dynamic>{
                  'structuredQuery':
                      structuredQuery,
                },
              ),
            )
            .timeout(
              const Duration(
                seconds: 25,
              ),
            );

    /*
     * حماية إضافية:
     *
     * لو التوكن انتهى بعد الفحص مباشرة
     * ورجع Firestore 401،
     * نعمل Refresh ونعيد الطلب مرة واحدة.
     */
    if (response.statusCode == 401) {
      final refreshed =
          await FirebaseRestService
              .refreshIdToken();

      if (!refreshed) {
        throw StateError(
          'انتهت جلسة تسجيل الدخول. '
          'سجل الدخول مرة أخرى.',
        );
      }

      headers =
          await FirebaseRestService
              .getValidAuthHeaders();

      response =
          await http
              .post(
                uri,
                headers:
                    headers,
                body:
                    jsonEncode(
                  <String, dynamic>{
                    'structuredQuery':
                        structuredQuery,
                  },
                ),
              )
              .timeout(
                const Duration(
                  seconds: 25,
                ),
              );
    }

    // =======================================================
    // RESPONSE STATUS
    // =======================================================

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      _throwWindowsError(
        response,
      );
    }

    // =======================================================
    // DECODE
    // =======================================================

    final decoded =
        jsonDecode(
      response.body,
    );

    if (decoded is! List) {
      return <AuditLog>[];
    }

    final logs =
        <AuditLog>[];

    for (final item in decoded) {
      if (item is! Map) {
        continue;
      }

      final row =
          Map<String, dynamic>.from(
        item,
      );

      final rawDocument =
          row['document'];

      if (rawDocument is! Map) {
        continue;
      }

      final document =
          Map<String, dynamic>.from(
        rawDocument,
      );

      final data =
          FirebaseRestService
              .documentData(
        document,
      );

      logs.add(
        _fromRest(
          FirebaseRestService
              .documentId(
            document,
          ),
          data,
        ),
      );
    }

    logs.sort(
      (a, b) =>
          b.createdAt.compareTo(
        a.createdAt,
      ),
    );

    return logs;
  }

  // =========================================================
  // LOCAL FILTER
  // =========================================================

  List<AuditLog> _filterLocal(
    List<AuditLog> logs, {
    required String action,
    required String targetCode,
  }) {
    final result =
        logs.where(
      (log) {
        if (action.isNotEmpty &&
            log.action != action) {
          return false;
        }

        if (targetCode.isNotEmpty &&
            !log.targetCode
                .toLowerCase()
                .contains(
                  targetCode,
                )) {
          return false;
        }

        return true;
      },
    ).toList();

    result.sort(
      (a, b) =>
          b.createdAt.compareTo(
        a.createdAt,
      ),
    );

    return result;
  }

  // =========================================================
  // REST MODEL
  // =========================================================

  AuditLog _fromRest(
    String id,
    Map<String, dynamic> data,
  ) {
    final rawDetails =
        data['details'];

    Map<String, dynamic> details =
        <String, dynamic>{};

    if (rawDetails is Map) {
      details =
          Map<String, dynamic>.from(
        rawDetails,
      );
    }

    return AuditLog(
      id:
          id,

      action:
          (data['action'] ?? '')
              .toString(),

      performedByUid:
          (data['performedByUid'] ?? '')
              .toString(),

      targetUid:
          (data['targetUid'] ?? '')
              .toString(),

      targetCode:
          (data['targetCode'] ?? '')
              .toString(),

      createdAt:
          _parseDate(
                data['createdAt'],
              ) ??
              DateTime.now(),

      details:
          details,
    );
  }

  // =========================================================
  // DATE
  // =========================================================

  DateTime? _parseDate(
    dynamic value,
  ) {
    if (value is DateTime) {
      return value;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is String) {
      return DateTime.tryParse(
        value,
      )?.toLocal();
    }

    return null;
  }

  // =========================================================
  // WINDOWS ERROR
  // =========================================================

  void _throwWindowsError(
    http.Response response,
  ) {
    switch (response.statusCode) {
      case 401:
        throw StateError(
          'انتهت جلسة تسجيل الدخول. '
          'سجل الدخول مرة أخرى.',
        );

      case 403:
        throw StateError(
          'لا توجد صلاحية لقراءة سجل العمليات.',
        );

      case 429:
        throw StateError(
          'تم إرسال طلبات كثيرة. '
          'أعد المحاولة بعد قليل.',
        );

      case 500:
      case 502:
      case 503:
      case 504:
        throw StateError(
          'خدمة سجل العمليات غير متاحة حاليًا.',
        );

      default:
        break;
    }

    String message =
        'تعذر تحميل سجل العمليات.';

    try {
      final decoded =
          jsonDecode(
        response.body,
      );

      if (decoded is Map) {
        final error =
            decoded['error'];

        if (error is Map) {
          final value =
              error['message'];

          if (value != null &&
              value
                  .toString()
                  .trim()
                  .isNotEmpty) {
            message =
                value.toString();
          }
        }
      }
    } catch (_) {
      // نستخدم الرسالة الافتراضية.
    }

    throw StateError(
      '$message '
      '(HTTP ${response.statusCode})',
    );
  }
}

// ===========================================================
// STREAM FIRST VALUE
// ===========================================================

extension _AuditStreamStart<T>
    on Stream<T> {
  Stream<T> startWith(
    Future<T> first,
  ) async* {
    yield await first;

    yield* this;
  }
}
