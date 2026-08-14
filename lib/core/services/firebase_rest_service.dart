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
  static const String _apiKey =
      'AIzaSyDXOJw0_HBNUYlyTMfYofFVMOiu3X0jQPw';

  static const String _projectId =
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
        'accounts:signInWithPassword?key=$_apiKey',
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

  static Future<Map<String, dynamic>?> getDocument({
    required String collection,
    required String documentId,
  }) async {
    final token = _session?.idToken;

    if (token == null || token.isEmpty) {
      return null;
    }

    final response = await http.get(
      Uri.parse(
        'https://firestore.googleapis.com/v1/'
        'projects/$_projectId/databases/(default)/'
        'documents/$collection/$documentId',
      ),
      headers: <String, String>{
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      return null;
    }

    return jsonDecode(response.body)
        as Map<String, dynamic>;
  }

  static Map<String, dynamic> decodeFields(
    Map<String, dynamic>? fields,
  ) {
    if (fields == null) {
      return <String, dynamic>{};
    }

    return fields.map(
      (key, value) => MapEntry(
        key,
        _decodeValue(
          value as Map<String, dynamic>,
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
      final mapValue =
          value['mapValue'] as Map<String, dynamic>?;

      return decodeFields(
        mapValue?['fields']
            as Map<String, dynamic>?,
      );
    }

    if (value.containsKey('arrayValue')) {
      final arrayValue =
          value['arrayValue']
              as Map<String, dynamic>?;

      final values =
          arrayValue?['values']
              as List<dynamic>? ??
          const <dynamic>[];

      return values
          .map(
            (item) => _decodeValue(
              item as Map<String, dynamic>,
            ),
          )
          .toList();
    }

    return null;
  }
}
