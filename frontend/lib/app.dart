import 'package:flutter/material.dart';

import 'pages/splash/splash_page.dart';
import 'theme/app_theme.dart';

class PerisAIApp extends StatelessWidget {
  const PerisAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PerisAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const SplashPage(),
    );
  }
}
