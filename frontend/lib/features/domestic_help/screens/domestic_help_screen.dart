import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DomesticHelpScreen extends ConsumerWidget {
  static const String routeName = '/domestic-help';

  const DomesticHelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('Domestic Help')),
      body: Center(child: Text('Domestic Help Screen')),
    );
  }
}
