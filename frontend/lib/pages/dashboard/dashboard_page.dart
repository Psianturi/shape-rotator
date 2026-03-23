import 'package:flutter/material.dart';

import '../../controllers/wallet_controller.dart';
import '../../theme/app_theme.dart';
import '../activity/activity_page.dart';
import '../activity/transaction_proof_page.dart';
import '../transfer/transfer_page.dart';
import 'guardian_detail_page.dart';
import 'guardian_status_card.dart';

class DashboardPage extends StatefulWidget {
  final WalletController controller;

  const DashboardPage({super.key, required this.controller});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  WalletController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _c.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Icon(Icons.shield_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            const Text('PerisAI', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.manage_accounts_rounded, color: AppColors.textSecondary),
            tooltip: 'Guardian Detail',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => GuardianDetailPage(controller: _c)),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => _c.refreshGuardianProfile(),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _BalanceCard(balance: _c.balance),
            const SizedBox(height: 16),
            GuardianStatusCard(
              status: _c.guardianStatus,
              reason: _c.guardianReason,
              riskScore: _c.riskScore,
              isLoading: _c.isLoading,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.send_rounded,
                    label: 'Send',
                    color: AppColors.primary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => TransferPage(controller: _c)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.history_rounded,
                    label: 'Activity',
                    color: AppColors.review,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ActivityPage(controller: _c)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Recent Activity',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            if (_c.activityLog.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No transactions yet.', style: TextStyle(color: AppColors.textSecondary)),
                ),
              )
            else
              ..._c.activityLog.take(5).map((e) => _RecentTile(entry: e)),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final double balance;

  const _BalanceCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E9F6E), Color(0xFF0A7A55)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total Balance', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            '${balance.toStringAsFixed(4)} ETH',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text('Sepolia Testnet', style: TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  final ActivityEntry entry;

  const _RecentTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(entry.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(AppTheme.statusIcon(entry.status), color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                  Text(entry.detail, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            if (entry.hasProof)
              IconButton(
                tooltip: 'Open proof',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => TransactionProofPage(entry: entry)),
                ),
                icon: const Icon(Icons.receipt_long_rounded, color: AppColors.textSecondary, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}
