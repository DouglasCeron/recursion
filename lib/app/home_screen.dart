import 'package:flutter/material.dart';

import 'router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'RECURSION',
                style: textTheme.displaySmall?.copyWith(letterSpacing: 6),
              ),
              const SizedBox(height: 8),
              Text('Prototype', style: textTheme.bodyMedium),
              const SizedBox(height: 40),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.battle),
                child: const Text('Start battle'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
