import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/guardian_models.dart';
import '../services/guardian_api.dart';

class WalletController extends ChangeNotifier {
  static const String trustedAddress = AppConfig.trustedAddress;
  static const String suspiciousAddress = AppConfig.suspiciousAddress;

  final GuardianApi _api = GuardianApi(baseUrl: AppConfig.backendUrl);

  String userId = '';
  String nullifier = '';
  String commitment = '';
  String guardianStatus = 'IDLE';
  String guardianReason = '-';
  int riskScore = 0;
  double balance = 1.25; // ETH
  bool isLoading = false;
  List<ActivityEntry> activityLog = [];
  List<RuleEvaluation> lastRuleEvaluations = [];
  String? guardianSignerAddress;
  String? lastTxDigest;
  // Live from /health
  bool enclaveMode = false;
  String enclaveStatus = 'not_configured';
  // Live policy display
  String policyMaxAmount = '500';
  String policyAllowlist = AppConfig.trustedAddress;
  int intentsToday = 0;
  double allowRatePercent = 0;

  Future<void> simulateBiometricAndRegister() async {
    _setLoading(true, status: 'AUTH', reason: 'Generating anonymous identity...');

    final random = Random.secure();
    final entropy = List<int>.generate(16, (_) => random.nextInt(255));
    nullifier = base64UrlEncode(entropy);
    commitment = _commit(nullifier);

    try {
      final result = await _api.registerIdentity(
        masterCommitment: commitment,
        allowlist: [trustedAddress],
      );
      userId = result.userId;
      // Fetch health to get live enclave status and guardian address
      final health = await _api.fetchHealth();
      guardianSignerAddress = health['guardian_signer_address'] as String?;
      enclaveMode = (health['enclave_mode'] as bool?) ?? false;
      enclaveStatus = (health['enclave_status'] as String?) ?? 'not_configured';
      await _refreshGuardianProfile();
      guardianStatus = 'READY';
      guardianReason = 'Identity registered. Guardian is active.';
      _addActivity(ActivityEntry(
        status: 'READY',
        label: 'Identity registered',
        detail: userId,
        timestamp: DateTime.now(),
      ));
    } catch (_) {
      guardianStatus = 'ERROR';
      guardianReason = 'Registration failed. Ensure backend is running.';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> sendIntent({required String destination, required double amount}) async {
    if (userId.isEmpty) return;
    _setLoading(true, status: 'REVIEW', reason: 'Guardian evaluating policy rules...');

    try {
      final decision = await _api.signIntent(
        userId: userId,
        destination: destination,
        amount: amount,
        userPartialSignature: _commit('user_sig:$destination:$amount'),
      );

      guardianStatus = decision.status.toUpperCase();
      guardianReason = decision.reason;
      riskScore = decision.riskScore;
      lastRuleEvaluations = decision.ruleEvaluations;
      guardianSignerAddress = decision.guardianSignerAddress;
      lastTxDigest = decision.evmTransferDigest;
      await _refreshGuardianProfile();

      if (decision.status == 'allow') {
        balance -= amount;
      }

      _addActivity(ActivityEntry(
        intentId: decision.intentId,
        status: guardianStatus,
        label: '$guardianStatus → ${_shortAddr(destination)}',
        detail: '${amount.toStringAsFixed(4)} ETH | risk: $riskScore/100',
        destination: destination,
        amountEth: amount,
        proofDigest: decision.evmTransferDigest,
        guardianSignature: decision.status == 'allow' ? lastTxDigest : null,
        timestamp: DateTime.now(),
      ));
    } catch (_) {
      guardianStatus = 'ERROR';
      guardianReason = 'Sign intent failed. Check backend logs.';
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value, {String? status, String? reason}) {
    isLoading = value;
    if (status != null) guardianStatus = status;
    if (reason != null) guardianReason = reason;
    notifyListeners();
  }

  void _addActivity(ActivityEntry entry) {
    activityLog.insert(0, entry);
    notifyListeners();
  }

  Future<void> refreshGuardianProfile() async {
    await _refreshGuardianProfile();
    notifyListeners();
  }

  Future<void> _refreshGuardianProfile() async {
    try {
      final profile = await _api.fetchGuardianProfile(userId: userId.isEmpty ? null : userId);
      intentsToday = (profile['intents_today'] as num?)?.toInt() ?? intentsToday;
      allowRatePercent = (profile['allow_rate_percent'] as num?)?.toDouble() ?? allowRatePercent;
      final maxAmount = profile['policy_max_amount'];
      if (maxAmount != null) {
        policyMaxAmount = maxAmount.toString();
      }
      final allowlist = (profile['policy_allowlist'] as List<dynamic>?)?.cast<String>() ?? const [];
      if (allowlist.isNotEmpty) {
        policyAllowlist = allowlist.join(', ');
      }
      guardianSignerAddress = (profile['guardian_signer_address'] as String?) ?? guardianSignerAddress;
      enclaveMode = (profile['enclave_mode'] as bool?) ?? enclaveMode;
      enclaveStatus = (profile['enclave_status'] as String?) ?? enclaveStatus;
    } catch (_) {
      // Keep previous state if profile endpoint is temporarily unavailable.
    }
  }

  String _commit(String input) => base64UrlEncode(utf8.encode(input));

  String _shortAddr(String addr) =>
      addr.length > 10 ? '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}' : addr;
}

class ActivityEntry {
  final String? intentId;
  final String status;
  final String label;
  final String detail;
  final String? destination;
  final double? amountEth;
  final String? proofDigest;
  final String? guardianSignature;
  final DateTime timestamp;

  const ActivityEntry({
    this.intentId,
    required this.status,
    required this.label,
    required this.detail,
    this.destination,
    this.amountEth,
    this.proofDigest,
    this.guardianSignature,
    required this.timestamp,
  });

  bool get hasProof => intentId != null || proofDigest != null || guardianSignature != null;
}
