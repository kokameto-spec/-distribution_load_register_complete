import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class FirebaseRestSession {
  const FirebaseRestSession({
    required this.localId,
    required this.idToken,
    required this.refreshToken,
  });

  final String localId;
  final String idToken;
  final String refreshToken;
}

class FirebaseRestService {
  static const String apiKey =
      'AIzaSyDXOJw0_HBNUYlyTMfYofFVMOiu3X0jQPw';

  static const String projectId =
      'distribution-load-register';

  static FirebaseRestSession? _session;

  static FirebaseRestSession? get session => _session;

  static String? get token => _session?.idToken;

  static Future<FirebaseRestSession?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(
              'https://identitytoolkit.googleapis.com/v1/'
              'accounts:signInWithPassword?key=$apiKey',
            ),
            headers: const <String, String>{
              'Content-Type': 'application/json',
            },
            body: jsonEncode(
              <String, dynamic>{
                'email': email,
                'password': password,
                'returnSecureToken': true,
              },
            ),
          )
          .timeout(
            const Duration(seconds: 20),
          );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(
        response.body,
      );

      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final result = FirebaseRestSession(
        localId:
            (decoded['localId'] ?? '').toString(),
        idToken:
            (decoded['idToken'] ?? '').toString(),
        refreshToken:
            (decoded['refreshToken'] ?? '').toString(),
      );

      if (result.localId.isEmpty ||
          result.idToken.isEmpty) {
        return null;
      }

      _session = result;

      return result;
    } catch (_) {
      return null;
    }
  }

  static void signOut() {
    _session = null;
  }

  static Uri documentUrl(
    String collection,
    String documentId,
  ) {
    return Uri.parse(
      'https://firestore.googleapis.com/v1/'
      'projects/$projectId/databases/(default)/'
      'documents/$collection/$documentId',
    );
  }

  static Uri collectionUrl(
    String collection,
  ) {
    return Uri.parse(
      'https://firestore.googleapis.com/v1/'
      'projects/$projectId/databases/(default)/'
      'documents/$collection',
    );
  }

  static Uri runQueryUrl() {
    return Uri.parse(
      'https://firestore.googleapis.com/v1/'
      'projects/$projectId/databases/(default)/'
      'documents:runQuery',
    );
  }

  static Map<String, String> get authHeaders {
    final value = token;

    return <String, String>{
      'Content-Type': 'application/json',
      if (value != null && value.isNotEmpty)
        'Authorization': 'Bearer $value',
    };
  }

  static Future<Map<String, dynamic>?> getDocument({
    required String collection,
    required String documentId,
  }) async {
    final response = await http
        .get(
          documentUrl(
            collection,
            documentId,
          ),
          headers: authHeaders,
        )
        .timeout(
          const Duration(seconds: 20),
        );

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw StateError(
        'Firestore get document error: '
        '${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(
      response.body,
    );

    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    return decoded;
  }

  static Future<List<Map<String, dynamic>>>
      getCollection({
    required String collection,
    int pageSize = 1000,
  }) async {
    final uri = collectionUrl(
      collection,
    ).replace(
      queryParameters: <String, String>{
        'pageSize': pageSize.toString(),
      },
    );

    final response = await http
        .get(
          uri,
          headers: authHeaders,
        )
        .timeout(
          const Duration(seconds: 20),
        );

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw StateError(
        'Firestore get collection error: '
        '${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(
      response.body,
    );

    if (decoded is! Map<String, dynamic>) {
      return <Map<String, dynamic>>[];
    }

    final rawDocuments =
        decoded['documents'];

    if (rawDocuments is! List) {
      return <Map<String, dynamic>>[];
    }

    return rawDocuments
        .whereType<Map>()
        .map(
          (item) =>
              Map<String, dynamic>.from(
            item,
          ),
        )
        .toList(
          growable: false,
        );
  }

  static Future<List<Map<String, dynamic>>>
      runQuery({
    required String collection,
    String? distributorId,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 500,
  }) async {
    final filters =
        <Map<String, dynamic>>[];

    if (distributorId != null &&
        distributorId.trim().isNotEmpty) {
      filters.add(
        {
          'fieldFilter': {
            'field': {
              'fieldPath': 'distributorId',
            },
            'op': 'EQUAL',
            'value': {
              'stringValue':
                  distributorId.trim(),
            },
          },
        },
      );
    }

    if (fromDate != null) {
      filters.add(
        {
          'fieldFilter': {
            'field': {
              'fieldPath': 'recordedAt',
            },
            'op':
                'GREATER_THAN_OR_EQUAL',
            'value': {
              'timestampValue': fromDate
                  .toUtc()
                  .toIso8601String(),
            },
          },
        },
      );
    }

    if (toDate != null) {
      filters.add(
        {
          'fieldFilter': {
            'field': {
              'fieldPath': 'recordedAt',
            },
            'op':
                'LESS_THAN_OR_EQUAL',
            'value': {
              'timestampValue': toDate
                  .toUtc()
                  .toIso8601String(),
            },
          },
        },
      );
    }

    Map<String, dynamic>? where;

    if (filters.length == 1) {
      where = filters.first;
    } else if (filters.length > 1) {
      where = {
        'compositeFilter': {
          'op': 'AND',
          'filters': filters,
        },
      };
    }

    final structuredQuery =
        <String, dynamic>{
      'from': [
        {
          'collectionId': collection,
        },
      ],
      if (where != null)
        'where': where,
      'orderBy': [
        {
          'field': {
            'fieldPath': 'recordedAt',
          },
          'direction': 'DESCENDING',
        },
      ],
      'limit': limit,
    };

    final response = await http
        .post(
          runQueryUrl(),
          headers: authHeaders,
          body: jsonEncode(
            {
              'structuredQuery':
                  structuredQuery,
            },
          ),
        )
        .timeout(
          const Duration(seconds: 30),
        );

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw StateError(
        'Firestore query error: '
        '${response.statusCode} ${response.body}',
      );
    }

    final decoded =
        jsonDecode(response.body);

    if (decoded is! List) {
      return <Map<String, dynamic>>[];
    }

    final result =
        <Map<String, dynamic>>[];

    for (final item in decoded) {
      if (item is! Map) {
        continue;
      }

      final map =
          Map<String, dynamic>.from(
        item,
      );

      final document =
          map['document'];

      if (document is Map) {
        result.add(
          Map<String, dynamic>.from(
            document,
          ),
        );
      }
    }

    return result;
  }

  static String documentId(
    Map<String, dynamic> document,
  ) {
    final name =
        (document['name'] ?? '').toString();

    if (name.isEmpty) {
      return '';
    }

    return name.split('/').last;
  }

  static Map<String, dynamic> documentData(
    Map<String, dynamic> document,
  ) {
    final raw =
        document['fields'];

    if (raw is! Map) {
      return <String, dynamic>{};
    }

    return decodeFields(
      Map<String, dynamic>.from(
        raw,
      ),
    );
  }

  static Map<String, dynamic> decodeFields(
    Map<String, dynamic>? fields,
  ) {
    if (fields == null) {
      return <String, dynamic>{};
    }

    final result =
        <String, dynamic>{};

    for (final entry in fields.entries) {
      final rawValue =
          entry.value;

      if (rawValue is Map) {
        result[entry.key] =
            _decodeValue(
          Map<String, dynamic>.from(
            rawValue,
          ),
        );
      }
    }

    return result;
  }

  static dynamic _decodeValue(
    Map<String, dynamic> value,
  ) {
    if (value.containsKey('stringValue')) {
      return value['stringValue'];
    }

    if (value.containsKey('booleanValue')) {
      return value['booleanValue'];
    }

    if (value.containsKey('integerValue')) {
      return int.tryParse(
        value['integerValue'].toString(),
      );
    }

    if (value.containsKey('doubleValue')) {
      return (value['doubleValue'] as num?)
          ?.toDouble();
    }

    if (value.containsKey('timestampValue')) {
      return value['timestampValue']
          ?.toString();
    }

    if (value.containsKey('nullValue')) {
      return null;
    }

    if (value.containsKey('mapValue')) {
      final rawMap =
          value['mapValue'];

      if (rawMap is! Map) {
        return <String, dynamic>{};
      }

      final mapValue =
          Map<String, dynamic>.from(
        rawMap,
      );

      final rawFields =
          mapValue['fields'];

      if (rawFields is! Map) {
        return <String, dynamic>{};
      }

      return decodeFields(
        Map<String, dynamic>.from(
          rawFields,
        ),
      );
    }

    if (value.containsKey('arrayValue')) {
      final rawArray =
          value['arrayValue'];

      if (rawArray is! Map) {
        return <dynamic>[];
      }

      final arrayValue =
          Map<String, dynamic>.from(
        rawArray,
      );

      final rawValues =
          arrayValue['values'];

      if (rawValues is! List) {
        return <dynamic>[];
      }

      return rawValues.map(
        (item) {
          if (item is! Map) {
            return null;
          }

          return _decodeValue(
            Map<String, dynamic>.from(
              item,
            ),
          );
        },
      ).toList();
    }

    return null;
  }

  static Map<String, dynamic> encodeFields(
    Map<String, dynamic> data,
  ) {
    final result =
        <String, dynamic>{};

    for (final entry in data.entries) {
      result[entry.key] =
          _encodeValue(
        entry.value,
      );
    }

    return result;
  }

  static Map<String, dynamic> _encodeValue(
    dynamic value,
  ) {
    if (value == null) {
      return {
        'nullValue': null,
      };
    }

    if (value is String) {
      return {
        'stringValue': value,
      };
    }

    if (value is bool) {
      return {
        'booleanValue': value,
      };
    }

    if (value is int) {
      return {
        'integerValue':
            value.toString(),
      };
    }

    if (value is num) {
      return {
        'doubleValue':
            value.toDouble(),
      };
    }

    if (value is DateTime) {
      return {
        'timestampValue': value
            .toUtc()
            .toIso8601String(),
      };
    }

    if (value is Map) {
      return {
        'mapValue': {
          'fields': encodeFields(
            Map<String, dynamic>.from(
              value,
            ),
          ),
        },
      };
    }

    if (value is List) {
      return {
        'arrayValue': {
          'values': value
              .map(
                _encodeValue,
              )
              .toList(),
        },
      };
    }

    return {
      'stringValue':
          value.toString(),
    };
  }

  static Future<String> createDocument({
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    final response = await http
        .post(
          collectionUrl(
            collection,
          ),
          headers: authHeaders,
          body: jsonEncode(
            {
              'fields':
                  encodeFields(data),
            },
          ),
        )
        .timeout(
          const Duration(seconds: 20),
        );

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw StateError(
        'Firestore create failed: '
        '${response.statusCode} ${response.body}',
      );
    }

    final decoded =
        jsonDecode(response.body);

    return documentId(
      Map<String, dynamic>.from(
        decoded,
      ),
    );
  }

  static Future<void> patchDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    final fields =
        data.keys.toList();

    var uri =
        documentUrl(
      collection,
      documentId,
    );

    final queryParameters =
        <String, String>{};

    for (var i = 0;
        i < fields.length;
        i++) {
      queryParameters[
              'updateMask.fieldPaths[$i]'] =
          fields[i];
    }

    uri = uri.replace(
      queryParameters:
          queryParameters,
    );

    final response = await http
        .patch(
          uri,
          headers: authHeaders,
          body: jsonEncode(
            {
              'fields':
                  encodeFields(data),
            },
          ),
        )
        .timeout(
          const Duration(seconds: 20),
        );

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw StateError(
        'Firestore update failed: '
        '${response.statusCode} ${response.body}',
      );
    }
  }

  static Future<void> deleteDocument({
    required String collection,
    required String documentId,
  }) async {
    final response = await http
        .delete(
          documentUrl(
            collection,
            documentId,
          ),
          headers: authHeaders,
        )
        .timeout(
          const Duration(seconds: 20),
        );

    if (response.statusCode != 200 &&
        response.statusCode != 204) {
      throw StateError(
        'Firestore delete failed: '
        '${response.statusCode} ${response.body}',
      );
    }
  }
}
