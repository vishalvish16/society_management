import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GatePassScreen extends ConsumerWidget {
  static const String routeName = '/gate-pass';

  const GatePassScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.of(context).size.width >= 768;
    return Scaffold(
      appBar: isWide ? AppBar(title: const Text('Gate Pass')) : null,
      body: const Center(child: Text('Gate Pass Screen')),
    );
  }
}
