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

  static Future<FirebaseRestSession?> signIn({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/'
        'accounts:signInWithPassword?key=$apiKey',
      ),
      headers: const {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    );

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      return null;
    }

    final data =
        jsonDecode(response.body) as Map<String, dynamic>;

    final result = FirebaseRestSession(
      localId: (data['localId'] ?? '').toString(),
      idToken: (data['idToken'] ?? '').toString(),
      refreshToken:
          (data['refreshToken'] ?? '').toString(),
    );

    if (result.localId.isEmpty ||
        result.idToken.isEmpty) {
      return null;
    }

    _session = result;
    return result;
  }

  static void signOut() {
    _session = null;
  }

  static String? get token => _session?.idToken;

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

  static Uri collectionUrl(String collection) {
    return Uri.parse(
      'https://firestore.googleapis.com/v1/'
      'projects/$projectId/databases/(default)/'
      'documents/$collection',
    );
  }

  static Map<String, String> get authHeaders {
    final value = token;

    return {
      'Content-Type': 'application/json',
      if (value != null && value.isNotEmpty)
        'Authorization': 'Bearer $value',
    };
  }

  static Future<Map<String, dynamic>?> getDocument({
    required String collection,
    required String documentId,
  }) async {
    final response = await http.get(
      documentUrl(collection, documentId),
      headers: authHeaders,
    );

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      return null;
    }

    return jsonDecode(response.body)
        as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>>
      getCollection({
    required String collection,
    int pageSize = 1000,
  }) async {
    final uri = collectionUrl(collection).replace(
      queryParameters: {
        'pageSize': pageSize.toString(),
      },
    );

    final response = await http.get(
      uri,
      headers: authHeaders,
    );

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw StateError(
        'Firestore REST error: ${response.statusCode}',
      );
    }

    final decoded =
        jsonDecode(response.body) as Map<String, dynamic>;

    final documents =
        decoded['documents'] as List<dynamic>? ??
            const [];

    return documents
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  static String documentId(
    Map<String, dynamic> document,
  ) {
    final name = (document['name'] ?? '').toString();

    if (name.isEmpty) {
      return '';
    }

    return name.split('/').last;
  }

  static Map<String, dynamic> documentData(
    Map<String, dynamic> document,
  ) {
    final raw = document['fields'];

    if (raw is! Map<String, dynamic>) {
      return {};
    }

    return decodeFields(raw);
  }

  static Map<String, dynamic> decodeFields(
    Map<String, dynamic>? fields,
  ) {
    if (fields == null) {
      return {};
    }

    return fields.map(
      (key, value) => MapEntry(
        key,
        _decodeValue(
          Map<String, dynamic>.from(value as Map),
        ),
      ),
    );
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
      return value['timestampValue']?.toString();
    }

    if (value.containsKey('nullValue')) {
      return null;
    }

    if (value.containsKey('mapValue')) {
      final map =
          Map<String, dynamic>.from(
        value['mapValue'] as Map? ?? {},
      );

      return decodeFields(
        Map<String, dynamic>.from(
          map['fields'] as Map? ?? {},
        ),
      );
    }

    if (value.containsKey('arrayValue')) {
      final map =
          Map<String, dynamic>.from(
        value['arrayValue'] as Map? ?? {},
      );

      final values =
          map['values'] as List<dynamic>? ?? [];

      return values.map((item) {
        return _decodeValue(
          Map<String, dynamic>.from(item as Map),
        );
      }).toList();
    }

    return null;
  }

  static Map<String, dynamic> encodeFields(
    Map<String, dynamic> data,
  ) {
    return data.map(
      (key, value) => MapEntry(
        key,
        _encodeValue(value),
      ),
    );
  }

  static Map<String, dynamic> _encodeValue(
    dynamic value,
  ) {
    if (value == null) {
      return {'nullValue': null};
    }

    if (value is String) {
      return {'stringValue': value};
    }

    if (value is bool) {
      return {'booleanValue': value};
    }

    if (value is int) {
      return {'integerValue': value.toString()};
    }

    if (value is double) {
      return {'doubleValue': value};
    }

    if (value is DateTime) {
      return {
        'timestampValue':
            value.toUtc().toIso8601String(),
      };
    }

    if (value is Map) {
      final converted =
          Map<String, dynamic>.from(value);

      return {
        'mapValue': {
          'fields': encodeFields(converted),
        },
      };
    }

    if (value is List) {
      return {
        'arrayValue': {
          'values': value
              .map(_encodeValue)
              .toList(),
        },
      };
    }

    return {'stringValue': value.toString()};
  }

  static Future<String> createDocument({
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    final response = await http.post(
      collectionUrl(collection),
      headers: authHeaders,
      body: jsonEncode({
        'fields': encodeFields(data),
      }),
    );

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw StateError(
        'Firestore create failed: '
        '${response.statusCode}',
      );
    }

    final decoded =
        jsonDecode(response.body) as Map<String, dynamic>;

    return documentId(decoded);
  }

  static Future<void> patchDocument({
    required String collection,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    final fields = data.keys.toList();

    var uri = documentUrl(
      collection,
      documentId,
    );

    final parameters = <String, dynamic>{};

    for (var i = 0; i < fields.length; i++) {
      parameters['updateMask.fieldPaths[$i]'] =
          fields[i];
    }

    uri = uri.replace(
      queryParameters: parameters.map(
        (key, value) =>
            MapEntry(key, value.toString()),
      ),
    );

    final response = await http.patch(
      uri,
      headers: authHeaders,
      body: jsonEncode({
        'fields': encodeFields(data),
      }),
    );

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw StateError(
        'Firestore update failed: '
        '${response.statusCode}',
      );
    }
  }

  static Future<void> deleteDocument({
    required String collection,
    required String documentId,
  }) async {
    final response = await http.delete(
      documentUrl(
        collection,
        documentId,
      ),
      headers: authHeaders,
    );

    if (response.statusCode != 200 &&
        response.statusCode != 204) {
      throw StateError(
        'Firestore delete failed: '
        '${response.statusCode}',
      );
    }
  }
}
