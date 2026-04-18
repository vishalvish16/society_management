import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeliveryScreen extends ConsumerWidget {
  static const String routeName = '/delivery';

  const DeliveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.of(context).size.width >= 768;
    return Scaffold(
      appBar: isWide ? AppBar(title: const Text('Delivery')) : null,
      body: const Center(child: Text('Delivery Screen')),
    );
  }
}
