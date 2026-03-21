import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/wallet_controller.dart';
import '../../theme/app_theme.dart';

class GuardianDetailPage extends StatefulWidget {
  final WalletController controller;

  const GuardianDetailPage({super.key, required this.controller});

  @override
  State<GuardianDetailPage> createState() => _GuardianDetailPageState();
}

class _GuardianDetailPageState extends State<GuardianDetailPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onUpdate);
    widget.controller.refreshGuardianProfile();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final enclaveMode = c.enclaveMode;
    final enclaveStatus = c.enclaveStatus;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Guardian Detail', style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Section(
            title: 'GUARDIAN IDENTITY',
            children: [
              _InfoRow(
                label: 'Signer Address',
                value: c.guardianSignerAddress ?? 'Fetching...',
                copyable: c.guardianSignerAddress != null,
                fullValue: c.guardianSignerAddress,
              ),
              _InfoRow(label: 'Policy Engine', value: 'PerisAI Guardian v0.2'),
              _InfoRow(label: 'Chain', value: 'Sepolia (11155111)'),
            ],
          ),
          const SizedBox(height: 12),
          _EnclaveStatusCard(enclaveMode: enclaveMode, enclaveStatus: enclaveStatus),
          const SizedBox(height: 12),
          _Section(
            title: 'ACTIVE POLICY',
            children: [
              _InfoRow(label: 'Max Safe Amount', value: c.policyMaxAmount),
              _InfoRow(label: 'Allowlist', value: c.policyAllowlist),
              _InfoRow(label: 'Risk Threshold', value: 'DENY if score ≥ 70'),
            ],
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'GUARDIAN HEALTH',
            children: [
              _InfoRow(label: 'Intents Today', value: '${c.intentsToday}'),
              _InfoRow(label: 'Allow Rate', value: '${c.allowRatePercent.toStringAsFixed(2)}%'),
            ],
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'USER IDENTITY',
            children: [
              _InfoRow(label: 'User ID', value: c.userId.isEmpty ? 'Not registered' : c.userId),
              _InfoRow(
                label: 'Nullifier',
                value: c.nullifier.isEmpty ? '-' : '${c.nullifier.substring(0, 12)}...',
              ),
              _InfoRow(
                label: 'Commitment',
                value: c.commitment.isEmpty ? '-' : '${c.commitment.substring(0, 12)}...',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'LAST DECISION',
            children: [
              _InfoRow(
                label: 'Status',
                value: c.guardianStatus,
                valueColor: AppTheme.statusColor(c.guardianStatus),
              ),
              _InfoRow(label: 'Risk Score', value: '${c.riskScore}/100'),
              _InfoRow(label: 'Reason', value: c.guardianReason),
              if (c.lastTxDigest != null)
                _InfoRow(
                  label: 'EVM Digest',
                  value: '${c.lastTxDigest!.substring(0, 18)}...',
                  copyable: true,
                  fullValue: c.lastTxDigest,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EnclaveStatusCard extends StatelessWidget {
  final bool enclaveMode;
  final String enclaveStatus;

  const _EnclaveStatusCard({required this.enclaveMode, required this.enclaveStatus});

  @override
  Widget build(BuildContext context) {
    final isOk = enclaveStatus == 'ok';
    final isSimulated = !enclaveMode;
    final color = isSimulated
        ? AppColors.review
        : isOk
            ? AppColors.allow
            : AppColors.deny;
    final icon = isSimulated
        ? Icons.shield_outlined
        : isOk
            ? Icons.verified_user_rounded
            : Icons.gpp_bad_rounded;
    final label = isSimulated
        ? 'TEE Simulated (in-process key)'
        : isOk
            ? 'Enclave Active (Cloud Run isolated)'
            : 'Enclave Unreachable';
    final sublabel = isSimulated
        ? 'Production path: Cloud Run isolated container → Confidential VM'
        : 'Service-to-service auth via Google OIDC ID token';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(sublabel, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, letterSpacing: 1.2)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12)),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool copyable;
  final String? fullValue;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.copyable = false,
    this.fullValue,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: valueColor ?? AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: valueColor != null ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (copyable) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => Clipboard.setData(ClipboardData(text: fullValue ?? value)),
                    child: const Icon(Icons.copy_rounded, size: 14, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
