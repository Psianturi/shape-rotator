import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../services/guardian_api.dart';

class WalletHomePage extends StatefulWidget {
  const WalletHomePage({super.key});

  @override
  State<WalletHomePage> createState() => _WalletHomePageState();
}

class _WalletHomePageState extends State<WalletHomePage> {
  static const String backendBaseUrl = 'http://127.0.0.1:8000';
  static const String trustedAddress = '0xTrusted001';
  static const String suspiciousAddress = '0xNewRisk999';

  final TextEditingController _amountController = TextEditingController(text: '120');
  final GuardianApi _guardianApi = GuardianApi(baseUrl: backendBaseUrl);

  final List<String> _eventLog = [];

  String _guardianStatus = 'IDLE';
  String _guardianReason = '-';
  String _userId = '';
  String _nullifier = '';
  int _riskScore = 0;
  double _balance = 1250;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _simulateBiometricLoginAndRegister();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _simulateBiometricLoginAndRegister() async {
    setState(() {
      _isLoading = true;
      _guardianStatus = 'AUTH';
      _guardianReason = 'Simulating biometric login and private nullifier generation.';
    });

    // This simulates privacy-preserving biometric output without exposing raw biometrics.
    final random = Random.secure();
    final entropy = List<int>.generate(16, (_) => random.nextInt(255));
    _nullifier = base64UrlEncode(entropy);

    final masterCommitment = _simpleCommitment(_nullifier);

    try {
      final registerResult = await _guardianApi.registerIdentity(
        masterCommitment: masterCommitment,
        allowlist: [trustedAddress],
      );

      setState(() {
        _userId = registerResult.userId;
        _guardianStatus = 'READY';
        _guardianReason = registerResult.zkFastPathHint;
        _eventLog.insert(0, 'Identity registered for $_userId');
      });
    } on Exception {
      setState(() {
        _guardianStatus = 'ERROR';
        _guardianReason = 'Register failed. Ensure backend is running on port 8000.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendIntent({required String destination, required double amount}) async {
    if (_userId.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
      _guardianStatus = 'REVIEW';
      _guardianReason = 'Guardian is evaluating threshold and allowlist rules.';
    });

    try {
      final decision = await _guardianApi.signIntent(
        userId: _userId,
        destination: destination,
        amount: amount,
        userPartialSignature: _simpleCommitment('user_sig:$destination:$amount'),
      );

      setState(() {
        _guardianStatus = decision.status.toUpperCase();
        _guardianReason = decision.reason;
        _riskScore = decision.riskScore;
        _eventLog.insert(
          0,
          '${decision.status.toUpperCase()} -> $destination | amount: ${amount.toStringAsFixed(2)} | risk: ${decision.riskScore}',
        );

        if (decision.status == 'allow') {
          _balance -= amount;
        }
      });
    } on Exception {
      setState(() {
        _guardianStatus = 'ERROR';
        _guardianReason = 'Sign intent failed. Check backend logs.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _simpleCommitment(String input) {
    final bytes = utf8.encode(input);
    return base64UrlEncode(bytes);
  }

  Color _statusColor(String status) {
    if (status == 'ALLOW') {
      return const Color(0xFF0B8A40);
    }
    if (status == 'DENY') {
      return const Color(0xFFCC2233);
    }
    if (status == 'ERROR') {
      return const Color(0xFFB54708);
    }
    return const Color(0xFF2663B3);
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(_guardianStatus);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PerisAI Wallet'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Balance: ${_balance.toStringAsFixed(2)} units', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('User ID: ${_userId.isEmpty ? 'loading...' : _userId}'),
            Text('Nullifier (simulated): ${_nullifier.isEmpty ? '-' : _nullifier.substring(0, 10)}...'),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Transfer amount',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            final amount = double.tryParse(_amountController.text) ?? 120;
                            _sendIntent(destination: trustedAddress, amount: amount);
                          },
                    child: const Text('Send to Trusted Address'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            final amount = (double.tryParse(_amountController.text) ?? 120) + 600;
                            _sendIntent(destination: suspiciousAddress, amount: amount);
                          },
                    child: const Text('Simulate Suspicious Transfer'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Guardian Status: $_guardianStatus', style: TextStyle(fontWeight: FontWeight.bold, color: statusColor)),
                  const SizedBox(height: 6),
                  Text(_guardianReason),
                  const SizedBox(height: 6),
                  Text('Risk Score: $_riskScore/100'),
                ],
              ),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 12),
            const Text('Decision Timeline', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Expanded(
              child: ListView.builder(
                itemCount: _eventLog.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(_eventLog[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
