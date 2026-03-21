import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/guardian_models.dart';

class GuardianApi {
  GuardianApi({required this.baseUrl});

  final String baseUrl;

  Future<Map<String, dynamic>> fetchHealth() async {
    final response = await http.get(Uri.parse('$baseUrl/health'));
    if (response.statusCode != 200) {
      throw StateError('Health check failed with status ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchGuardianProfile({String? userId}) async {
    final uri = userId == null
        ? Uri.parse('$baseUrl/guardian-profile')
        : Uri.parse('$baseUrl/guardian-profile?user_id=$userId');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw StateError('Guardian profile failed with status ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<RegisterResult> registerIdentity({
    required String masterCommitment,
    required List<String> allowlist,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'master_commitment': masterCommitment,
        'allowlist': allowlist,
      }),
    );

    if (response.statusCode != 200) {
      throw StateError('Register failed with status ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return RegisterResult(
      userId: decoded['user_id'] as String,
      zkFastPathHint: decoded['zk_fast_path_hint'] as String,
    );
  }

  Future<GuardianDecision> signIntent({
    required String userId,
    required String destination,
    required double amount,
    required String userPartialSignature,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/sign-intent'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'destination': destination,
        'amount': amount,
        'user_partial_signature': userPartialSignature,
      }),
    );

    if (response.statusCode != 200) {
      throw StateError('Sign intent failed with status ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return GuardianDecision.fromJson(decoded);
  }
}
