import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class GuardianStatusCard extends StatelessWidget {
  final String status;
  final String reason;
  final int riskScore;
  final bool isLoading;

  const GuardianStatusCard({
    super.key,
    required this.status,
    required this.reason,
    required this.riskScore,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(status);
    final icon = AppTheme.statusIcon(status);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.6), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                'Guardian: $status',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              if (isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(reason, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Risk Score', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: riskScore / 100,
                    backgroundColor: AppColors.card,
                    color: _riskColor(riskScore),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$riskScore/100',
                style: TextStyle(
                  color: _riskColor(riskScore),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _riskColor(int score) {
    if (score >= 70) return AppColors.deny;
    if (score >= 40) return AppColors.error;
    return AppColors.allow;
  }
}
