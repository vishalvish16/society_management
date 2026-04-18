import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DomesticHelpScreen extends ConsumerWidget {
  static const String routeName = '/domestic-help';

  const DomesticHelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.of(context).size.width >= 768;
    return Scaffold(
      appBar: isWide ? AppBar(title: const Text('Domestic Help')) : null,
      body: const Center(child: Text('Domestic Help Screen')),
    );
  }
}
