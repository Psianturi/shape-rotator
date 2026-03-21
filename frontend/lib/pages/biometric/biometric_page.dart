import 'package:flutter/material.dart';

import '../../controllers/wallet_controller.dart';
import '../../theme/app_theme.dart';
import '../dashboard/dashboard_page.dart';

class BiometricPage extends StatefulWidget {
  const BiometricPage({super.key});

  @override
  State<BiometricPage> createState() => _BiometricPageState();
}

class _BiometricPageState extends State<BiometricPage> {
  final WalletController _controller = WalletController();
  bool _scanning = false;
  bool _done = false;

  Future<void> _startBiometric() async {
    setState(() => _scanning = true);
    await _controller.simulateBiometricAndRegister();
    if (!mounted) return;
    if (_controller.guardianStatus == 'ERROR') {
      setState(() => _scanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_controller.guardianReason),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() {
      _scanning = false;
      _done = true;
    });
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => DashboardPage(controller: _controller)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -100,
              right: -70,
              child: _GlowBlob(color: AppColors.primary.withOpacity(0.14), size: 220),
            ),
            Positioned(
              bottom: -90,
              left: -60,
              child: _GlowBlob(color: AppColors.review.withOpacity(0.12), size: 180),
            ),
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.vertical - 40),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary.withOpacity(0.14),
                                  border: Border.all(color: AppColors.primary.withOpacity(0.65), width: 1.5),
                                ),
                                child: const Icon(Icons.shield_rounded, size: 38, color: AppColors.primary),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'PerisAI',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Privacy-first threshold wallet',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.card.withOpacity(0.92),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: AppColors.primary.withOpacity(0.14)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.22),
                                blurRadius: 24,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                _done ? 'Identity secured' : 'Tap to secure your wallet',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Biometric data never leaves your device.\nOnly an anonymous commitment is sent.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.45),
                              ),
                              const SizedBox(height: 24),
                              _BiometricButton(
                                scanning: _scanning,
                                done: _done,
                                onTap: (_scanning || _done) ? null : _startBiometric,
                              ),
                              const SizedBox(height: 18),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                child: Text(
                                  _done ? 'Verified and registered with guardian.' : 'Tap the circle to start biometric sign in.',
                                  key: ValueKey<String>(_done ? 'done' : 'idle'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: const [
                            Expanded(
                              child: _HintCard(
                                icon: Icons.lock_outline_rounded,
                                text: 'Commitment stays private',
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _HintCard(
                                icon: Icons.verified_user_outlined,
                                text: 'Guardian activates instantly',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HintCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card.withOpacity(0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.textSecondary.withOpacity(0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _BiometricButton extends StatelessWidget {
  final bool scanning;
  final bool done;
  final VoidCallback? onTap;

  const _BiometricButton({required this.scanning, required this.done, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done
              ? AppColors.allow.withOpacity(0.2)
              : scanning
                  ? AppColors.primary.withOpacity(0.1)
                  : AppColors.card,
          border: Border.all(
            color: done ? AppColors.allow : AppColors.primary,
            width: 2.5,
          ),
        ),
        child: scanning
            ? const Center(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
                ),
              )
            : Icon(
                done ? Icons.check_rounded : Icons.fingerprint_rounded,
                size: 56,
                color: done ? AppColors.allow : AppColors.primary,
              ),
      ),
    );
  }
}
