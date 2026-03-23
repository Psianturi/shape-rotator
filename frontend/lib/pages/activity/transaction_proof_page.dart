import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/wallet_controller.dart';
import '../../theme/app_theme.dart';

class TransactionProofPage extends StatelessWidget {
  final ActivityEntry entry;

  const TransactionProofPage({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final isAllow = entry.status.toUpperCase() == 'ALLOW';
    final color = AppTheme.statusColor(entry.status);
    final icon = AppTheme.statusIcon(entry.status);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Transaction Proof', style: TextStyle(color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.status, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(entry.reasonLabel, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _InfoBlock(
            title: 'Proof Summary',
            rows: [
              _InfoRow(label: 'Intent ID', value: entry.intentId ?? '-'),
              _InfoRow(label: 'Destination', value: entry.destination ?? '-'),
              _InfoRow(label: 'Amount', value: entry.amountEth == null ? '-' : '${entry.amountEth!.toStringAsFixed(4)} ETH'),
              _InfoRow(label: 'Risk Score', value: entry.detail),
            ],
          ),
          const SizedBox(height: 12),
          _InfoBlock(
            title: 'On-Chain Proof',
            rows: [
              _InfoRow(
                label: 'EVM Digest',
                value: entry.proofDigest == null ? 'Not available for this entry' : '${entry.proofDigest!.substring(0, 18)}...',
                copyValue: entry.proofDigest,
              ),
              _InfoRow(
                label: 'Guardian Signature',
                value: entry.guardianSignature == null ? (isAllow ? 'Issued by enclave signer' : 'None') : '${entry.guardianSignature!.substring(0, 18)}...',
                copyValue: entry.guardianSignature,
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: entry.proofDigest == null && entry.guardianSignature == null
                ? null
                : () {
                    final text = entry.proofDigest ?? entry.guardianSignature ?? entry.intentId ?? '-';
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Proof copied to clipboard')),
                    );
                  },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy proof'),
          ),
        ],
      ),
    );
  }
}

extension on ActivityEntry {
  String get reasonLabel => detail;
}

class _InfoBlock extends StatelessWidget {
  final String title;
  final List<Widget> rows;

  const _InfoBlock({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, letterSpacing: 1.1)),
            const SizedBox(height: 8),
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final String? copyValue;

  const _InfoRow({required this.label, required this.value, this.copyValue});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (copyValue != null) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => Clipboard.setData(ClipboardData(text: copyValue!)),
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