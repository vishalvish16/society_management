import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

const _kBiometricEnabled = 'biometric_enabled';
const _kBiometricIdentifier = 'biometric_identifier';
const _kBiometricPassword = 'biometric_password';

class BiometricState {
  final bool isAvailable;     // device supports biometrics
  final bool isEnabled;       // user has turned it on
  final bool isChecking;

  const BiometricState({
    this.isAvailable = false,
    this.isEnabled = false,
    this.isChecking = true,
  });

  BiometricState copyWith({bool? isAvailable, bool? isEnabled, bool? isChecking}) =>
      BiometricState(
        isAvailable: isAvailable ?? this.isAvailable,
        isEnabled: isEnabled ?? this.isEnabled,
        isChecking: isChecking ?? this.isChecking,
      );
}

class BiometricNotifier extends StateNotifier<BiometricState> {
  final _auth = LocalAuthentication();
  final _storage = const FlutterSecureStorage();

  BiometricNotifier() : super(const BiometricState()) {
    _init();
  }

  Future<void> _init() async {
    try {
      final available = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      final enabledStr = await _storage.read(key: _kBiometricEnabled);
      state = state.copyWith(
        isAvailable: available && canCheck,
        isEnabled: enabledStr == 'true',
        isChecking: false,
      );
    } catch (_) {
      state = state.copyWith(isAvailable: false, isEnabled: false, isChecking: false);
    }
  }

  /// Called when user toggles biometric ON.
  /// Saves identifier+password so we can re-authenticate without backend.
  Future<String?> enable(String identifier, String password) async {
    if (!state.isAvailable) return 'Biometrics not available on this device';

    // First authenticate to confirm it works
    final ok = await _authenticate(reason: 'Confirm your biometric to enable quick login');
    if (!ok) return 'Biometric authentication failed';

    await _storage.write(key: _kBiometricEnabled, value: 'true');
    await _storage.write(key: _kBiometricIdentifier, value: identifier);
    await _storage.write(key: _kBiometricPassword, value: password);
    state = state.copyWith(isEnabled: true);
    return null;
  }

  /// Called when user toggles biometric OFF.
  Future<void> disable() async {
    await _storage.delete(key: _kBiometricEnabled);
    await _storage.delete(key: _kBiometricIdentifier);
    await _storage.delete(key: _kBiometricPassword);
    state = state.copyWith(isEnabled: false);
  }

  /// Attempt biometric auth. Returns (identifier, password) on success, null on fail.
  Future<(String, String)?> authenticate() async {
    if (!state.isEnabled) return null;
    final ok = await _authenticate(reason: 'Sign in to Vidyron Society');
    if (!ok) return null;
    final identifier = await _storage.read(key: _kBiometricIdentifier);
    final password = await _storage.read(key: _kBiometricPassword);
    if (identifier == null || password == null) return null;
    return (identifier, password);
  }

  Future<bool> _authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // allow PIN as fallback
        ),
      );
    } on PlatformException {
      return false;
    }
  }

  /// Check if stored credentials still exist (e.g. after token wipe on logout).
  Future<bool> hasStoredCredentials() async {
    final id = await _storage.read(key: _kBiometricIdentifier);
    return id != null && id.isNotEmpty;
  }
}

final biometricProvider =
    StateNotifierProvider<BiometricNotifier, BiometricState>(
        (ref) => BiometricNotifier());
