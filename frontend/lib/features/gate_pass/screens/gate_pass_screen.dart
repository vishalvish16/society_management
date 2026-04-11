import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GatePassScreen extends ConsumerWidget {
  static const String routeName = '/gate-pass';

  const GatePassScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('Gate Pass')),
      body: Center(child: Text('Gate Pass Screen')),
    );
  }
}
