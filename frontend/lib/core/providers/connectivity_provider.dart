import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider = StateNotifierProvider<ConnectivityNotifier, bool>((ref) {
  return ConnectivityNotifier();
});

class ConnectivityNotifier extends StateNotifier<bool> {
  ConnectivityNotifier() : super(true) {
    _init();
  }

  late final StreamSubscription<List<ConnectivityResult>> _sub;

  Future<void> _init() async {
    final results = await Connectivity().checkConnectivity();
    state = _hasConnection(results);
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      state = _hasConnection(results);
    });
  }

  bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
