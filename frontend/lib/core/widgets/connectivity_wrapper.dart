import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/connectivity_provider.dart';
import 'no_internet_screen.dart';

class ConnectivityWrapper extends ConsumerStatefulWidget {
  const ConnectivityWrapper({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends ConsumerState<ConnectivityWrapper> {
  bool _wasOffline = false;

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(connectivityProvider);

    // Auto-redirect to home when connection is restored
    if (!isOnline) {
      _wasOffline = true;
    } else if (_wasOffline) {
      _wasOffline = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/dashboard');
      });
    }

    if (!isOnline) {
      return const NoInternetScreen();
    }

    return widget.child;
  }
}
