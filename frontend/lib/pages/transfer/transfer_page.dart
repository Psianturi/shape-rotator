import 'package:flutter/material.dart';

import '../../controllers/wallet_controller.dart';
import '../../theme/app_theme.dart';
import '../dashboard/guardian_status_card.dart';

class TransferPage extends StatefulWidget {
  final WalletController controller;

  const TransferPage({super.key, required this.controller});

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  final TextEditingController _amountCtrl = TextEditingController(text: '0.05');

  WalletController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _c.removeListener(_onUpdate);
    _amountCtrl.dispose();
    super.dispose();
  }

  void _onUpdate() => setState(() {});

  Future<void> _send(String destination, double amount) async {
    await _c.sendIntent(destination: destination, amount: amount);
    if (!mounted) return;
    _showResultSheet();
  }

  void _showResultSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ResultSheet(controller: _c),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = double.tryParse(_amountCtrl.text) ?? 0.05;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Send Transfer', style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Amount (ETH)', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.currency_exchange, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _c.isLoading ? null : () => _send(WalletController.trustedAddress, amount),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Send to Trusted Address'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _c.isLoading ? null : () => _send(WalletController.suspiciousAddress, amount + 0.6),
              icon: const Icon(Icons.warning_amber_rounded),
              label: const Text('Simulate Suspicious Transfer'),
            ),
            const SizedBox(height: 24),
            GuardianStatusCard(
              status: _c.guardianStatus,
              reason: _c.guardianReason,
              riskScore: _c.riskScore,
              isLoading: _c.isLoading,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultSheet extends StatelessWidget {
  final WalletController controller;

  const _ResultSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final color = AppTheme.statusColor(c.guardianStatus);
    final icon = AppTheme.statusIcon(c.guardianStatus);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 56),
          const SizedBox(height: 12),
          Text(
            c.guardianStatus,
            style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(c.guardianReason, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          if (c.lastRuleEvaluations.isNotEmpty) ...[
            const Divider(color: AppColors.textSecondary),
            ...c.lastRuleEvaluations.map((r) => _RuleRow(rule: r)),
          ],
          if (c.lastTxDigest != null) ...[
            const SizedBox(height: 12),
            Text(
              'Digest: ${c.lastTxDigest!.substring(0, 20)}...',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontFamily: 'monospace'),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  final dynamic rule;

  const _RuleRow({required this.rule});

  @override
  Widget build(BuildContext context) {
    final pass = rule.status == 'pass';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            pass ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: pass ? AppColors.allow : AppColors.deny,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              rule.detail,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
