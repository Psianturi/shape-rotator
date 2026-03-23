class RegisterResult {
  const RegisterResult({required this.userId, required this.zkFastPathHint});

  final String userId;
  final String zkFastPathHint;
}

class RuleEvaluation {
  const RuleEvaluation({required this.rule, required this.status, required this.detail});

  final String rule;
  final String status;
  final String detail;

  factory RuleEvaluation.fromJson(Map<String, dynamic> json) => RuleEvaluation(
        rule: json['rule'] as String? ?? '-',
        status: json['status'] as String? ?? '-',
        detail: json['detail'] as String? ?? '-',
      );
}

class GuardianDecision {
  const GuardianDecision({
    required this.intentId,
    required this.status,
    required this.reason,
    required this.riskScore,
    required this.zkFastVerificationMs,
    required this.ruleEvaluations,
    this.guardianSignerAddress,
    this.evmTransferDigest,
  });

  final String intentId;
  final String status;
  final String reason;
  final int riskScore;
  final int zkFastVerificationMs;
  final List<RuleEvaluation> ruleEvaluations;
  final String? guardianSignerAddress;
  final String? evmTransferDigest;

  factory GuardianDecision.fromJson(Map<String, dynamic> json) {
    final rawRules = json['rule_evaluations'] as List<dynamic>? ?? const [];
    return GuardianDecision(
      intentId: json['intent_id'] as String? ?? '-',
      status: json['status'] as String? ?? 'deny',
      reason: json['reason'] as String? ?? 'Unknown reason',
      riskScore: (json['risk_score'] as num?)?.toInt() ?? 0,
      zkFastVerificationMs: (json['zk_fast_verification_ms'] as num?)?.toInt() ?? 0,
      ruleEvaluations: rawRules.map((e) => RuleEvaluation.fromJson(e as Map<String, dynamic>)).toList(),
      guardianSignerAddress: json['guardian_signer_address'] as String?,
      evmTransferDigest: json['evm_transfer_digest'] as String?,
    );
  }
}
