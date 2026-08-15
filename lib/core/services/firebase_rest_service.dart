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

  // =========================================================
  // SIGN IN
  // =========================================================

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
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  // =========================================================
  // SIGN OUT
  // =========================================================

  static void signOut() {
    _session = null;
  }

  // =========================================================
  // URLS
  // =========================================================

  static Uri documentUrl(
    String collection,
    String documentId,
  ) {
    return Uri.parse(
      'https://firestore.googleapis.com/v1/'
      'projects/$projectId/'
      'databases/(default)/documents/'
      '$collection/$documentId',
    );
  }

  static Uri collectionUrl(
    String collection,
  ) {
    return Uri.parse(
      'https://firestore.googleapis.com/v1/'
      'projects/$projectId/'
      'databases/(default)/documents/'
      '$collection',
    );
  }

  // =========================================================
  // HEADERS
  // =========================================================

  static Map<String, String> get authHeaders {
    final value = token;

    return <String, String>{
      'Content-Type': 'application/json',
      if (value != null &&
          value.trim().isNotEmpty)
        'Authorization': 'Bearer $value',
    };
  }

  // =========================================================
  // GET DOCUMENT
  // =========================================================

  static Future<Map<String, dynamic>?>
      getDocument({
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
        'Firestore REST get document error: '
        '${response.statusCode} '
        '${response.body}',
      );
    }

    final decoded =
        jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    return decoded;
  }

  // =========================================================
  // GET COLLECTION
  // =========================================================

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
        'Firestore REST get collection error: '
        '${response.statusCode} '
        '${response.body}',
      );
    }

    final decoded =
        jsonDecode(response.body);

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

  // =========================================================
  // DOCUMENT ID
  // =========================================================

  static String documentId(
    Map<String, dynamic> document,
  ) {
    final name =
        (document['name'] ?? '').toString();

    if (name.isEmpty) {
      return '';
    }

    final parts =
        name.split('/');

    if (parts.isEmpty) {
      return '';
    }

    return parts.last;
  }

  // =========================================================
  // DOCUMENT DATA
  // =========================================================

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

  // =========================================================
  // DECODE FIELDS
  // =========================================================

  static Map<String, dynamic> decodeFields(
    Map<String, dynamic>? fields,
  ) {
    if (fields == null) {
      return <String, dynamic>{};
    }

    final result =
        <String, dynamic>{};

    for (final entry
        in fields.entries) {
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

  // =========================================================
  // DECODE VALUE
  // =========================================================

  static dynamic _decodeValue(
    Map<String, dynamic> value,
  ) {
    if (value.containsKey(
      'stringValue',
    )) {
      return value['stringValue'];
    }

    if (value.containsKey(
      'booleanValue',
    )) {
      return value['booleanValue'];
    }

    if (value.containsKey(
      'integerValue',
    )) {
      return int.tryParse(
        value['integerValue']
            .toString(),
      );
    }

    if (value.containsKey(
      'doubleValue',
    )) {
      final raw =
          value['doubleValue'];

      if (raw is num) {
        return raw.toDouble();
      }

      return double.tryParse(
        raw?.toString() ?? '',
      );
    }

    if (value.containsKey(
      'timestampValue',
    )) {
      return value['timestampValue']
          ?.toString();
    }

    if (value.containsKey(
      'nullValue',
    )) {
      return null;
    }

    if (value.containsKey(
      'mapValue',
    )) {
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

    if (value.containsKey(
      'arrayValue',
    )) {
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

  // =========================================================
  // ENCODE FIELDS
  // =========================================================

  static Map<String, dynamic> encodeFields(
    Map<String, dynamic> data,
  ) {
    final result =
        <String, dynamic>{};

    for (final entry
        in data.entries) {
      result[entry.key] =
          _encodeValue(
        entry.value,
      );
    }

    return result;
  }

  // =========================================================
  // ENCODE VALUE
  // =========================================================

  static Map<String, dynamic> _encodeValue(
    dynamic value,
  ) {
    if (value == null) {
      return <String, dynamic>{
        'nullValue': null,
      };
    }

    if (value is String) {
      return <String, dynamic>{
        'stringValue': value,
      };
    }

    if (value is bool) {
      return <String, dynamic>{
        'booleanValue': value,
      };
    }

    if (value is int) {
      return <String, dynamic>{
        'integerValue':
            value.toString(),
      };
    }

    if (value is double) {
      return <String, dynamic>{
        'doubleValue': value,
      };
    }

    if (value is num) {
      return <String, dynamic>{
        'doubleValue':
            value.toDouble(),
      };
    }

    if (value is DateTime) {
      return <String, dynamic>{
        'timestampValue':
            value
                .toUtc()
                .toIso8601String(),
      };
    }

    if (value is Map) {
      final converted =
          Map<String, dynamic>.from(
        value,
      );

      return <String, dynamic>{
        'mapValue':
            <String, dynamic>{
          'fields':
              encodeFields(
            converted,
          ),
        },
      };
    }

    if (value is List) {
      return <String, dynamic>{
        'arrayValue':
            <String, dynamic>{
          'values': value
              .map(
                _encodeValue,
              )
              .toList(),
        },
      };
    }

    return <String, dynamic>{
      'stringValue':
          value.toString(),
    };
  }

  // =========================================================
  // CREATE DOCUMENT
  // =========================================================

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
            <String, dynamic>{
              'fields':
                  encodeFields(
                data,
              ),
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
        '${response.statusCode} '
        '${response.body}',
      );
    }

    final decoded =
        jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw StateError(
        'Firestore returned invalid create response.',
      );
    }

    return documentId(
      decoded,
    );
  }

  // =========================================================
  // PATCH DOCUMENT
  // =========================================================

  static Future<void> patchDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    final fields =
        data.keys.toList();

    var uri = documentUrl(
      collection,
      documentId,
    );

    final queryParameters =
        <String, String>{};

    for (var index = 0;
        index < fields.length;
        index++) {
      queryParameters[
              'updateMask.fieldPaths[$index]'] =
          fields[index];
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
            <String, dynamic>{
              'fields':
                  encodeFields(
                data,
              ),
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
        '${response.statusCode} '
        '${response.body}',
      );
    }
  }

  // =========================================================
  // DELETE DOCUMENT
  // =========================================================

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
        '${response.statusCode} '
        '${response.body}',
      );
    }
  }
}
